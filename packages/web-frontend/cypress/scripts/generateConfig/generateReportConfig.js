/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { snake } from 'case';
import moment from 'moment';

import {
  compareAsc,
  filterEntities,
  filterValues,
  getLoggerInstance,
  stringifyQuery,
  toArray,
} from '@tupaia/utils';
import datesByGranularity from '../../config/datesByGranularity.json';
import orgUnitMap from '../../config/orgUnitMap.json';
import { convertDateRangeToUrlPeriodString } from '../../../src/historyNavigation/utils';

const WARNING_TYPES = {
  DRILL_DOWN: 'drillDown',
  NO_DATA_BUILDER: 'noDataBuilder',
  NO_GROUP: 'noGroup',
  NO_PROJECT: 'noProject',
};

const WARNING_TYPE_TO_MESSAGE = {
  [WARNING_TYPES.DRILL_DOWN]: `Drill down levels are not supported`,
  [WARNING_TYPES.NO_DATA_BUILDER]: `No data builder`,
  [WARNING_TYPES.NO_GROUP]: 'Not attached to any dashboard group',
  [WARNING_TYPES.NO_PROJECT]: 'Not attached to any projects',
};

const logWarningsForSkippedReports = skippedReports => {
  const logger = getLoggerInstance();
  logger.warn(`Skipping the following reports:`);
  Object.entries(skippedReports).forEach(([warnType, reportIds]) => {
    const message = WARNING_TYPE_TO_MESSAGE[warnType];
    if (!message) {
      throw new Error(`Dev error: no message defined for warning category: '${warnType}'`);
    }
    logger.warn(`* ${message}:`);
    reportIds.sort().forEach(reportId => {
      logger.warn(`  ${reportId}`);
    });
  });
};

const createUrl = (report, urlParams) => {
  const { projectCode, orgUnitCode, dashboardGroup, reportPeriod } = urlParams;
  const path = [projectCode, orgUnitCode, dashboardGroup.name].map(encodeURIComponent).join('/');
  const queryParams = {
    report: report.id,
    reportPeriod,
  };

  return stringifyQuery('', path, queryParams);
};

/**
 * @returns {string|undefined}
 */
const selectPeriod = viewJson => {
  const { periodGranularity } = viewJson;
  if (!periodGranularity) {
    return undefined;
  }

  const dateInput = datesByGranularity[periodGranularity];
  if (!dateInput) {
    throw new Error(
      `Please add a non empty entry for '${periodGranularity}' in datesByGranularity.json`,
    );
  }

  const [startDate, endDate] = Array.isArray(dateInput) ? dateInput : [dateInput, dateInput];
  return convertDateRangeToUrlPeriodString({
    startDate: moment(startDate),
    endDate: moment(endDate),
  });
};

const selectEntities = async (db, codes) =>
  db.executeSql(`SELECT * FROM entity WHERE code IN (${codes.map(() => '?').join(',')})`, codes);
/**
 * @returns {Promise<string|undefined>}
 */
const selectOrgUnitCode = async (db, orgUnitCodes, entityConditions) => {
  if (orgUnitCodes.length === 0 || !entityConditions) {
    return orgUnitCodes[0];
  }

  const entities = await selectEntities(db, orgUnitCodes);
  return filterEntities(entities, entityConditions)[0]?.code;
};

const selectUrlParams = async (db, report, dashboardGroups) => {
  const viewJson = report.viewJson || {};

  const attemptedMapEntries = [];
  for (const dashboardGroup of dashboardGroups) {
    const {
      organisationUnitCode: dashboardOrgUnitCode,
      organisationLevel: dashboardLevel,
    } = dashboardGroup;

    const level = snake(dashboardLevel);
    const [entity] = await selectEntities(db, [dashboardOrgUnitCode]);
    const orgUnitMapKey = entity.country_code || entity.code;
    attemptedMapEntries.push({ key: orgUnitMapKey, level });

    const orgUnitCodes = toArray(orgUnitMap?.[orgUnitMapKey]?.[level]);
    const orgUnitCode = await selectOrgUnitCode(
      db,
      orgUnitCodes,
      viewJson.displayOnEntityConditions,
    );
    const [projectCode] = dashboardGroup.projectCodes;

    if (orgUnitCode && projectCode) {
      const reportPeriod = selectPeriod(viewJson);
      return { dashboardGroup, orgUnitCode, projectCode, reportPeriod };
    }
  }

  // No compatible entry found, throw error
  throw new Error(
    [
      `No compatible org unit map entry found for report '${report.id}'`,
      'Try using one of the following entries:',
      ...attemptedMapEntries.map(({ key, level }) => `* Key: '${key}', level: '${level}'`),
    ].join('\n'),
  );
};

const getUrlsForReports = async (db, reports, reportIdToGroups) => {
  const skippedReports = Object.fromEntries(
    Object.values(WARNING_TYPES).map(warnType => [warnType, []]),
  );
  const addSkippedReport = (warnType, reportDescription) => {
    skippedReports[warnType].push(reportDescription);
  };

  const getUrlForReport = async report => {
    const { dataBuilder, drillDownLevel } = report;

    if (drillDownLevel) {
      addSkippedReport(WARNING_TYPES.DRILL_DOWN, `${report.id} - level ${drillDownLevel}`);
      return null;
    }

    if (!dataBuilder) {
      addSkippedReport(WARNING_TYPES.NO_DATA_BUILDER, report.id);
      return null;
    }

    const groupsForReport = reportIdToGroups[report.id];
    if (!groupsForReport) {
      addSkippedReport(WARNING_TYPES.NO_GROUP, report.id);
      return null;
    }

    if (!groupsForReport.some(dg => dg.projectCodes)) {
      addSkippedReport(WARNING_TYPES.NO_PROJECT, report.id);
      return null;
    }

    const urlParams = await selectUrlParams(db, report, groupsForReport);
    return createUrl(report, urlParams);
  };
  const urls = await Promise.all(reports.map(getUrlForReport));

  return {
    urls: urls.filter(u => u).sort(compareAsc),
    skippedReports: filterValues(skippedReports, r => r.length > 0),
  };
};

const getReportIdToGroups = async db => {
  const dashboardGroups = await db.executeSql(`SELECT * from "dashboardGroup"`);

  const reportIdToGroups = {};
  dashboardGroups.forEach(dashboardGroup => {
    dashboardGroup.dashboardReports.forEach(reportId => {
      if (!reportIdToGroups[reportId]) {
        reportIdToGroups[reportId] = [];
      }
      reportIdToGroups[reportId].push(dashboardGroup);
    });
  });
  return reportIdToGroups;
};

/**
 * We generate the least amount of config required to test each report once.
 * 1. For each report, use the last dashboard group that includes it
 * 2. For each dashboard group, use the first project that includes it
 * 3. For each dashboard group, use an organisation unit from the orgUnitMap config
 * that matches the group's org unit code and level
 */
export const generateReportConfig = async db => {
  const logger = getLoggerInstance();
  const reports = await db.executeSql('SELECT * from "dashboardReport"');
  const reportIdToGroups = await getReportIdToGroups(db);
  const { urls, skippedReports } = await getUrlsForReports(db, reports, reportIdToGroups);
  const skippedReportsExist = Object.keys(skippedReports).length > 0;
  if (skippedReportsExist) {
    logWarningsForSkippedReports(skippedReports);
  }
  logger.info(`Report urls created: ${urls.length}, skipped: ${reports.length - urls.length}`);

  return urls;
};
