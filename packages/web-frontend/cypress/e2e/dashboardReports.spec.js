/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import reportUrls from '../config/dashboardReports.json';
import { SNAPSHOTS } from '../constants';
import { preserveUserSession } from '../support';

const hasKeyOtherThan = (object, excludedKeys) =>
  Object.keys(object).find(key => !excludedKeys.includes(key));

const checkMatrixResponseHasData = response => {
  const { rows = [] } = response.body;
  // These keys are related to the structure of the matrix, not to its cell values
  const nonValueKeys = ['categoryId', 'dataElement'];
  return rows.length > 0 && rows.find(row => hasKeyOtherThan(row, nonValueKeys));
};

const checkResponseHasData = response => {
  const { body } = response;
  const hasSingleValue = body?.value !== undefined;
  const hasChartData = body?.data?.length > 0;

  return hasSingleValue || hasChartData;
  // return hasSingleValue || hasChartData || checkMatrixResponseHasData(response);
};

const urlToRouteRegex = url => {
  const queryParams = url.split('?').slice(1).join('');
  const viewId = new URLSearchParams(queryParams).get('report');
  if (!viewId) {
    throw new Error(`'${url}' is not a valid report url: it must contain a 'report' query param`);
  }

  return new RegExp(`view?.*\\WisExpanded=true&.*viewId=${viewId}[&$]`);
};

describe('Dashboard reports', () => {
  if (reportUrls.length === 0) {
    throw new Error('Dashboard report url list is empty');
  }
  const requireData = Cypress.config('tupaia_requireNonEmptyVisualisations');

  before(() => {
    cy.login();
  });

  beforeEach(() => {
    preserveUserSession();
  });

  reportUrls.forEach(url => {
    it(url, () => {
      cy.server();
      cy.route(urlToRouteRegex(url)).as('report');
      cy.visit(url);
      cy.wait('@report').then(({ response }) => {
        if (requireData) {
          const failureMessage = `Report '${url}' is empty`;
          expect(checkResponseHasData(response), failureMessage).to.be.true;
        }
      });

      cy.findByTestId('enlarged-dialog').as('enlargedDialog');
      // Capture and store the snapshot using the "new" key, to avoid comparison with existing snapshots.
      // We want to store the new snapshots no matter what: a failed comparison would prevent that
      cy.get('@enlargedDialog').snapshotHtml({ name: SNAPSHOTS.newKey });
      // Then, use the "standard" key to trigger a comparison with existing snapshots.
      // This way we check for regression
      cy.get('@enlargedDialog').snapshotHtml({ name: SNAPSHOTS.key });
    });
  });
});
