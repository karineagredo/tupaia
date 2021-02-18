/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */
import keyBy from 'lodash.keyby';
import { utcMoment } from '@tupaia/utils';

import { SqlQuery } from './SqlQuery';

const getA1WhereClause = conditions => {
  let hasAnyCondition = false;
  let clause = '';
  for (const [condition, value] of Object.entries(conditions)) {
    if (!value) {
      continue;
    }

    clause = `${clause}
              ${hasAnyCondition ? 'AND' : 'WHERE'}`;
    switch (condition) {
      case 'questionIds':
        clause = `${clause} q.id IN ${SqlQuery.parameteriseValues(value)}`;
        break;
      case 'entityIds':
        clause = `${clause} sr.entity_id IN ${SqlQuery.parameteriseValues(value)}`;
        break;
      case 'eventId':
        clause = `${clause} sr.id = ?`;
        break;
      case 'startDate':
        clause = `${clause} sr.submission_time > ?`;
        break;
      case 'endDate':
        clause = `${clause} sr.submission_time < ?`;
        break;
      default:
        throw new Error(`Unknown condition in fetch data where clause: ${condition}`);
    }
    hasAnyCondition = true;
  }

  return clause;
};

export const fetchData = async (
  database,
  { dataElementCodes, organisationUnitCodes, eventId, startDate, endDate, aggregations },
) => {
  const firstAggregationType = aggregations && aggregations[0] && aggregations[0].type;
  if (firstAggregationType !== 'MOST_RECENT') {
    throw new Error('Unsupported first aggregation type');
  }
  const questionResults = await new SqlQuery(`
    SELECT id, code FROM question WHERE code IN ${SqlQuery.parameteriseValues(dataElementCodes)}
  `);
  const questionMetadata = keyBy(questionResults, 'id');
  const questionIds = Object.keys(questionMetadata);

  const entityResults = await new SqlQuery(`
    SELECT id, code, name FROM entity WHERE code IN ${SqlQuery.parameteriseValues(
      organisationUnitCodes,
    )}
  `);
  const entityMetadata = keyBy(entityResults, 'id');
  const entityIds = Object.keys(entityMetadata);

  const sqlQuery = new SqlQuery(
    `
    SELECT
      a2.submission_time AS "date",
      a2.sr_id AS "eventId",
      a2.text AS "value",
      a2.type AS "type",
      a2.question_id AS "question_id",
    FROM (
      SELECT a.question_id, sr.entity_id
      FROM answer a JOIN survey_response sr ON a.survey_response_id = sr.id
        ${getA1WhereClause({ questionIds, entityIds, eventId, startDate, endDate })}
      GROUP BY a.question_id, sr.entity_id;
    ) as a1
    CROSS JOIN LATERAL (
      SELECT sr.submission_time, sr.id as sr_id,
      FROM answer a JOIN survey_response sr ON a.survey_response_id = sr.id
      WHERE sr.entity_id = a1.entity_id
      AND a.question_id = a1.question_id
      order by date desc
      limit 1
    ) as a2
  `,
    [...dataElementCodes, ...organisationUnitCodes]
      .concat(eventId ? [eventId] : [])
      .concat(startDate ? [utcMoment(startDate).startOf('day').toISOString()] : [])
      .concat(endDate ? [utcMoment(endDate).startOf('day').toISOString()] : []),
  );

  sqlQuery.addOrderByClause('date');
  const data = await sqlQuery.executeOnDatabase(database);

  return data.map(r => ({
    ...r,
    dataElementCode: questionMetadata[r.question_id].code,
    entityCode: entityMetadata[r.entity_id].code,
    entityName: entityMetadata[r.entity_id].name,
  }));
};
