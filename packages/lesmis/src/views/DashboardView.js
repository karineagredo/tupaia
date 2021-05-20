/*
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 *
 */
import React, { useState } from 'react';
import PropTypes from 'prop-types';
import styled from 'styled-components';
import MuiBox from '@material-ui/core/Box';
import MuiContainer from '@material-ui/core/Container';
import MuiDivider from '@material-ui/core/Divider';
import Typography from '@material-ui/core/Typography';
import { Select } from '@tupaia/ui-components';
import { DashboardReportTabView } from './DashboardReportTabView';
import {
  MiniMap,
  TabPanel,
  TabBar,
  TabBarSection,
  EntityVitalsItem,
  PartnerLogo,
  FlexStart,
} from '../components';
import { useUrlParams, useUrlSearchParams } from '../utils';
import { useProvinceInformation, useEntityData, useEntitiesData } from '../api/queries';

const StyledSelect = styled(Select)`
  margin: 0 1rem 0 0;
  width: 14rem;
  text-transform: capitalize;
`;

const TabTemplate = ({ TabSelector, Body }) => (
  <>
    <TabBar>
      <TabBarSection>{TabSelector}</TabBarSection>
    </TabBar>
    <MuiBox p={5} minHeight={500}>
      {Body}
    </MuiBox>
  </>
);

TabTemplate.propTypes = {
  TabSelector: PropTypes.node.isRequired,
  Body: PropTypes.node.isRequired,
};

const getProfileLabel = entityType => {
  if (!entityType) {
    return 'Profile';
  }
  switch (entityType) {
    case 'district':
      return 'Province Profile';
    case 'sub_district':
      return 'District Profile';
    default:
      return `${entityType} Profile`;
  }
};

const makeTabOptions = entityType => [
  {
    value: 'profile',
    label: getProfileLabel(entityType),
    Component: DashboardReportTabView,
  },
  {
    value: 'indicators',
    label: 'Free Indicator Selection',
    Component: TabTemplate,
    Body: 'Free Indicator Selection',
  },
  {
    value: 'essdpPlan',
    label: 'ESSDP Plan 2021-25 M&E Framework',
    Component: TabTemplate,
    Body: '9th Education Sector and Sports Development Plan 2021-25 M&E Framework',
  },
  {
    value: 'earlyChildhood',
    label: 'ESSDP Early childhood education sub-sector',
    Component: TabTemplate,
    Body: 'ESSDP Early childhood education sub-sector',
  },
  {
    value: 'primary',
    label: 'ESSDP Primary sub-sector',
    Component: TabTemplate,
    Body: 'ESSDP Primary sub-sector',
  },
  {
    value: 'secondary',
    label: 'ESSDP Lower secondary sub-sector',
    Component: TabTemplate,
    Body: 'ESSDP Lower secondary sub-sector',
  },
  {
    value: 'emergency',
    label: 'Emergency in Education/COVID-19',
    Component: TabTemplate,
    Body: 'Emergency in Education/COVID-19',
  },
  {
    value: 'international',
    label: 'International reporting on SDGs',
    Component: TabTemplate,
    Body: 'International reporting on SDGs',
  },
];

const Wrapper = styled.section`
  background: #fbfbfb;
`;

const Container = styled(MuiContainer)`
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-items: stretch;
  padding-right: 0;
`;

const FlexRow = styled(FlexStart)`
  flex-wrap: wrap;
  height: 100%;
`;

const VitalsSection = styled(FlexRow)`
  margin-right: 10px;
  padding-bottom: 1rem;
  flex: 1;
  min-width: 500px;
`;

const PartnersContainer = styled(FlexRow)`
  width: 320px;
  padding-left: 25px;
`;

const ParentDistrict = styled(FlexRow)`
  width: 60%;
`;

const ParentVillage = styled(FlexRow)`
  padding-left: 30px;
  width: 30%;
`;

const TitleContainer = styled.div`
  width: 100%;
`;

