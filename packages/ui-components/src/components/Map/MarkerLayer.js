/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 *
 */
import React from 'react';
import styled from 'styled-components';
import PropTypes from 'prop-types';
import { LayerGroup, Polygon } from 'react-leaflet';
import { MeasureMarker, MeasurePopup } from './Markers';
import { AreaTooltip } from './AreaTooltip';
import { getSingleFormattedValue, MEASURE_TYPE_RADIUS } from './utils';

const ShadedPolygon = styled(Polygon)`
  weight: 1;
  fill-opacity: 0.5;
  :hover {
    fill-opacity: 0.8;
  }
`;

// remove name from the measure data as it's not expected in getSingleFormattedValue
const getTooltipText = ({ name, ...markerData }, serieses) =>
  `${name}: ${getSingleFormattedValue(markerData, serieses)}`;

export const MarkerLayer = ({ measureData, serieses }) => {
  if (!measureData || !serieses) return null;

  // for radius overlay sort desc radius to place smaller circles over larger circles
  if (serieses.some(l => l.type === MEASURE_TYPE_RADIUS)) {
    measureData.sort((a, b) => Number(b.radius) - Number(a.radius));
  }

  return (
    <LayerGroup>
      {measureData.map(measure =>
        measure.region ? (
          <ShadedPolygon
            key={`${measure.code}-${measure.color}`}
            positions={measure.region}
            {...measure}
          >
            <AreaTooltip text={getTooltipText(measure, serieses)} />
          </ShadedPolygon>
        ) : (
          <MeasureMarker key={measure.code} {...measure}>
            <MeasurePopup markerData={measure} serieses={serieses} />
          </MeasureMarker>
        ),
      )}
    </LayerGroup>
  );
};

MarkerLayer.propTypes = {
  measureData: PropTypes.array,
  serieses: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      value: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
    }),
  ),
};

MarkerLayer.defaultProps = {
  measureData: null,
  serieses: null,
};
