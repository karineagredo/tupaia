/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */
import { utcMoment, stripTimezoneFromDate } from '@tupaia/utils';

import { SqlQuery } from './SqlQuery';

const AGGREGATIONS = {
  FINAL_EACH_DAY: {
    periodColumns: ['day_period'],
    useA2Join: true,
  },
  FINAL_EACH_WEEK: {
    periodColumns: ['week_period'],
    useA2Join: true,
  },
  FINAL_EACH_MONTH: {
    periodColumns: ['month_period'],
    useA2Join: true,
  },
  FINAL_EACH_YEAR: {
    periodColumns: ['year_period'],
    useA2Join: true,
  },
  MOST_RECENT: {
    periodColumns: [],
    useA2Join: true,
  },
  SUM_PER_ORG_GROUP: {
    periodColumns: [],
    useA2Join: false,
    entityAggregation: true,
    sum: true,
  },
  DEFAULT: {
    useA2Join: false,
  },
};

const getCommonFields = firstAggregation => [
  'data_element_code',
  getEntityCodeField(firstAggregation),
]; // Fields which may be grouped by for aggregation purposes
const ANSWER_SPECIFIC_FIELDS = ['entity_name', 'date', 'event_id', 'value', 'type']; // Fields unique to each answer

const getEntityCodeField = firstAggregation =>
  firstAggregation.entityAggregation ? 'aggregation_entity_code' : 'entity_code';

const entityCodesAndRelations = (firstAggregation, entityCodes, paramsArray) =>
  `entity_codes_and_relations (code${
    firstAggregation.entityAggregation ? ', aggregation_entity_code' : ''
  }) AS (${
    firstAggregation.entityAggregation
      ? SqlQuery.parameteriseValues(
          Object.entries(firstAggregation.config.orgUnitMap).map(([key, value]) => [
            key,
            value.code,
          ]),
          paramsArray,
        )
      : SqlQuery.parameteriseValues(
          entityCodes.map(entityCode => [entityCode]),
          paramsArray,
        )
  })`;

const getA1Select = firstAggregation => {
  return `SELECT ${getCommonFields(firstAggregation)
    .concat(
      firstAggregation.useA2Join
        ? firstAggregation.periodColumns
        : firstAggregation.sum
        ? ['SUM(value::NUMERIC)::text as value', 'MAX(date) as date', 'MAX(type) as type']
        : ANSWER_SPECIFIC_FIELDS,
    )
    .join(', ')}`;
};

const getA1WhereClause = (conditions, paramsArray) => {
  let hasAnyCondition = false;
  let clause = '';
  for (const [condition, value] of Object.entries(conditions)) {
    if (!value) {
      continue;
    }
    paramsArray.push(value);

    clause = `${clause}
              ${hasAnyCondition ? 'AND' : 'WHERE'}`;
    switch (condition) {
      case 'dataGroupCode':
        clause = `${clause} data_group_code = ?`;
        break;
      case 'eventId':
        clause = `${clause} event_id = ?`;
        break;
      case 'startDate':
        clause = `${clause} date >= ?`;
        break;
      case 'endDate':
        clause = `${clause} date <= ?`;
        break;
      default:
        throw new Error(`Unknown condition in fetch data where clause: ${condition}`);
    }
    hasAnyCondition = true;
  }

  return clause;
};

const getA1GroupByClause = firstAggregation => {
  return firstAggregation.useA2Join || firstAggregation.sum
    ? `GROUP BY ${getCommonFields(firstAggregation)
        .concat(firstAggregation.periodColumns)
        .join(', ')}`
    : '';
};

const getA2WhereClause = (firstAggregation, startDate, endDate, paramsArray) => {
  const whereClauses = getCommonFields(firstAggregation)
    .concat(firstAggregation.periodColumns)
    .map(field => `${field} = a1.${field}`);
  if (startDate) {
    whereClauses.push('date >= ?');
    paramsArray.push(startDate);
  }
  if (endDate) {
    whereClauses.push('date <= ?');
    paramsArray.push(endDate);
  }
  return `WHERE ${whereClauses.join('\n      AND ')}`;
};

const getA2Join = (firstAggregation, startDate, endDate, paramsArray) => {
  return firstAggregation.useA2Join
    ? `CROSS JOIN LATERAL (
      SELECT ${
        firstAggregation.sum
          ? ANSWER_SPECIFIC_FIELDS.filter(field => field !== 'value')
          : ANSWER_SPECIFIC_FIELDS
      }
      FROM analytics
      INNER JOIN entity_codes_and_relations ON entity_codes_and_relations.code = analytics.entity_code
      ${getA2WhereClause(firstAggregation, startDate, endDate, paramsArray)}
      order by date desc
      limit 1
    ) as a2`
    : '';
};

const generateBaseSqlQuery = ({
  dataElementCodes,
  organisationUnitCodes,
  dataGroupCode,
  eventId,
  startDate,
  endDate,
  aggregations,
}) => {
  const adjustedStartDate = startDate
    ? stripTimezoneFromDate(utcMoment(startDate).startOf('day').toISOString())
    : undefined;
  const adjustedEndDate = endDate
    ? stripTimezoneFromDate(utcMoment(endDate).endOf('day').toISOString())
    : undefined;
  const firstAggregation = AGGREGATIONS[aggregations?.[0]?.type] || AGGREGATIONS.DEFAULT;
  firstAggregation.config = aggregations?.[0]?.config;
  const paramsArray = [];
  const sqlQuery = new SqlQuery(
    `
    WITH ${entityCodesAndRelations(firstAggregation, organisationUnitCodes, paramsArray)}

    SELECT
      date AS "date",
      ${getEntityCodeField(firstAggregation)} AS "entityCode",
      data_element_code AS "dataElementCode",
      value AS "value",
      type AS "type"
    FROM (
      ${getA1Select(firstAggregation)}
      FROM analytics
      INNER JOIN entity_codes_and_relations ON entity_codes_and_relations.code = analytics.entity_code
      INNER JOIN (
        ${SqlQuery.parameteriseValues(
          dataElementCodes.map(dataElementCode => [dataElementCode]),
          paramsArray,
        )}
      ) data_element_codes(code) ON data_element_codes.code = analytics.data_element_code
        ${getA1WhereClause(
          { dataGroupCode, eventId, startDate: adjustedStartDate, endDate: adjustedEndDate },
          paramsArray,
        )}
        ${getA1GroupByClause(firstAggregation)}
    ) as a1
    ${getA2Join(firstAggregation, adjustedStartDate, adjustedEndDate, paramsArray)}
  `,
    paramsArray,
  );

  sqlQuery.addOrderByClause('date');

  console.log(sqlQuery.loggableQuery());

  return sqlQuery;
};

export async function fetchData(database, options) {
  const sqlQuery = generateBaseSqlQuery(options);
  return sqlQuery.executeOnDatabase(database);
}
