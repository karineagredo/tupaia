/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { AGGREGATION_TYPES } from '../../aggregationTypes';
import { replaceOrgUnitWithOrgGroup, averagePerDataElementPerOrgUnit } from './aggregations';

export const aggregateEvents = (
  events,
  aggregationType = AGGREGATION_TYPES.RAW,
  aggregationConfig = {},
) => {
  switch (aggregationType) {
    case AGGREGATION_TYPES.REPLACE_ORG_UNIT_WITH_ORG_GROUP:
      return replaceOrgUnitWithOrgGroup(events, aggregationConfig);
    case AGGREGATION_TYPES.RAW:
      return events;
    case AGGREGATION_TYPES.AVERAGE_PER_DATA_ELEMENT_PER_ORG_UNIT:
      return averagePerDataElementPerOrgUnit(events, aggregationConfig);
    default:
      throw new Error('Aggregation type not found');
  }
};
