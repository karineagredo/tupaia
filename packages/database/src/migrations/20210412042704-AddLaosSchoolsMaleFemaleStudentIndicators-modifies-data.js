'use strict';

import { arrayToDbString, generateId, insertObject } from '../utilities';

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

const insertIndicator = async (db, indicator) => {
  await insertObject(db, 'indicator', { ...indicator, id: generateId() });
  await insertObject(db, 'data_source', {
    id: generateId(),
    code: indicator.code,
    type: 'dataElement',
    service_type: 'indicator',
  });
};

exports.up = async function (db) {
  await insertIndicator(db, {
    code: 'Laos_Schools_Male_Students',
    builder: 'analyticArithmetic',
    config: {
      formula:
        'SchPop002 + SchPop004 + SchPop006 + SchPop008 + SchPop010 + SchPop012 + SchPop014 + SchPop016 + SchPop018 + SchPop020 + SchPop022 + SchPop024 + SchPop026 + SchPop028 + SchPop030 + SchPop032 + SchPop034',
      aggregation: {
        type: 'SUM_PER_ORG_GROUP',
        config: {
          dataSourceEntityType: 'school',
          aggregationEntityType: 'requested',
        },
      },
      defaultValues: {
        SchPop002: 0,
        SchPop004: 0,
        SchPop006: 0,
        SchPop008: 0,
        SchPop010: 0,
        SchPop012: 0,
        SchPop014: 0,
        SchPop016: 0,
        SchPop018: 0,
        SchPop020: 0,
        SchPop022: 0,
        SchPop024: 0,
        SchPop026: 0,
        SchPop028: 0,
        SchPop030: 0,
        SchPop032: 0,
        SchPop034: 0,
      },
    },
  });
  await insertIndicator(db, {
    code: 'Laos_Schools_Female_Students',
    builder: 'analyticArithmetic',
    config: {
      formula:
        'SchPop001 + SchPop003 + SchPop005 + SchPop007 + SchPop009 + SchPop011 + SchPop013 + SchPop015 + SchPop017 + SchPop019 + SchPop021 + SchPop023 + SchPop025 + SchPop027 + SchPop029 + SchPop031 + SchPop033',
      aggregation: {
        type: 'SUM_PER_ORG_GROUP',
        config: {
          dataSourceEntityType: 'school',
          aggregationEntityType: 'requested',
        },
      },
      defaultValues: {
        SchPop001: 0,
        SchPop003: 0,
        SchPop005: 0,
        SchPop007: 0,
        SchPop009: 0,
        SchPop011: 0,
        SchPop013: 0,
        SchPop015: 0,
        SchPop017: 0,
        SchPop019: 0,
        SchPop021: 0,
        SchPop023: 0,
        SchPop025: 0,
        SchPop027: 0,
        SchPop029: 0,
        SchPop031: 0,
        SchPop033: 0,
      },
    },
  });
  await insertIndicator(db, {
    code: 'Laos_Schools_Students',
    builder: 'analyticArithmetic',
    config: {
      formula: 'Laos_Schools_Male_Students + Laos_Schools_Female_Students',
    },
  });
};

exports.down = async function (db) {
  const codes = [
    'Laos_Schools_Students',
    'Laos_Schools_Male_Students',
    'Laos_Schools_Female_Students',
  ];

  await db.runSql(`DELETE FROM indicator WHERE code IN (${arrayToDbString(codes)})`);
  await db.runSql(`DELETE FROM data_source WHERE code IN (${arrayToDbString(codes)})`);
};

exports._meta = {
  version: 1,
};
