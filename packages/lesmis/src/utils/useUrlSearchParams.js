/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 *
 */
import { useState } from 'react';
import history from 'history/browser';

export const { location } = history;

export const useUrlSearchParams = ({ search }) => {
  console.log('hook', search);
  const urlParams = new URLSearchParams(search);

  const setParams = newParams => {
    Object.entries(newParams).forEach(([key, param]) => {
      if (param === null || param === undefined) {
        urlParams.delete(key);
      } else {
        urlParams.set(key, param.toString());
      }
    });

    if (location.search !== urlParams.toString()) {
      history.push({ ...location, search: `?${urlParams.toString()}` });
    }
  };

  const params = {};

  urlParams.forEach((value, key) => {
    params[key] = value;
  });

  return [params, setParams];
};

export const useUrlSearchParam = (historyLocation, param, defaultValue = null) => {
  const [params, setParams] = useUrlSearchParams(historyLocation);

  const setSelectedParam = newValue => {
    setParams({ [param]: newValue });
  };

  const selectedParam = params[param] || defaultValue;

  return [selectedParam, setSelectedParam];
};

export const useStartDateParam = () => {
  const key = 'startDate';
  const [param, setParamState] = useState(null);

  const { search } = history.location;
  const urlParams = new URLSearchParams(search);

  const setParam = newParam => {
    if (newParam === null || newParam === undefined) {
      urlParams.delete(key);
      setParamState(null);
    } else {
      urlParams.set(key, newParam.toString());
      setParamState(newParam.toString());
    }

    if (search !== urlParams.toString()) {
      history.push({ ...location, search: `?${urlParams.toString()}` });
    }
  };

  return [param, setParam];
};

export const useEndDateParam = () => {
  const key = 'endDate';
  const [param, setParamState] = useState(null);

  const { search } = history.location;
  const urlParams = new URLSearchParams(search);

  const setParam = newParam => {
    if (newParam === null || newParam === undefined) {
      urlParams.delete(key);
      setParamState(null);
    } else {
      urlParams.set(key, newParam.toString());
      setParamState(newParam.toString());
    }

    if (search !== urlParams.toString()) {
      history.push({ ...location, search: `?${urlParams.toString()}` });
    }
  };

  return [param, setParam];
};

export const useReportIdParam = () => {
  const key = 'reportId';
  const [param, setParamState] = useState(null);

  const { search } = history.location;
  const urlParams = new URLSearchParams(search);

  const setParam = newParam => {
    if (newParam === null || newParam === undefined) {
      urlParams.delete(key);
      setParamState(null);
    } else {
      urlParams.set(key, newParam.toString());
      setParamState(newParam.toString());
    }

    if (search !== urlParams.toString()) {
      history.push({ ...location, search: `?${urlParams.toString()}` });
    }
  };

  return [param, setParam];
};
