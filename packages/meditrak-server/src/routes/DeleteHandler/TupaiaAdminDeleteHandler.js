/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { DeleteHandler } from './DeleteHandler';
import { assertTupaiaAdminPanelAccess } from '../../permissions';

export class TupaiaAdminDeleteHandler extends DeleteHandler {
  async assertUserHasAccess() {
    await this.assertPermissions(assertTupaiaAdminPanelAccess);
  }
}