const RedTitle = styled(Typography)`
  font-weight: 500;
  text-transform: capitalize;
  color: ${props => props.theme.palette.primary.main};
  padding-top: 30px;
`;

const GreyTitle = styled(Typography)`
  color: ${props => props.theme.palette.text.secondary};
  font-weight: 500;
  padding-top: 30px;
  padding-bottom: 10px;
  padding-left: 5px;
`;

const HorizontalDivider = styled(MuiDivider)`
  width: 90%;
  margin-top: 1rem;
`;

const VerticalDivider = styled(MuiDivider)`
  margin-top: 2.5rem;
  height: 7rem;
`;

const PhotoOrMap = ({ entityData }) => {
  const { Photo, bounds, region, type, point } = entityData;
  const [validImage, setValidImage] = useState(true);

  if (Photo && validImage) {
    return <img src={Photo} alt="place" width="720px" onError={() => setValidImage(false)} />;
  }

  return <MiniMap bounds={bounds} region={region} type={type} point={point} />;
};
//
// const CountryView = ({ vitals }) => {
//   return (
//     <>
//       <VitalsSection>
//         <TitleContainer>
//           <RedTitle variant="h4">Country Profile:</RedTitle>
//         </TitleContainer>
//         <EntityVitalsItem
//           name="No. Schools"
//           value="13849" // TODO: Remove hardcoded values https://github.com/beyondessential/tupaia-backlog/issues/2765
//           icon="School"
//           isLoading={vitals.isLoading}
//         />
//         <EntityVitalsItem
//           name="No. Students"
//           value="1659117" // TODO: Remove hardcoded values https://github.com/beyondessential/tupaia-backlog/issues/2765
//           icon="Study"
//           isLoading={vitals.isLoading}
//         />
//       </VitalsSection>
//       <PhotoOrMap vitals={vitals} />
//       <PartnersContainer>
//         <TitleContainer>
//           <GreyTitle>Development Partner Support</GreyTitle>
//         </TitleContainer>
//         {Object.entries(vitals).map(([key, value]) =>
//           value === true ? <PartnerLogo code={key} key={key} /> : null,
//         )}
//       </PartnersContainer>
//     </>
//   );
// };

