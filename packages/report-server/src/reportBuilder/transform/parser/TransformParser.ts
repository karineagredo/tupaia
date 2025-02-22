/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { ExpressionParser } from '@tupaia/expression-parser';
import { Row, FieldValue } from '../../types';

type RowLookup = {
  [key: string]: FieldValue[];
};

/**
 * Lookups object for rows within the transform data
 *
 * eg. if rows = [{BCD1: 5}, {BCD1: 8}, {BCD1: 4}], and currentRow = 1
 * '$row.BCD1' => 8
 * '$all.BCD1' => [5, 8, 4]
 * '$allPrevious.BCD1' => [5, 8]
 * '$where(f($otherRow) = $otherRow.BCD1 < $row.BCD1).BCD1' => [5, 4]
 * '$row.BCD1 + sum($allPrevious.BCD1)' => 21
 */
type Lookups = {
  row: Row;
  all: RowLookup;
  allPrevious: RowLookup;
  where: (check: (row: Row) => boolean) => RowLookup;
};

export class TransformParser extends ExpressionParser {
  private currentRow = 0;

  private rows: Row[];

  private lookups: Lookups;

  constructor(rows: Row[], additionalFunctions: { [key: string]: (...params: any[]) => any }) {
    super();

    this.rows = rows;
    this.lookups = { row: {}, all: {}, allPrevious: {}, where: this.whereFunction };

    if (rows.length > 0) {
      this.lookups.row = this.rows[this.currentRow];
      this.rows.forEach(row => addRowToLookup(row, this.lookups.all));
      addRowToLookup(this.lookups.row, this.lookups.allPrevious);

      Object.entries(this.lookups).forEach(([lookupName, lookup]) => {
        this.set(`$${lookupName}`, lookup);
      });
    }

    Object.entries(additionalFunctions).forEach(([functionName, functionCall]) => {
      this.set(functionName, functionCall);
    });
  }

  next() {
    this.currentRow++;

    if (this.currentRow >= this.rows.length) {
      return;
    }

    this.lookups.row = this.rows[this.currentRow];
    this.set('$row', this.lookups.row);
    addRowToLookup(this.lookups.row, this.lookups.allPrevious);
  }

  whereFunction = (check: (row: Row) => boolean) => {
    const whereData = {};
    const filteredRows = this.rows.filter(rowInFilter => check(rowInFilter));
    filteredRows.forEach(row => {
      addRowToLookup(row, whereData);
    });
    return whereData;
  };
}

const addRowToLookup = (row: Row, lookup: RowLookup) => {
  Object.entries(row).forEach(([field, value]) => {
    if (value !== undefined && value !== null) {
      if (!(field in lookup)) {
        lookup[field] = [];
      }
      lookup[field].push(value);
    }
  });
};
