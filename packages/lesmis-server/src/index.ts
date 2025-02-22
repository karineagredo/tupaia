/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

import '@babel/polyfill';

import * as dotenv from 'dotenv';

import http from 'http';

import { createApp } from './app';
import winston from './log';

dotenv.config(); // Load the environment variables into process.env

/**
 * Set up app with routes etc.
 */
const app = createApp();

/**
 * Start the server
 */
const port = process.env.PORT || 8060;
http.createServer(app).listen(port);
winston.info(`Running on port ${port}`);

/**
 * Notify PM2 that we are ready
 * */
if (process.send) {
  process.send('ready');
}
