/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */

/**
 * https://babeljs.io/docs/en/config-files#jest
 *
 * Setup jest in Monorepo. This is to create a custom jest transformer file that wraps babel-jest.
 *
 * @type {Transformer}
 */
module.exports = require('babel-jest').createTransformer({
  rootMode: 'upward',
});
