'use strict';

import { TupaiaDatabase } from '../TupaiaDatabase';

var dbm;
var type;
var seed;

/**
  * We receive the dbmigrate dependency from dbmigrate initially.
  * This enables us to not have to rely on NODE_PATH.
  */
exports.setup = function(options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

exports.up = async function() {
  const db = new TupaiaDatabase();
  await db.executeSql(`
    ALTER TYPE public.entity_type ADD VALUE 'case_contact';
  `);
  return db.closeConnections();
};

exports.down = function(db) {
// there is no remove value for ALTER TYPE in psql :(
  return null;
};

exports._meta = {
  "version": 1
};
