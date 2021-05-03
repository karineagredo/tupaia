import { Aggregator as BaseAggregator } from '@tupaia/aggregator';
import { QueryBuilder } from './QueryBuilder';
import { buildAggregationOptions } from './buildAggregationOptions';

export class Aggregator extends BaseAggregator {
  constructor(dataBroker, models, routeHandler) {
    super(dataBroker);
    this.models = models;
    this.routeHandler = routeHandler;
  }

  async fetchAnalytics(
    dataElementCodes,
    originalQuery,
    replacementValues,
    initialAggregationOptions = {},
  ) {
    const queryBuilder = new QueryBuilder(originalQuery, replacementValues);
    const hierarchyName = (
      await this.models.entityHierarchy.findById(await this.routeHandler.fetchHierarchyId())
    ).name;

    const fetchOptions = queryBuilder.build();

    const aggregationOptions = buildAggregationOptions(
      initialAggregationOptions,
      queryBuilder.getEntityAggregationOptions(),
    );

    return super.fetchAnalytics(
      dataElementCodes,
      { ...fetchOptions, hierarchy: hierarchyName, useDeprecatedApi: false },
      aggregationOptions,
    );
  }

  async fetchEvents(programCode, originalQuery, replacementValues) {
    const queryBuilder = new QueryBuilder(originalQuery, replacementValues);
    const hierarchyName = (
      await this.models.entityHierarchy.findById(await this.routeHandler.fetchHierarchyId())
    ).name;

    queryBuilder.replaceOrgUnitCodes();
    queryBuilder.makeEventReplacements();

    const aggregationOptions = buildAggregationOptions(
      {}, // No input aggregation for events (yet)
      queryBuilder.getEntityAggregationOptions(),
    );

    return super.fetchEvents(
      programCode,
      { ...queryBuilder.getQuery(), hierarchy: hierarchyName },
      aggregationOptions,
    );
  }
}
