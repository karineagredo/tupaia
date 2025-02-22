/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { DeleteHandler } from '../DeleteHandler';
import {
  assertAllPermissions,
  assertAnyPermissions,
  assertBESAdminAccess,
  assertTupaiaAdminPanelAccess,
} from '../../permissions';
import { assertSurveyResponsePermissions } from './assertSurveyResponsePermissions';
import { AnalyticsRefresher } from '@tupaia/database';

/**
 * Handles DELETE endpoints:
 * - /surveyResponses/:surveyResponseId
 */

export class DeleteSurveyResponses extends DeleteHandler {
  async assertUserHasAccess() {
    // Check the user has either:
    // - BES admin access
    // - Permission to view the surveyResponse AND Tupaia Admin Panel access anywhere
    const surveyResponsePermissionChecker = accessPolicy =>
      assertSurveyResponsePermissions(accessPolicy, this.models, this.recordId);

    await this.assertPermissions(
      assertAnyPermissions([
        assertBESAdminAccess,
        assertAllPermissions([assertTupaiaAdminPanelAccess, surveyResponsePermissionChecker]),
      ]),
    );
  }

  async deleteRecord() {
    await super.deleteRecord();

    if (this.req.query.waitForAnalyticsRebuild === 'true') {
      const { database } = this.models;
      await AnalyticsRefresher.executeRefresh(database);
    }
  }
}
