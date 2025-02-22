/**
 * Tupaia
 * Copyright (c) 2017 - 2020 Beyond Essential Systems Pty Ltd
 */
import { assertCanAddDataElementInGroup } from '../database';

const RESOURCE_TYPES = {
  DATA_GROUP: 'dataGroup',
  DATA_ELEMENT: 'dataElement',
  SURVEY: 'survey',
};

class SurveyEditor {
  constructor(models) {
    this.models = models;
  }

  async edit(recordId, updatedFields) {
    this.survey = await this.models.survey.findById(recordId);
    this.dataGroup = await this.survey.dataGroup();
    this.updatedFieldsByResource = this.createUpdatedFieldsByResource(updatedFields);

    await this.updateDataElements();
    await this.updateDataGroup();
    await this.updateSurvey();
  }

  createUpdatedFieldsByResource = updatedFields => {
    const {
      'data_source.service_type': serviceType,
      'data_source.config': config,
      ...updatedSurveyFields
    } = updatedFields;

    return {
      [RESOURCE_TYPES.DATA_GROUP]: {
        code: updatedSurveyFields.code,
        service_type: serviceType,
        config,
      },
      [RESOURCE_TYPES.DATA_ELEMENT]: { service_type: serviceType, config },
      [RESOURCE_TYPES.SURVEY]: updatedSurveyFields,
    };
  };

  isResourceUpdated = resourceType =>
    Object.values(this.updatedFieldsByResource[resourceType]).some(field => field !== undefined);

  updateDataElements = async () => {
    // Check for performance reasons
    if (!this.isResourceUpdated(RESOURCE_TYPES.DATA_ELEMENT)) {
      return;
    }

    const dataElements = await this.models.dataSource.getDataElementsInGroup(this.dataGroup.code);
    const updateDataElement = async dataElement => {
      await assertCanAddDataElementInGroup(
        this.models,
        dataElement.code,
        this.dataGroup.code,
        this.updatedFieldsByResource.dataElement,
      );
      await this.updateResource(dataElement, RESOURCE_TYPES.DATA_ELEMENT);
    };

    await Promise.all(dataElements.map(updateDataElement));
  };

  updateDataGroup = async () => {
    await this.dataGroup.deleteSurveyDateElement();
    await this.updateResource(this.dataGroup, RESOURCE_TYPES.DATA_GROUP);
    await this.dataGroup.upsertSurveyDateElement();
  };

  updateSurvey = async () => this.updateResource(this.survey, RESOURCE_TYPES.SURVEY);

  /**
   * @param {DatabaseModel} model - mutated
   */
  updateResource = async (model, resourceType) => {
    const updatedFields = this.updatedFieldsByResource[resourceType];
    const isDataSource = model.databaseType === this.models.dataSource.databaseType;

    Object.entries(updatedFields).forEach(([fieldName, fieldValue]) => {
      if (isDataSource && (fieldName === 'config' || fieldValue === undefined)) {
        // Handle config last since its value depends on other fields
        // For the same reason, do not set model fields to `undefined`
        // so that the actual record values can be used for config calculation
        return;
      }
      // eslint-disable-next-line no-param-reassign
      model[fieldName] = fieldValue;
    });
    if (isDataSource) {
      this.updateDataSourceConfig(model, updatedFields);
    }

    return model.save();
  };

  /**
   * @param {DatabaseModel} model - mutated
   */
  updateDataSourceConfig = (model, updatedFields) => {
    if ('config' in updatedFields) {
      // Retain existing fields in data source config
      // eslint-disable-next-line no-param-reassign
      model.config = { ...model.config, ...updatedFields.config };
    }
    model.sanitizeConfig();
  };
}

export const editSurvey = async (models, id, updatedFields) => {
  return models.wrapInTransaction(async transactingModels => {
    const surveyEditor = new SurveyEditor(transactingModels);
    return surveyEditor.edit(id, updatedFields);
  });
};
