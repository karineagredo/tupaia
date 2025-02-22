/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import {
  adjustOptionsToAggregationList,
  aggregateAnalytics,
  filterAnalytics,
  periodFromAnalytics,
} from './analytics';
import { aggregateEvents } from './events';
import { AGGREGATION_TYPES } from './aggregationTypes';

export class Aggregator {
  static aggregationTypes = AGGREGATION_TYPES;

  constructor(dataBroker) {
    this.dataBroker = dataBroker;
    this.context = dataBroker.context;
  }

  async close() {
    return this.dataBroker.close();
  }

  get aggregationTypes() {
    return Aggregator.aggregationTypes;
  }

  get dataSourceTypes() {
    return this.dataBroker.getDataSourceTypes();
  }

  processAnalytics = (analytics, aggregationOptions, requestedPeriod) => {
    const { aggregations = [], filter } = aggregationOptions;
    const aggregatedAnalytics = this.aggregateAnalytics(analytics, aggregations, requestedPeriod);
    return filterAnalytics(aggregatedAnalytics, filter);
  };

  aggregateAnalytics = (analytics, aggregationList, requestedPeriod) =>
    aggregationList.reduce((partiallyAggregatedAnalytics, { type, config }) => {
      return aggregateAnalytics(partiallyAggregatedAnalytics, type, {
        ...config,
        requestedPeriod,
      });
    }, analytics);

  async fetchAnalytics(codeInput, fetchOptions, aggregationOptions = {}) {
    const code = Array.isArray(codeInput) ? codeInput : [codeInput];
    const dataSourceSpec = { code, type: this.dataSourceTypes.DATA_ELEMENT };
    const [adjustedFetchOptions, adjustedAggregationOptions] = await adjustOptionsToAggregationList(
      this.context,
      fetchOptions,
      aggregationOptions,
    );

    const { organisationUnitCode, organisationUnitCodes } = adjustedFetchOptions;
    if (!organisationUnitCode && (!organisationUnitCodes || !organisationUnitCodes.length)) {
      // No organisation unit code, return empty response
      return {
        results: [],
        metadata: {
          dataElementCodeToName: {},
        },
        period: periodFromAnalytics([], fetchOptions),
      };
    }

    const { results, metadata } = await this.dataBroker.pull(dataSourceSpec, adjustedFetchOptions);

    return {
      results: this.processAnalytics(results, adjustedAggregationOptions, fetchOptions.period),
      metadata,
      period: periodFromAnalytics(results, fetchOptions),
    };
  }

  processEvents = (events, aggregationOptions) => {
    const { aggregations = [] } = aggregationOptions;
    const aggregatedEvents = aggregations.reduce(
      (partiallyAggregatedEvents, { type, config }) =>
        aggregateEvents(partiallyAggregatedEvents, type, config),
      events,
    );
    return aggregatedEvents;
  };

  async fetchEvents(code, fetchOptions, aggregationOptions = {}) {
    const dataSourceSpec = { code, type: this.dataSourceTypes.DATA_GROUP };
    const [adjustedFetchOptions, adjustedAggregationOptions] = await adjustOptionsToAggregationList(
      this.context,
      fetchOptions,
      aggregationOptions,
    );

    const { organisationUnitCode, organisationUnitCodes } = adjustedFetchOptions;
    if (!organisationUnitCode && (!organisationUnitCodes || !organisationUnitCodes.length)) {
      return [];
    }

    const events = await this.dataBroker.pull(dataSourceSpec, adjustedFetchOptions);

    return this.processEvents(events, adjustedAggregationOptions);
  }

  async fetchDataElements(codes, fetchOptions) {
    const dataSourceSpec = { code: codes, type: this.dataSourceTypes.DATA_ELEMENT };
    return this.dataBroker.pullMetadata(dataSourceSpec, fetchOptions);
  }

  async fetchDataGroup(code, fetchOptions) {
    const dataSourceSpec = { code, type: this.dataSourceTypes.DATA_GROUP };
    return this.dataBroker.pullMetadata(dataSourceSpec, fetchOptions);
  }

  // TODO ultimately Aggregator should handle preaggregation internally - at that point this method
  // could be removed
  async pushAggregateData(data) {
    if (data.length === 0) return null;
    const codes = data.map(dataValue => dataValue.code);
    const dataSourceSpec = { code: codes, type: this.dataSourceTypes.DATA_ELEMENT };
    const { diagnostics } = await this.dataBroker.push(dataSourceSpec, data);
    return diagnostics;
  }

  // TODO ultimately Aggregator should handle preaggregation internally - at that point this method
  // could be removed
  async deleteAggregateDataValue(dataValue) {
    const dataSourceSpec = {
      code: dataValue.code,
      type: this.dataSourceTypes.DATA_ELEMENT,
    };
    return this.dataBroker.delete(dataSourceSpec, dataValue);
  }
}
