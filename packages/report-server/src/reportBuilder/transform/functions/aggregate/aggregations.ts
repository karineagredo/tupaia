/* eslint-disable no-param-reassign */
/* eslint-disable @typescript-eslint/no-unused-vars */

/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { Row, FieldValue } from '../../../types';

const isUndefined = (value: FieldValue): value is undefined => {
  return value === undefined;
};

const group = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  existingRow[field] = value;
};

const sum = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  if (typeof value === 'number') {
    existingRow[field] = ((existingRow[field] as number) || 0) + value;
  } else {
    throw new Error(`Expected number, got '${typeof value}'.`);
  }
};

const count = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  existingRow[field] = ((existingRow[field] as number) || 0) + 1;
};

const avg = (existingRow: Row, field: string, value: FieldValue, props: { count?: number }) => {
  if (isUndefined(value)) {
    return;
  }

  if (typeof value !== 'number') {
    throw new Error(`Expected number, got '${typeof value}'.`);
  }

  const preExistingValue = isUndefined(existingRow[field]) ? 0 : (existingRow[field] as number);
  const preExistingCount = isUndefined(props.count) ? 0 : props.count;
  existingRow[field] = (preExistingValue * preExistingCount + value) / (preExistingCount + 1);
  props.count = preExistingCount + 1;
};

const max = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  const existingValue: FieldValue = existingRow[field];
  if (!isUndefined(value)) {
    if (isUndefined(existingValue)) {
      existingRow[field] = value;
    } else if (value > existingValue) {
      existingRow[field] = value;
    }
  }
};

const min = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  const existingValue: FieldValue = existingRow[field];
  if (!isUndefined(value)) {
    if (isUndefined(existingValue)) {
      existingRow[field] = value;
    } else if (value < existingValue) {
      existingRow[field] = value;
    }
  }
};

const unique = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  if (!isUndefined(existingRow[field]) && existingRow[field] !== value) {
    existingRow[field] = 'NO_UNIQUE_VALUE';
  } else {
    existingRow[field] = value;
  }
};

const drop = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  // Do nothing, don't add the field to the existing row
};

const first = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  if (isUndefined(existingRow[field])) {
    existingRow[field] = value;
  }
};

const last = (
  existingRow: Row,
  field: string,
  value: FieldValue,
  props: Record<string, unknown>,
) => {
  existingRow[field] = value;
};

export const aggregations = {
  group,
  sum,
  count,
  avg,
  max,
  min,
  unique,
  drop,
  first,
  last,
  default: last,
};
