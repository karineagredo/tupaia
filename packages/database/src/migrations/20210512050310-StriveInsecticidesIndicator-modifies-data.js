'use strict';

import { insertObject, generateId } from '../utilities';

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

const getIndicator = () => ({
  code: 'STRIVE_AE_003_DEL_Mortality',
  builder: 'analyticArithmetic',
  config: {
    formula: 'STRVEC_AE-IR02 === 0 ?? STRVEC_AE-IR09',
    aggregation: 'RAW',
    defaultValues: {
      'STRVEC_AE-IR02': 'undefined',
    },
  },
});
const insertIndicator = async db => {
  const indicator = getIndicator();
  await insertObject(db, 'indicator', { ...indicator, id: generateId() });
  await insertObject(db, 'data_source', {
    id: generateId(),
    code: indicator.code,
    type: 'dataElement',
    service_type: 'indicator',
  });
};

exports.up = function (db) {
  return insertIndicator(db);
};

exports.down = function (db) {
  return null;
};

exports._meta = {
  version: 1,
};
