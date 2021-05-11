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

const BASE_DASHBOARD_REPORT = {
  id: 'PG_Strive_Average_Mosquito_Mortality',
  dataBuilder: 'tableOfDataValues',
};

const DATA_BUILDER_CONFIG = {
  rows: [
    {
      rows: [
        '0.03% Deltamethrin',
        '0.05% Deltamethrin',
        '0.05% Lambdacyhalothrin',
        '0.1% Bendiocarb',
        '0.8% Malathion',
        '4% DDT',
        '5% Malathion',
      ],
      category: 'Anopheles IR',
    },
    {
      rows: [
        '0.03% Deltamethrin',
        '0.05% Deltamethrin',
        '0.05% Lambdacyhalothrin',
        '0.1% Bendiocarb',
        '0.8% Malathion',
        '4% DDT',
        '5% Malathion',
      ],
      category: 'Aedes IR',
    },
  ],
  cells: [
    ['MAL_3645d4bf'],
    ['MAL_199ffeec'],
    ['MAL_46cfdeec'],
    ['MAL_566bceec'],
    ['MAL_47bb143e'],
    ['MAL_ORS'],
    ['MAL_5de7d4bf'],
    ['MAL_5de2a4bf'],
    ['MAL_47b2b43e'],
    ['MAL_Artesunate'],
    ['MAL_Paracetemol'],
  ],
  columns: ['Stock Status'],
  categoryAggregator: {
    type: '$condition',
    conditions: [
      {
        key: 'red',
        condition: {
          in: [null, 0],
        },
      },
      {
        key: 'green',
        condition: {
          '>': 0,
        },
      },
      {
        key: 'orange',
        condition: {
          someNotAll: {
            '>': 0,
          },
        },
      },
    ],
  },
};

exports.up = async function (db) {
  return null;
};

exports.down = async function (db) {
  return null;
};

exports._meta = {
  version: 1,
};
