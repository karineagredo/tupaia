/**
 * Tupaia Config Server
 * Copyright (c) 2019 Beyond Essential Systems Pty Ltd
 */

import { expect } from 'chai';
import { Aggregator } from '@tupaia/aggregator';

import { buildAggregationOptions } from '/aggregator/buildAggregationOptions';

const BASIC_AGGREGATION_OPTIONS = { aggregationType: 'SUM_MOST_RECENT_PER_FACILITY', filter: {} };
const BASIC_ENTITY_AGGREGATION_OPTIONS = {
  dataSourceEntityType: 'facility',
};

describe('buildAggregationOptions', () => {
  it('should build basic aggregation options', async () => {
    return expect(buildAggregationOptions(BASIC_AGGREGATION_OPTIONS, {})).to.deep.equal({
      aggregations: [
        {
          type: 'SUM_MOST_RECENT_PER_FACILITY',
          config: undefined,
        },
      ],
      filter: {},
    });
  });

  it('should build basic aggregation options and dataSource only entity aggregation options', async () => {
    return expect(
      buildAggregationOptions(BASIC_AGGREGATION_OPTIONS, BASIC_ENTITY_AGGREGATION_OPTIONS),
    ).to.deep.equal({
      aggregations: [
        {
          type: 'SUM_MOST_RECENT_PER_FACILITY',
          config: undefined,
        },
        {
          type: 'RAW',
          config: {
            aggregationEntityType: undefined,
            dataSourceEntityType: 'facility',
          },
        },
      ],
      filter: {},
    });
  });

  it('should build basic aggregation options and default entity aggregation options', async () => {
    return expect(
      buildAggregationOptions(BASIC_AGGREGATION_OPTIONS, {
        ...BASIC_ENTITY_AGGREGATION_OPTIONS,
        aggregationEntityType: 'district',
      }),
    ).to.deep.equal({
      aggregations: [
        { type: 'SUM_MOST_RECENT_PER_FACILITY', config: undefined },
        {
          type: Aggregator.aggregationTypes.REPLACE_ORG_UNIT_WITH_ORG_GROUP,
          config: {
            dataSourceEntityType: 'facility',
            aggregationEntityType: 'district',
          },
        },
      ],
      filter: {},
    });
  });

  it('should build entity aggregation options before basic aggregation options if configured', async () => {
    return expect(
      buildAggregationOptions(BASIC_AGGREGATION_OPTIONS, {
        ...BASIC_ENTITY_AGGREGATION_OPTIONS,
        dataSourceEntityType: 'facility',
        aggregationEntityType: 'district',
        aggregationOrder: 'BEFORE',
      }),
    ).to.deep.equal({
      aggregations: [
        {
          type: Aggregator.aggregationTypes.REPLACE_ORG_UNIT_WITH_ORG_GROUP,
          config: {
            dataSourceEntityType: 'facility',
            aggregationEntityType: 'district',
          },
        },
        { type: 'SUM_MOST_RECENT_PER_FACILITY', config: undefined },
      ],
      filter: {},
    });
  });
});
