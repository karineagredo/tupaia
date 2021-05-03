'use strict';

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

exports.up = function (db) {
  return db.runSql(`
    UPDATE "dashboardReport"
      SET "dataBuilderConfig" = jsonb_set("dataBuilderConfig" #- '{entityAggregation, includeSiblingData}', '{entityAggregation, aggregationConfig, includeSiblingData}', 'true', true)
        WHERE "dataBuilderConfig"#>>'{entityAggregation, includeSiblingData}' = 'true';
  `);
};

exports.down = function (db) {
  return db.runSql(`
    UPDATE "dashboardReport"
    SET "dataBuilderConfig" = jsonb_set("dataBuilderConfig" #- '{entityAggregation, aggregationConfig, includeSiblingData}', '{entityAggregation, includeSiblingData}', 'true', true)
      WHERE "dataBuilderConfig"#>>'{entityAggregation, aggregationConfig, includeSiblingData}' = 'true';
  `);
};

exports._meta = {
  version: 1,
};
