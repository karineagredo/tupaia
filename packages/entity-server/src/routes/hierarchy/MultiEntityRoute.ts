/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { Route } from '@tupaia/server-boilerplate';
import { formatEntitiesForResponse } from './format';
import { MultiEntityRequest, MultiEntityRequestParams, EntityResponse } from './types';

export type MultiEntityRouteRequest = MultiEntityRequest<
  MultiEntityRequestParams,
  EntityResponse[]
>;

export class MultiEntityRoute extends Route<MultiEntityRouteRequest> {
  async buildResponse() {
    const { entities, field, fields } = this.req.ctx;
    return formatEntitiesForResponse(this.req.models, this.req.ctx, entities, field || fields);
  }
}
