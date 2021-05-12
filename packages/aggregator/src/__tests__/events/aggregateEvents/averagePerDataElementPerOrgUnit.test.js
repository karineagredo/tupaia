/**
 * Tupaia
 * Copyright (c) 2017 - 2021 Beyond Essential Systems Pty Ltd
 */

import { averagePerDataElementPerOrgUnit } from '../../../events/aggregateEvents/aggregations';

const BASE_TEST_EVENTS = [
  {
    event: '1',
    eventDate: '2021-02-22',
    orgUnit: 'org1',
    orgUnitName: 'orgName1',
    dataValues: { element1: 'value1', element2: 3 },
  },
  {
    event: '2',
    eventDate: '2021-02-23',
    orgUnit: 'org1',
    orgUnitName: 'orgName1',
    dataValues: { element1: 'value1', element2: 31 },
  },
  {
    event: '3',
    eventDate: '2021-02-23',
    orgUnit: 'org2',
    orgUnitName: 'orgName2',
    dataValues: { element1: 'value1', element2: 2 },
  },
  {
    event: '4',
    eventDate: '2021-02-24',
    orgUnit: 'org2',
    orgUnitName: 'orgName2',
    dataValues: { element1: 'value1', element2: 22 },
  },
];

describe('averagePerDataElementPerOrgUnit()', () => {
  it('should do nothing without orgUnitMap', () => {
    const aggregationConfig = { groupEventByDataElements: ['element1'], target };
    expect(averagePerDataElementPerOrgUnit(BASE_TEST_EVENTS, {})).toIncludeSameMembers([
      { dataElement: 'element1', organisationUnit: 'org1', period: '20200101', value: 1 },
      { dataElement: 'element1', organisationUnit: 'org2', period: '20200102', value: 2 },
      { dataElement: 'element1', organisationUnit: 'org3', period: '20200103', value: 3 },
    ]);
  });
});
