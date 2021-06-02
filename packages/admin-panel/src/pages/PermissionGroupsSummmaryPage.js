/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 *
 */
import React, { useState, useEffect } from 'react';
import styled from 'styled-components';
import { api } from '../api';

const Container = styled.section`
  padding-top: 1rem;
  padding-bottom: 1rem;
  max-width: 1200px;
  overflow: auto;
  margin: 0 auto;
  min-height: 80vh;
`;

const Inner = styled.div`
  display: flex;
  align-self: flex-end;
`;

const Column = styled.div`
  display: flex;
  flex-direction: column-reverse;
  padding: 1rem;
`;

const Node = styled.div`
  display: flex;
  flex-direction: column;
  padding: 1rem;
  align-self: center;
  justify-content: center;
  width: 140px;
  height: 140px;
  background: #efefef;
  border: 1px solid #999;
  border-radius: 50%;
  margin: 1rem 0;
`;

const Text = styled.span`
  font-size: 12px;
  line-height: 18px;
  font-weight: 500;
  text-align: center;
`;

const getParent = (permissionGroups, currentPermissionGroup, permissionTree) => {
  const parent = permissionGroups.find(pg => currentPermissionGroup.parent_id === pg.id);

  if (!parent) {
    return permissionTree;
  }

  return getParent(permissionGroups, parent, [...permissionTree, parent]);
};

const getPermissionGroups = async () => {
  const { body: permissionGroups } = await api.get('permissionGroups');
  const basePermissionGroups = permissionGroups.filter(pg => {
    // find the permission groups that have no children
    // none of the permission groups have a parent_id that equals its id
    return !permissionGroups.some(item => item.parent_id === pg.id);
  });

  return basePermissionGroups.map(currentPermissionGroup => {
    return getParent(permissionGroups, currentPermissionGroup, [currentPermissionGroup]);
  });
};

export const PermissionGroupsSummaryPage = () => {
  const [data, setData] = useState([]);

  useEffect(() => {
    async function fetchData() {
      const groups = await getPermissionGroups();
      setData(groups);
    }
    fetchData();
  }, []);

  console.log('data', data);

  return (
    <Container>
      <h1>Permission Groups</h1>
      <Inner>
        {data.map((columns, index) => {
          return (
            // eslint-disable-next-line react/no-array-index-key
            <Column key={index}>
              {columns.map(node => {
                return (
                  <Node key={node.id}>
                    <Text>{node.name}</Text>
                  </Node>
                );
              })}
            </Column>
          );
        })}
      </Inner>
    </Container>
  );
};
