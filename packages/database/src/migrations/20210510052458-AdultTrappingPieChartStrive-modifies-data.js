'use strict';

import { insertObject } from '../utilities';

var dbm;
var type;
var seed;

/**
 * We receive the dbmigrate dependency from dbmigrate initially.
 * This enables us to not have to rely on NODE_PATH.
 */
exports.setup = function (options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

const dataElementCode = 'STRVEC_AE-AT13';

const species = [
  'Ae. aegypti',
  'Ae. albopictus',
  'Ae. scutellaris',
  'Aedes Other',
  'Aedes spp.',
  'An. farauti',
  'An. koliensis',
  'An. longirostris',
  'An. punctulatus',
  'Culex spp.',
  'Cx. annulirostris',
  'Cx. quinquefasciatus',
  'Cx. sitiens',
  'Mansoni spp.',
];

const dashboardGroupCodes = [
  ['PG_Strive_PNG_Country', 'country'],
  ['PG_Strive_PNG_District', 'district'],
  ['PG_Strive_PNG_Facility', 'facility'],
];

const getId = level => `PG_Strive_Adult_Trapping_${level}`;
const getEntityAggregation = level => {
  const aggregationEntityType = level === 'facility' ? {} : level;
  return {
    dataSourceEntityType: 'facility',
    ...aggregationEntityType,
  };
};

const getBaseDashboardReport = level => ({
  id: getId(level),
  dataBuilder: 'percentagesOfValueCounts',
  dataServices: [
    {
      isDataRegional: true,
    },
  ],
});

const getDataClasses = level => {
  const result = {};
  species.forEach((specie, index) => {
    result[specie] = {
      numerator: {
        dataValues: [dataElementCode],
        valueOfInterest: index,
        entityAggregation: getEntityAggregation(level),
      },
      denominator: {
        dataValues: [dataElementCode],
        valueOfInterest: '*',
        entityAggregation: getEntityAggregation(level),
      },
    };
  });
  return result;
};

const viewJson = {
  name: 'Distribution of mosquito species collected',
  type: 'chart',
  chartType: 'pie',
  valueType: 'fractionAndPercentage',
};

exports.up = async function (db) {
  for (const [dashboardGroupCode, hierarchyLevel] of dashboardGroupCodes) {
    const baseDashboardReport = getBaseDashboardReport(hierarchyLevel);
    await insertObject(db, 'dashboardReport', {
      ...baseDashboardReport,
      dataBuilderConfig: { dataClasses: getDataClasses(hierarchyLevel) },
      viewJson,
    });

    await db.runSql(`
      UPDATE "dashboardGroup"
      SET "dashboardReports" = "dashboardReports" || '{${baseDashboardReport.id}}'
      WHERE code = '${dashboardGroupCode}';
    `);
  }
};

exports.down = async function (db) {
  for (const [dashboardGroupCode, hierarchyLevel] of dashboardGroupCodes) {
    const baseDashboardReport = getBaseDashboardReport(hierarchyLevel);
    await db.runSql(`
      DELETE FROM "dashboardReport" WHERE id = '${baseDashboardReport.id}'
  `);

    await db.runSql(`    
      UPDATE "dashboardGroup"
      SET "dashboardReports" = array_remove("dashboardReports", '${baseDashboardReport.id}')
      WHERE code = '${dashboardGroupCode}';
  `);
  }
};

exports._meta = {
  version: 1,
};
