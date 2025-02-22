import { composeBuiltData } from '/apiV1/utils';
import { latestDataValueDate } from '/apiV1/dataBuilders/generic/latestData';
import { latestDownloadLink } from '/apiV1/dataBuilders/generic/dataDownload';

export const disasterSurveyResponseDownloads = async (
  { dataBuilderConfig, query, entity, req, viewJson },
  aggregator,
  dhisApi,
) => {
  const { preConfig, postConfig } = dataBuilderConfig;

  const preDownloadLink = await latestDownloadLink({ req, query, dataBuilderConfig: preConfig });
  const preDisasterSurveyData = await latestDataValueDate(
    {
      dataBuilderConfig: preConfig,
      entity,
      viewJson,
    },
    aggregator,
    dhisApi,
  );

  const postQuery = {
    ...query,
    startDate: query.disasterStartDate,
  };
  const postDownloadLink = await latestDownloadLink({
    req,
    query: postQuery,
    dataBuilderConfig: postConfig,
  });
  const postDisasterSurveyData = await latestDataValueDate(
    {
      dataBuilderConfig: postConfig,
      entity,
      viewJson,
    },
    aggregator,
    dhisApi,
  );

  return composeBuiltData(
    preDisasterSurveyData,
    preDownloadLink,
    postDisasterSurveyData,
    postDownloadLink,
  );
};
