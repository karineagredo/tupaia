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

const dataBuilderConfig = {
  dataClasses: {
    'Ae. aegypti': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 0,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Ae. albopictus': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 1,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Ae. scutellaris': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 2,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Aedes Other': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 3,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Aedes spp.': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 4,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'An. farauti': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 5,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'An. koliensis': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 6,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'An. longirostris': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 7,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'An. punctulatus': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 8,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Culex spp.': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 9,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Cx. annulirostris': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 10,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
    'Cx. quinquefasciatus': {
      numerator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: 11,
      },
      denominator: {
        dataValues: ['STRVEC_LHS13'],
        valueOfInterest: '*',
      },
    },
  },
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
