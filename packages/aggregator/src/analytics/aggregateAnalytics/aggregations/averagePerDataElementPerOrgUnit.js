/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { convertToPeriod, isFuturePeriod, getCurrentPeriod, PERIOD_TYPES } from '@tupaia/utils';

/**
 * Add the analytics together across the periods listed in the analytic response, and return an array
 * with just one analytic per data element/organisation unit pair
 */
export const averagePerDataElementPerOrgUnit = (analytics, aggregationConfig) => {
  const totalsByDataElementAndOrgUnit = [];
  analytics.forEach(analytic => {
    const i = summedAnalytics.findIndex(
      otherAnalytic =>
        analytic.dataElement === otherAnalytic.dataElement &&
        analytic.organisationUnit === otherAnalytic.organisationUnit,
    );
    // If there are no matching response elements already being returned, add it
    if (i < 0) {
      summedAnalytics.push({ ...analytic });
    } else {
      summedAnalytics[i].value += analytic.value;
    }
  });

  return summedAnalytics;
};
