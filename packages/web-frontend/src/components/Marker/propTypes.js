/**
 * Tupaia Web
 * Copyright (c) 2019 Beyond Essential Systems Pty Ltd.
 * This source code is licensed under the AGPL-3.0 license
 * found in the LICENSE file in the root directory of this source tree.
 */

import PropTypes from 'prop-types';

export const MarkerDataPropType = PropTypes.shape({
  coordinates: PropTypes.arrayOf(PropTypes.number),
  value: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
  photoUrl: PropTypes.string,
  organisationUnitCode: PropTypes.string,
  name: PropTypes.string,
});

export const MeasureOptionsPropType = PropTypes.shape({
  name: PropTypes.string,
  value: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
});

export const MeasureOptionsGroupPropType = PropTypes.arrayOf(MeasureOptionsPropType);
