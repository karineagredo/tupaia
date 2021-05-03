/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 *
 */
import { ApiConnection } from '@tupaia/server-boilerplate';

const { ENTITY_SERVER_API_URL = 'http://localhost:8050/v1' } = process.env;

export class EntityConnection extends ApiConnection {
  baseUrl = ENTITY_SERVER_API_URL;

  constructor(session) {
    const { getAuthHeader } = session;
    super({ getAuthHeader });
  }

  async getParents(hierarchyName, entityCodes) {
    const entities = await this.post(
      `hierarchy/${hierarchyName}`,
      { fields: ['parent_code'].join(',') },
      { entities: entityCodes },
    );

    return Array.from(new Set(entities.map(entity => entity.parent_code)));
  }

  async getDataSourceEntities(
    hierarchyName,
    entityCodes,
    {
      dataSourceEntityType,
      includeSiblingData,
      dataSourceEntityFilter = {}, // TODO: Add support for dataSourceEntityFilter https://github.com/beyondessential/tupaia-backlog/issues/2660
    },
  ) {
    const entityCodesForRequest = includeSiblingData
      ? await this.getParents(hierarchyName, entityCodes)
      : entityCodes;

    return this.post(
      `hierarchy/${hierarchyName}/descendants`,
      {
        filter: `type:${dataSourceEntityType}`,
        field: 'code',
      },
      {
        entities: entityCodesForRequest,
      },
    );
  }

  async getDataSourceEntitiesAndRelations(
    hierarchyName,
    entityCodes,
    {
      aggregationEntityType,
      dataSourceEntityType,
      includeSiblingData,
      dataSourceEntityFilter = {}, // TODO: Add support for dataSourceEntityFilter https://github.com/beyondessential/tupaia-backlog/issues/2660
    },
  ) {
    const entityCodesForRequest = includeSiblingData
      ? await this.getParents(hierarchyName, entityCodes)
      : entityCodes;

    const query = {
      descendant_filter: `type:${dataSourceEntityType}`,
      field: 'code',
      groupBy: 'descendant',
    };

    // Omitting ancestor_type returns descendants to requested entities map
    if (aggregationEntityType !== 'requested') {
      query.ancestor_filter = `type:${aggregationEntityType}`;
    }

    const response = await this.post(`hierarchy/${hierarchyName}/relations`, query, {
      entities: entityCodesForRequest,
    });

    const formattedRelations = {};
    Object.entries(response).forEach(([descendant, ancestor]) => {
      formattedRelations[descendant] = { code: ancestor };
    });
    return [Object.keys(formattedRelations), formattedRelations];
  }
}
