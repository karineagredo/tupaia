/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */
import { Aggregator } from '@tupaia/aggregator';

const ENTITY_AGGREGATION_ORDER_AFTER = 'AFTER';
const DEFAULT_ENTITY_AGGREGATION_TYPE = Aggregator.aggregationTypes.REPLACE_ORG_UNIT_WITH_ORG_GROUP;
const DATA_SOURCE_ONLY_AGGREGATION_TYPE = Aggregator.aggregationTypes.RAW;
const DEFAULT_ENTITY_AGGREGATION_ORDER = ENTITY_AGGREGATION_ORDER_AFTER;

export const buildAggregationOptions = (initialAggregationOptions, entityAggregationOptions) => {
  const {
    aggregations,
    aggregationType,
    aggregationConfig,
    ...restOfOptions
  } = initialAggregationOptions;
  const {
    aggregationEntityType,
    dataSourceEntityType,
    aggregationType: entityAggregationType,
    aggregationConfig: entityAggregationConfig,
    aggregationOrder: entityAggregationOrder = DEFAULT_ENTITY_AGGREGATION_ORDER,
  } = entityAggregationOptions;

  // Note aggregationType and aggregationConfig might be undefined
  const inputAggregations = aggregations || [{ type: aggregationType, config: aggregationConfig }];

  if (!(aggregationEntityType || dataSourceEntityType)) {
    return {
      aggregations: inputAggregations,
      ...restOfOptions,
    };
  }

  const entityAggregation = fetchEntityAggregationConfig(
    aggregationEntityType,
    dataSourceEntityType,
    entityAggregationType,
    entityAggregationConfig,
  );

  return {
    aggregations:
      entityAggregationOrder === ENTITY_AGGREGATION_ORDER_AFTER
        ? [...inputAggregations, entityAggregation]
        : [entityAggregation, ...inputAggregations],
    ...restOfOptions,
  };
};

const fetchEntityAggregationConfig = (
  aggregationEntityType,
  dataSourceEntityType,
  entityAggregationType = DEFAULT_ENTITY_AGGREGATION_TYPE,
  entityAggregationConfig,
) => {
  return {
    type: aggregationEntityType ? entityAggregationType : DATA_SOURCE_ONLY_AGGREGATION_TYPE,
    config: { ...entityAggregationConfig, aggregationEntityType, dataSourceEntityType },
  };
};
