/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */
import React from 'react';
import PropTypes from 'prop-types';
import { HomeButton, NavBar as BaseNavBar } from '@tupaia/ui-components';
import { ProfileButton } from '../authentication';

const isTabActive = (match, location) => {
  if (!match) {
    return false;
  }
  return location.pathname.indexOf(match.url) !== -1;
};

export const Navbar = ({ links }) => (
  <BaseNavBar
    HomeButton={<HomeButton source="/admin-panel-logo-white.svg" />}
    links={links}
    Profile={ProfileButton}
    isTabActive={isTabActive}
  />
);

Navbar.propTypes = {
  links: PropTypes.arrayOf(PropTypes.shape({})).isRequired,
};
