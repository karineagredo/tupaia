/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import { QueryParameters } from '@tupaia/server-boilerplate';
import { SessionHandlingApiConnection } from './SessionHandlingApiConnection';

const { REPORT_API_URL = 'http://localhost:8030/v2' } = process.env;

type ReportObject = {
  results: Record<string, unknown>[];
};
type RequestBody = Record<string, unknown> | Record<string, unknown>[];
export class ReportConnection extends SessionHandlingApiConnection {
  baseUrl = REPORT_API_URL;

  async fetchReport(reportCode: string, query: QueryParameters, body: RequestBody) {
    return this.post(`fetchReport/${reportCode}`, query, body);
  }
}
