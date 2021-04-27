/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { createAggregator } from '@tupaia/aggregator';
import { RouteHandler } from './RouteHandler';
import { Aggregator } from '/aggregator';
import { refreshAndSaveAccessToken } from '/appServer/requestHelpers/refreshAndSaveAccessToken';

/**
 * Interface class for handling routes that fetch data from an aggregator
 * buildResponse must be implemented
 */
export class DataAggregatingRouteHandler extends RouteHandler {
  constructor(req, res) {
    super(req, res);

    // TODO: How to support public user???
    const userName = req.session?.userJson?.userName;

    const getAuthHeader = async () => {
      const { refreshToken } = await req.models.userSession.findOne({
        userName,
      });
      // TODO: Make getting access token smart so we don't constantly refresh
      const newAccessToken = await refreshAndSaveAccessToken(req.models, refreshToken, userName);
      return `Bearer ${newAccessToken}`;
    };

    this.aggregator = createAggregator(
      Aggregator,
      { session: { getAuthHeader } },
      this.models,
      this,
    );
  }
}
