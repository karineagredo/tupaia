/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { DataBroker } from '@tupaia/data-broker';
import { Aggregator } from './Aggregator';

export const createAggregator = (AggregatorClass = Aggregator, context, ...additionalParams) => {
  const dataBroker = new DataBroker(context);
  return new AggregatorClass(dataBroker, ...additionalParams);
};
