/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 *
 */
import { ApiConnection } from '@tupaia/server-boilerplate';

const { ENTITY_API_URL = 'http://localhost:8050/v1' } = process.env;

const UNSUPPORTED_ENTITY_TYPE = 'project';

export class EntityConnection extends ApiConnection {
  baseUrl = ENTITY_API_URL;

  constructor(session) {
    const { getAuthHeader } = session;
    super({ getAuthHeader });
  }

  async getSupportedEntities(hierarchyName, entityCodes) {
    const requestedEntities = await this.get(`hierarchy/${hierarchyName}`, {
      entities: entityCodes.join(','),
      fields: ['code', 'type'].join(','),
    });

    const unsupportedEntities = requestedEntities.filter(
      entity => entity.type === UNSUPPORTED_ENTITY_TYPE,
    );

    if (unsupportedEntities.length < 1) {
      return entityCodes; // All requested entities are supported
    }

    // Get countries within project
    const replacementEntities = await this.get(`hierarchy/${hierarchyName}/descendants`, {
      entities: unsupportedEntities.map(entity => entity.code).join(','),
      field: 'code',
      filter: `type:country`,
    });

    return requestedEntities
      .filter(entity => !unsupportedEntities.includes(entity))
      .map(entity => entity.code)
      .concat(replacementEntities);
  }
}
