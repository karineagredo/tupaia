/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { createAggregator } from '@tupaia/aggregator';
import { createBasicHeader } from '@tupaia/utils';
import { RouteHandler } from './RouteHandler';
import { Aggregator } from '/aggregator';
import { refreshAndSaveAccessToken } from '/appServer/requestHelpers/refreshAndSaveAccessToken';

const { MICROSERVICE_CLIENT_USERNAME, MICROSERVICE_CLIENT_SECRET } = process.env;

const PUBLIC_USER_NAME = 'public';
const PUBLIC_USER_AUTH_HEADER = createBasicHeader(
  MICROSERVICE_CLIENT_USERNAME,
  MICROSERVICE_CLIENT_SECRET,
);

/**
 * Interface class for handling routes that fetch data from an aggregator
 * buildResponse must be implemented
 */
export class DataAggregatingRouteHandler extends RouteHandler {
  constructor(req, res) {
    super(req, res);

    const userName = req.session?.userJson?.userName;

    const getAuthHeader = async () => {
      if (userName === PUBLIC_USER_NAME) {
        return PUBLIC_USER_AUTH_HEADER;
      }

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
