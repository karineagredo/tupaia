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

const dataElementCode = 'STRVEC_LHS13';

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

const dashboardGroupCode = 'PG_Strive_PNG_Country';

const dashboardReport = {
  id: 'PG_Strive_Larvae_Species_Found',
  dataBuilder: 'percentagesOfValueCounts',
  dataServices: [
    {
      isDataRegional: true,
    },
  ],
};

const getDataClasses = () => {
  const result = {};
  species.forEach((specie, index) => {
    result[specie] = {
      numerator: { dataValues: [dataElementCode], valueOfInterest: index },
      denominator: {
        dataValues: [dataElementCode],
        valueOfInterest: '*',
      },
    };
  });
  return result;
};

const dataBuilderConfig = {
  dataClasses: getDataClasses(),
  entityAggregation: {
    dataSourceEntityType: 'country',
  },
};

const viewJson = {
  name: 'Larvae Species Found',
  type: 'chart',
  chartType: 'pie',
  valueType: 'fractionAndPercentage',
};

exports.up = async function (db) {
  await insertObject(db, 'dashboardReport', {
    ...dashboardReport,
    dataBuilderConfig,
    viewJson,
  });

  await db.runSql(`
    UPDATE "dashboardGroup"
    SET "dashboardReports" = "dashboardReports" || '{${dashboardReport.id}}'
    WHERE code = '${dashboardGroupCode}';
  `);
};

exports.down = async function (db) {
  await db.runSql(`
    DELETE FROM "dashboardReport" WHERE id = '${dashboardReport.id}'
  `);

  return db.runSql(`    
  UPDATE "dashboardGroup"
  SET "dashboardReports" = array_remove("dashboardReports", '${dashboardReport.id}')
  WHERE code = '${dashboardGroupCode}';
`);
};

exports._meta = {
  version: 1,
};
