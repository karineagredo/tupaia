'use strict';

import { insertObject, generateId } from '../utilities';

var dbm;
var type;
var seed;

const permissionGroupNameToId = async (db, name) => {
  const record = await db.runSql(`SELECT id FROM permission_group WHERE name = '${name}'`);
  return record.rows[0] && record.rows[0].id;
};

const REPORT_CODE = 'LESMIS_student_gender_stacked_bar';

/**
 * We receive the dbmigrate dependency from dbmigrate initially.
 * This enables us to not have to rely on NODE_PATH.
 */
exports.setup = function (options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

exports.up = async function (db) {
  await insertObject(db, 'report', {
    id: generateId(),
    code: REPORT_CODE,
    config: {
      fetch: {
        dataElements: [
          'SchPop001',
          'SchPop002',
          'SchPop003',
          'SchPop004',
          'SchPop005',
          'SchPop006',
          'SchPop007',
          'SchPop008',
          'SchPop009',
          'SchPop010',
          'SchPop011',
          'SchPop012',
          'SchPop013',
          'SchPop014',
          'SchPop015',
          'SchPop016',
          'SchPop017',
          'SchPop018',
          'SchPop019',
          'SchPop020',
          'SchPop021',
          'SchPop022',
          'SchPop023',
          'SchPop024',
          'SchPop025',
          'SchPop026',
          'SchPop027',
          'SchPop028',
          'SchPop029',
          'SchPop030',
          'SchPop031',
          'SchPop032',
          'SchPop033',
          'SchPop034',
        ],
        aggregations: [
          {
            type: 'SUM_PER_ORG_GROUP',
            config: {
              dataSourceEntityType: 'school',
              aggregationEntityType: 'requested',
            },
          },
        ],
      },
      transform: [
        {
          transform: 'select',
          "'name'":
            "eq($row.dataElement, 'SchPop001') ? 'Nursery' : eq($row.dataElement, 'SchPop002') ? 'Nursery' : eq($row.dataElement, 'SchPop003') ? 'Kindy 1' : eq($row.dataElement, 'SchPop004') ? 'Kindy 1' : eq($row.dataElement, 'SchPop005') ? 'Kindy 2' : eq($row.dataElement, 'SchPop006') ? 'Kindy 2' : eq($row.dataElement, 'SchPop007') ? 'Kindy 3' : eq($row.dataElement, 'SchPop008') ? 'Kindy 3' : eq($row.dataElement, 'SchPop009') ? 'PrePrimary' : eq($row.dataElement, 'SchPop010') ? 'PrePrimary' :eq($row.dataElement, 'SchPop011') ? 'Grade 1' : eq($row.dataElement, 'SchPop012') ? 'Grade 1' : eq($row.dataElement, 'SchPop013') ? 'Grade 2' : eq($row.dataElement, 'SchPop014') ? 'Grade 2' : eq($row.dataElement, 'SchPop015') ? 'Grade 3' : eq($row.dataElement, 'SchPop016') ? 'Grade 3' : eq($row.dataElement, 'SchPop017') ? 'Grade 4' : eq($row.dataElement, 'SchPop018') ? 'Grade 4' : eq($row.dataElement, 'SchPop019') ? 'Grade 5' : eq($row.dataElement, 'SchPop020') ? 'Grade 5' : eq($row.dataElement, 'SchPop021') ? 'Grade 6' : eq($row.dataElement, 'SchPop022') ? 'Grade 6' : eq($row.dataElement, 'SchPop023') ? 'Grade 7' : eq($row.dataElement, 'SchPop024') ? 'Grade 7' : eq($row.dataElement, 'SchPop025') ? 'Grade 8' : eq($row.dataElement, 'SchPop026') ? 'Grade 8' : eq($row.dataElement, 'SchPop027') ? 'Grade 9' : eq($row.dataElement, 'SchPop028') ? 'Grade 9' : eq($row.dataElement, 'SchPop029') ? 'Grade 10' : eq($row.dataElement, 'SchPop030') ? 'Grade 10' : eq($row.dataElement, 'SchPop031') ? 'Grade 11' : eq($row.dataElement, 'SchPop032') ? 'Grade 11' : eq($row.dataElement, 'SchPop033') ? 'Grade 12' : eq($row.dataElement, 'SchPop034') ? 'Grade 12' : 'err'",
          '...': '*',
        },
        {
          transform: 'sort',
          by: '$row.dataElement',
        },
        'keyValueByDataElementName',
        {
          transform: 'aggregate',
          name: 'group',
          '...': 'last',
        },
        {
          transform: 'select',
          "'Male'":
            'sum([$row.SchPop002,$row.SchPop004,$row.SchPop006,$row.SchPop008,$row.SchPop010,$row.SchPop012,$row.SchPop014,$row.SchPop016,$row.SchPop018,$row.SchPop020,$row.SchPop022,$row.SchPop024,$row.SchPop026,$row.SchPop028,$row.SchPop030,$row.SchPop032,$row.SchPop034])',
          "'Female'":
            'sum([$row.SchPop001,$row.SchPop003,$row.SchPop005,$row.SchPop007,$row.SchPop009,$row.SchPop011,$row.SchPop013,$row.SchPop015,$row.SchPop017,$row.SchPop019,$row.SchPop021,$row.SchPop023,$row.SchPop025,$row.SchPop027,$row.SchPop029,$row.SchPop031,$row.SchPop033])',
          '...': ['name'],
        },
      ],
    },
    permission_group_id: await permissionGroupNameToId(db, 'LESMIS Public'),
  });
};

exports.down = async function (db) {
  await db.runSql(`
    DELETE FROM report
    WHERE code = '${REPORT_CODE}';
  `);
};

exports._meta = {
  version: 1,
};
