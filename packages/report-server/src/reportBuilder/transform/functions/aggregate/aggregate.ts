/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { TransformParser } from '../../parser';
import { aggregations } from './aggregations';
import { buildWhere } from '../where';
import { Row } from '../../../types';
import { buildCreateGroupKey } from './createGroupKey';
import { buildGetFieldAggregation } from './getFieldAggregation';
import { functions } from '../../../functions';

type AggregateParams = {
  createGroupKey: (row: Row) => string;
  getFieldAggregation: (field: string) => keyof typeof aggregations;
  where: (parser: TransformParser) => boolean;
};

type AggregationProps = Parameters<typeof aggregations[keyof typeof aggregations]>[3];

const merge = (
  mergedRow: Row,
  newRow: Row,
  params: AggregateParams,
  groupProps: { [field: string]: AggregationProps },
): Row => {
  Object.keys(newRow).forEach((field: string) => {
    const aggregation = params.getFieldAggregation(field);
    groupProps[field] = groupProps[field] || {};
    aggregations[aggregation](mergedRow, field, newRow[field], groupProps[field]);
  });
  return mergedRow;
};

const aggregate = (rows: Row[], params: AggregateParams): Row[] => {
  const groupedRows: { [groupKey: string]: Row } = {};
  const aggregationProps: { [groupKey: string]: { [field: string]: AggregationProps } } = {};
  const otherRows: Row[] = [];

  const parser = new TransformParser(rows, functions);
  rows.forEach((row: Row) => {
    if (!params.where(parser)) {
      otherRows.push(row);
      parser.next();
      return;
    }
    const groupKey = params.createGroupKey(row);
    groupedRows[groupKey] = groupedRows[groupKey] || {};
    aggregationProps[groupKey] = aggregationProps[groupKey] || {};
    merge(groupedRows[groupKey], row, params, aggregationProps[groupKey]);
    parser.next();
  });

  return Object.values(groupedRows).concat(otherRows);
};

const buildParams = (params: unknown): AggregateParams => {
  if (typeof params !== 'object' || params === null) {
    throw new Error(`Expected params object but got ${params}`);
  }

  const { where, ...restOfAggregations } = params;

  Object.values(restOfAggregations).forEach(aggregation => {
    if (typeof aggregation !== 'string' || !(aggregation in aggregations)) {
      throw new Error(
        `Expected all aggregations to be one of ${Object.keys(
          aggregations,
        )} but got ${aggregation}`,
      );
    }
  });

  return {
    createGroupKey: buildCreateGroupKey(
      restOfAggregations as { [key: string]: keyof typeof aggregations },
    ),
    getFieldAggregation: buildGetFieldAggregation(
      restOfAggregations as { [key: string]: keyof typeof aggregations },
    ),
    where: buildWhere(params),
  };
};

export const buildAggregate = (params: unknown) => {
  const builtParams = buildParams(params);
  return (rows: Row[]) => aggregate(rows, builtParams);
};