// eslint-disable-next-line no-unused-vars,react/prop-types
const ProvinceView = ({ entityCode, descendants }) => {
  const vitals = useProvinceInformation(entityCode, descendants);
  return (
    <>
      <EntityVitalsItem
        name="Province Code"
        value={vitals.code}
        icon="LocationPin"
        isLoading={vitals.isLoading}
      />
      <EntityVitalsItem
        name="Province Population"
        value={vitals.Population}
        icon="Group"
        isLoading={vitals.isLoading}
      />
      <EntityVitalsItem
        name="No. Schools"
        value={vitals.NumberOfSchools}
        icon="School"
        isLoading={vitals.isLoading}
      />
      <EntityVitalsItem
        name="No. Students"
        value={vitals.NumberOfStudents}
        icon="Study"
        isLoading={vitals.isLoading}
      />
    </>
  );
};
//
// const DistrictView = ({ entityCode }) => {
//   return (
//     <>
//       <EntityVitalsItem
//         name="District Code"
//         value={vitals.code}
//         icon="LocationPin"
//         isLoading={vitals.isLoading}
//       />
//       <EntityVitalsItem
//         name="District Population"
//         value={vitals.Population}
//         icon="Group"
//         isLoading={vitals.isLoading}
//       />
//       <EntityVitalsItem
//         name="Priority District"
//         value={vitals.priorityDistrict ? 'Yes' : 'No'}
//         icon="Notepad"
//         isLoading={vitals.isLoading}
//       />
//       <EntityVitalsItem
//         name="No. Schools"
//         value={vitals.NumberOfSchools}
//         icon="School"
//         isLoading={vitals.isLoading}
//       />
//       <EntityVitalsItem
//         name="No. Students"
//         value={vitals.NumberOfStudents}
//         icon="Study"
//         isLoading={vitals.isLoading}
//       />
//       <HorizontalDivider />
//       <FlexRow>
//         <TitleContainer>
//           <RedTitle variant="h4">Province</RedTitle>
//         </TitleContainer>
//         <EntityVitalsItem
//           name="Name of Province"
//           value={vitals.parentProvince?.name}
//           isLoading={vitals.isLoading}
//         />
//         <EntityVitalsItem
//           name="Province Code"
//           value={vitals.parentProvince?.code}
//           isLoading={vitals.isLoading}
//         />
//         <EntityVitalsItem
//           name="Province Population"
//           value={vitals.parentProvince?.Population}
//           isLoading={vitals.isLoading}
//         />
//       </FlexRow>
//     </>
//   );
// };
// //
// // const VillageView = ({ vitals }) => {
// //   return (
// //     <>
// //       <VitalsSection>
// //         <TitleContainer>
// //           <RedTitle variant="h4">Village Profile:</RedTitle>
// //         </TitleContainer>
// //         <EntityVitalsItem
// //           name="Village Code"
// //           value={vitals.code}
// //           icon="LocationPin"
// //           isLoading={vitals.isLoading}
// //         />
// //         <EntityVitalsItem
// //           name="Village Population"
// //           value={vitals.Population}
// //           icon="Group"
// //           isLoading={vitals.isLoading}
// //         />
// //         <EntityVitalsItem
// //           name="No. Schools"
// //           value={vitals.NumberOfSchools}
// //           icon="School"
// //           isLoading={vitals.isLoading}
// //         />
// //         <EntityVitalsItem
// //           name="No. Students"
// //           value={vitals.NumberOfStudents}
// //           icon="Study"
// //           isLoading={vitals.isLoading}
// //         />
// //       </VitalsSection>
// //       <PhotoOrMap vitals={vitals} />
// //       <PartnersContainer>
// //         <TitleContainer>
// //           <GreyTitle>Development Partner Support</GreyTitle>
// //         </TitleContainer>
// //         {Object.entries(vitals).map(([key, value]) =>
// //           value === true ? <PartnerLogo code={key} key={key} /> : null,
// //         )}
// //       </PartnersContainer>
// //     </>
// //   );
// // };
// // //
// // // const SchoolView = ({ vitals }) => {
// // //   return (
// // //     <>
// // //       <VitalsSection>
// // //         <TitleContainer>
// // //           <RedTitle variant="h4">School Profile:</RedTitle>
// // //         </TitleContainer>
// // //         <EntityVitalsItem
// // //           name="School Code"
// // //           value={vitals.code}
// // //           icon="LocationPin"
// // //           isLoading={vitals.isLoading}
// // //         />
// // //         <EntityVitalsItem
// // //           name="Number of Students"
// // //           value={vitals.NumberOfStudents}
// // //           icon="Study"
// // //           isLoading={vitals.isLoading}
// // //         />
// // //         <EntityVitalsItem name="Complete School" icon="Notepad" isLoading={vitals.isLoading} />
// // //         <EntityVitalsItem
// // //           name="Distance to Main Road"
// // //           value={`${vitals.DistanceToMainRoad || '-'} km`}
// // //           icon="Road"
// // //           isLoading={vitals.isLoading}
// // //         />
// // //         <EntityVitalsItem
// // //           name="Location"
// // //           value={vitals.point?.map(x => x.toFixed(3)).join()}
// // //           icon="PushPin"
// // //           isLoading={vitals.isLoading}
// // //         />
// // //         <EntityVitalsItem
// // //           name="School Type"
// // //           value={vitals.attributes?.type}
// // //           icon="School"
// // //           isLoading={vitals.isLoading}
// // //         />
// // //         <HorizontalDivider />
// // //         <FlexRow>
// // //           <ParentDistrict>
// // //             <TitleContainer>
// // //               <RedTitle variant="h4">District</RedTitle>
// // //             </TitleContainer>
// // //             <EntityVitalsItem
// // //               name="Name of District"
// // //               value={vitals.parentDistrict?.name}
// // //               isLoading={vitals.isLoading}
// // //             />
// // //             <EntityVitalsItem
// // //               name="District Population"
// // //               value={vitals.parentDistrict?.Population}
// // //               isLoading={vitals.isLoading}
// // //             />
// // //             <EntityVitalsItem
// // //               name="Priority District"
// // //               value={vitals.parentDistrict?.priorityDistrict ? 'Yes' : 'No'}
// // //               isLoading={vitals.isLoading}
// // //             />
// // //           </ParentDistrict>
// // //           <VerticalDivider orientation="vertical" />
// // //           <ParentVillage>
// // //             <TitleContainer>
// // //               <RedTitle variant="h4">Village</RedTitle>
// // //             </TitleContainer>
// // //             <EntityVitalsItem
// // //               name="Village Population"
// // //               value={vitals.parentVillage?.Population}
// // //               isLoading={vitals.isLoading}
// // //             />
// // //           </ParentVillage>
// // //         </FlexRow>
// // //       </VitalsSection>
// // //       <PhotoOrMap vitals={vitals} />
// // //     </>
// // //   );
// // // };

