/**
 * Tupaia Config Server
 * Copyright (c) 2019 Beyond Essential Systems Pty Ltd
 */
import { SumBuilder } from '/apiV1/dataBuilders/generic/sum/sum';
import { DataPerOrgUnitBuilder } from './DataPerOrgUnitBuilder';
import {
  fetchAggregatedAnalyticsByDhisIds,
  checkAllDataElementsAreDhisIndicators,
} from '/apiV1/utils';

export class SumPerOrgUnitBuilder extends DataPerOrgUnitBuilder {
  getBaseBuilderClass = () => SumBuilder;

  async fetchResultsAndPeriod() {
    const { dataElementCode } = this.query;
    const dataElementCodes = this.config.dataElementCodes || [dataElementCode];
    const { period, results } = await this.fetchResults(dataElementCodes);
    return { results, period };
  }

  async fetchResults(dataElementCodes) {
    const allDataElementsAreDhisIndicators = await checkAllDataElementsAreDhisIndicators(
      this.models,
      dataElementCodes,
    );
    if (allDataElementsAreDhisIndicators) {
      const { entityAggregation } = this.config;
      const hierarchyId = await this.fetchEntityHierarchyId();
      const result = await fetchAggregatedAnalyticsByDhisIds(
        this.models,
        this.dhisApi,
        dataElementCodes,
        this.query,
        entityAggregation,
        hierarchyId
      );
      console.log(result);
  
      return result;
    }
    return this.fetchAnalytics(dataElementCodes, {
      organisationUnitCode: this.entity.code,
    });
  }
}
export const sumLatestPerOrgUnit = async (
  models,
  aggregator,
  dhisApi,
  query,
  measureBuilderConfig,
  entity,
) => {
  const builder = new SumPerOrgUnitBuilder(
    models,
    aggregator,
    dhisApi,
    measureBuilderConfig,
    query,
    entity,
    aggregator.aggregationTypes.MOST_RECENT,
  );
  return builder.build();
};
export const sumAllPerOrgUnit = async (
  models,
  aggregator,
  dhisApi,
  query,
  measureBuilderConfig,
  entity,
) => {
  const builder = new SumPerOrgUnitBuilder(
    models,
    aggregator,
    dhisApi,
    measureBuilderConfig,
    query,
    entity,
    aggregator.aggregationTypes.SUM,
  );
  return builder.build();
};
