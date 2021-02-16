/**
 * Tupaia Config Server
 * Copyright (c) 2019 Beyond Essential Systems Pty Ltd
 */

const OPTIONS = {
  1: 'One',
  2: 'Two',
  3: 'Three',
  4: 'Four',
  5: 'Five',
  6: 'Six',
  7: 'Seven',
  8: 'Eight',
};

export const DATA_ELEMENTS = {
  CD1: { code: 'CD1', name: 'Risk Factor: Smokers Female' },
  CD2: { code: 'CD2', name: 'Risk Factor: Smokers Male' },
  CD3: { code: 'CD3', name: 'Risk Factor: Overweight Female' },
  CD4: { code: 'CD4', name: 'Risk Factor: Overweight Male' },
  CD5: { code: 'CD5', name: 'CVD Risk: Green Female' },
  CD6: { code: 'CD6', name: 'CVD Risk: Green Male' },
  CD7: { code: 'CD7', name: 'CVD Risk: Red Female' },
  CD8: { code: 'CD_Description', name: 'CD Description' },
  HP1: { code: 'HP1', name: 'Fitness: 10-19 years - female', options: OPTIONS },
  HP2: { code: 'HP2', name: 'Fitness: 10-19 years - male', options: OPTIONS },
  HP3: { code: 'HP3', name: 'Fitness: 20-39 years - female', options: OPTIONS },
  HP4: { code: 'HP4', name: 'Fitness: 20-39 years - male', options: OPTIONS },
  HP5: { code: 'HP5', name: 'Fitness: 40-59 years - female', options: OPTIONS },
  HP6: { code: 'HP6', name: 'Fitness: 40-59 years - male', options: OPTIONS },
  HP7: { code: 'HP7', name: 'Fitness: 60+ years - female', options: OPTIONS },
  HP8: { code: 'HP8', name: 'Fitness: 60+ years - male', options: OPTIONS },
};

export const DATA_VALUES = [
  // Note: Data should not be sorted by org unit name,
  // so that we can assert this as part of the tests
  // Vaini
  { dataElement: 'CD1', value: 10, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD2', value: 20, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD3', value: 30, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD4', value: 40, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD5', value: 50, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD6', value: 60, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD7', value: 70, organisationUnit: 'TO1_Vainihc' },
  { dataElement: 'CD8', value: 80, organisationUnit: 'TO1_Vainihc' },
  // Nukunuku
  { dataElement: 'CD1', value: 1, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD2', value: 2, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD3', value: 3, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD4', value: 4, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD5', value: 5, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD6', value: 6, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD7', value: 7, organisationUnit: 'TO2_Nukuhc' },
  { dataElement: 'CD8', value: 8, organisationUnit: 'TO2_Nukuhc' },
  {
    dataElement: 'CD_Description',
    value: 'Communicable diseases description',
    organisationUnit: 'TO2_Nukuhc',
  },
  // Haveluloto (with Options)
  { dataElement: 'HP1', value: 1, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP2', value: 2, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP3', value: 3, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP4', value: 4, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP5', value: 5, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP6', value: 6, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP7', value: 7, organisationUnit: 'TO3_HvlMCH' },
  { dataElement: 'HP8', value: 8, organisationUnit: 'TO3_HvlMCH' },
];

export const ORG_UNITS = [
  // Org unit codes are in a different alphabetical order
  // than the names on purpose
  { code: 'TO1_Vainihc', name: 'Vaini' },
  { code: 'TO2_Nukuhc', name: 'Nukunuku' },
  { code: 'TO3_HvlMCH', name: 'Haveluloto' },
];