const Column1 = styled.div`
  flex: 1;
`;

const Column2 = styled.div`
  display: flex;
  width: 370px;
`;

const Column3 = styled.div`
  width: 370px;
`;

const VITALS_VIEWS = {
  // country: CountryView,
  district: ProvinceView,
  // sub_district: DistrictView,
  // village: VillageView,
  // school: SchoolView,
};

// eslint-disable-next-line react/prop-types
const VitalsView = ({ entityType, entityCode, descendants }) => {
  console.log('descendants', descendants);
  const Component = VITALS_VIEWS[entityType];
  return <Component entityCode={entityCode} descendants={descendants} />;
};

export const DashboardView = () => {
  const { entityCode } = useUrlParams();
  const { data: entityData, entityDataIsLoading } = useEntityData(entityCode);
  // get descendants for vitals
  const { data: descendants = [], isLoading: entitiesDataIsLoading } = useEntitiesData(entityCode, {
    includeRootEntity: false,
    fields: 'code,type',
  });

  const tabOptions = makeTabOptions(entityData?.type);
  const [params, setParams] = useUrlSearchParams();

  const selectedTab = params.dashboardTab || tabOptions[0].value;

  const handleChangeTab = event => {
    setParams({ dashboardTab: event.target.value, dashboard: null, year: null });
  };

  const isLoading = entityDataIsLoading || entitiesDataIsLoading;
  console.log('isloading...', isLoading);

  return (
    <>
      <Container maxWidth={false}>
        <Column1>
          <RedTitle variant="h4">{entityData && entityData.type} Profile:</RedTitle>
          {isLoading ? (
            'Loading...'
          ) : (
            <VitalsView
              entityType={entityData.type}
              entityCode={entityData.code}
              descendants={descendants}
            />
          )}
        </Column1>
        <Column2>{entityData ? <PhotoOrMap entityData={entityData} /> : 'Loading...'}</Column2>
        <Column3>
          <GreyTitle>Development Partner Support</GreyTitle>
          <FlexStart>
            {/*{Object.entries(vitals).map(([key, value]) =>*/}
            {/*  value === true ? <PartnerLogo code={key} key={key} /> : null,*/}
            {/*)}*/}
          </FlexStart>
        </Column3>
      </Container>
      {tabOptions.map(({ value, Body, Component }) => (
        <TabPanel key={value} isSelected={value === selectedTab} Panel={React.Fragment}>
          <Component
            entityCode={entityCode}
            Body={Body}
            TabSelector={
              <StyledSelect
                id="dashboardtab"
                options={tabOptions}
                value={selectedTab}
                onChange={handleChangeTab}
                showPlaceholder={false}
                SelectProps={{
                  MenuProps: { disablePortal: true },
                }}
              />
            }
          />
        </TabPanel>
      ))}
    </>
  );
};
