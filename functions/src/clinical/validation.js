'use strict';

const {
  BLOOD_MARKERS,
  BLOOD_MARKER_ALIASES,
  SCHEMA_VERSION,
} = require('./constants');

class ClinicalValidationError extends Error {
  constructor(message, details = []) {
    super(message);
    this.name = 'ClinicalValidationError';
    this.code = 'invalid_payload';
    this.details = details;
  }
}

class ClinicalConflictError extends Error {
  constructor(message, details = [], code = 'idempotency_conflict') {
    super(message);
    this.name = 'ClinicalConflictError';
    this.code = code;
    this.details = details;
  }
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isFiniteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function requireString(errors, object, key, path = key) {
  if (typeof object[key] !== 'string' || object[key].trim() === '') {
    errors.push(`${path} must be a non-empty string`);
  }
}

function requireNumber(errors, object, key, path = key) {
  if (!isFiniteNumber(object[key])) {
    errors.push(`${path} must be a finite number`);
  }
}

function requireIsoDate(errors, object, key, path = key) {
  requireString(errors, object, key, path);
  if (typeof object[key] === 'string' && Number.isNaN(Date.parse(object[key]))) {
    errors.push(`${path} must be an ISO-8601 date-time`);
  }
}

function validateMemberRef(errors, memberRef) {
  if (typeof memberRef === 'string' && memberRef.trim() !== '') {
    if (memberRef.length > 256) errors.push('memberRef must be at most 256 characters');
    return;
  }
  if (!isObject(memberRef)) {
    errors.push('memberRef must be a uid string or an object');
    return;
  }
  if (!['uid', 'externalId'].includes(memberRef.type)) {
    errors.push('memberRef.type must be uid or externalId');
  }
  requireString(errors, memberRef, 'value', 'memberRef.value');
  if (typeof memberRef.value === 'string' && memberRef.value.length > 256) {
    errors.push('memberRef.value must be at most 256 characters');
  }
}

function validateKit(errors, kit) {
  if (kit === undefined || kit === null) return;
  if (!isObject(kit)) {
    errors.push('kit must be an object');
    return;
  }
  const identifiers = ['udi', 'lot'].filter(
    (key) => typeof kit[key] === 'string' && kit[key].trim() !== '',
  );
  if (identifiers.length === 0) {
    errors.push('kit requires at least one of udi or lot');
  }
  if (kit.expiresAt !== undefined && Number.isNaN(Date.parse(kit.expiresAt))) {
    errors.push('kit.expiresAt must be an ISO-8601 date');
  }
}

function validateCommon(envelope) {
  const errors = [];
  if (!isObject(envelope)) {
    throw new ClinicalValidationError('Payload must be a JSON object');
  }
  if (envelope.schemaVersion !== SCHEMA_VERSION) {
    errors.push(`schemaVersion must be ${SCHEMA_VERSION}`);
  }
  requireString(errors, envelope, 'source');
  requireString(errors, envelope, 'externalReportId');
  requireString(errors, envelope, 'idempotencyKey');
  if (typeof envelope.source === 'string' && envelope.source.length > 80) {
    errors.push('source must be at most 80 characters');
  }
  if (
    typeof envelope.externalReportId === 'string' &&
    envelope.externalReportId.length > 160
  ) {
    errors.push('externalReportId must be at most 160 characters');
  }
  if (
    typeof envelope.idempotencyKey === 'string' &&
    envelope.idempotencyKey.length > 256
  ) {
    errors.push('idempotencyKey must be at most 256 characters');
  }
  if (!Number.isInteger(envelope.revision) || envelope.revision < 1) {
    errors.push('revision must be an integer greater than or equal to 1');
  }
  validateMemberRef(errors, envelope.memberRef);
  requireIsoDate(errors, envelope, 'sampledAt');
  requireIsoDate(errors, envelope, 'reportedAt');
  if (
    typeof envelope.sampledAt === 'string' &&
    typeof envelope.reportedAt === 'string' &&
    !Number.isNaN(Date.parse(envelope.sampledAt)) &&
    !Number.isNaN(Date.parse(envelope.reportedAt)) &&
    Date.parse(envelope.reportedAt) < Date.parse(envelope.sampledAt)
  ) {
    errors.push('reportedAt must not be earlier than sampledAt');
  }
  validateKit(errors, envelope.kit);
  if (!isObject(envelope.payload)) errors.push('payload must be an object');
  return errors;
}

function validateComposition(errors, values, path) {
  if (!Array.isArray(values) || values.length === 0) {
    errors.push(`${path} must contain at least one taxon`);
    return;
  }
  values.forEach((item, index) => {
    if (!isObject(item)) {
      errors.push(`${path}[${index}] must be an object`);
      return;
    }
    requireString(errors, item, 'name', `${path}[${index}].name`);
    requireNumber(errors, item, 'value', `${path}[${index}].value`);
    if (isFiniteNumber(item.value) && item.value < 0) {
      errors.push(`${path}[${index}].value must not be negative`);
    }
  });
}

function validateGutPayload(payload) {
  const errors = [];
  if (!isObject(payload.alpha)) {
    errors.push('payload.alpha must be an object');
  } else {
    ['shannon', 'simpson', 'chao1', 'observedOtus'].forEach((key) =>
      requireNumber(errors, payload.alpha, key, `payload.alpha.${key}`),
    );
  }

  if (!isObject(payload.beta) || !Array.isArray(payload.beta.pcoa)) {
    errors.push('payload.beta.pcoa must be an array');
  } else {
    payload.beta.pcoa.forEach((point, index) => {
      if (!isObject(point)) {
        errors.push(`payload.beta.pcoa[${index}] must be an object`);
        return;
      }
      requireNumber(errors, point, 'pc1', `payload.beta.pcoa[${index}].pc1`);
      requireNumber(errors, point, 'pc2', `payload.beta.pcoa[${index}].pc2`);
    });
  }

  if (!isObject(payload.abundance)) {
    errors.push('payload.abundance must be an object');
  } else {
    validateComposition(errors, payload.abundance.phylum, 'payload.abundance.phylum');
    validateComposition(errors, payload.abundance.genus, 'payload.abundance.genus');
  }

  if (!isObject(payload.unifrac)) {
    errors.push('payload.unifrac must be an object');
  } else {
    requireNumber(errors, payload.unifrac, 'weighted', 'payload.unifrac.weighted');
    requireNumber(errors, payload.unifrac, 'unweighted', 'payload.unifrac.unweighted');
  }

  if (!isObject(payload.metadata)) errors.push('payload.metadata must be an object');
  return errors;
}

function canonicalMarkerCode(rawCode) {
  if (typeof rawCode !== 'string') return null;
  const normalized = rawCode.trim().toUpperCase().replace(/[\s-]+/g, '_');
  if (BLOOD_MARKERS[rawCode.trim().toUpperCase()]) {
    return rawCode.trim().toUpperCase();
  }
  return BLOOD_MARKER_ALIASES[normalized] || null;
}

function validateBloodPayload(payload) {
  const errors = [];
  if (!Array.isArray(payload.biomarkers) || payload.biomarkers.length === 0) {
    return ['payload.biomarkers must contain at least one result'];
  }
  const seen = new Set();
  payload.biomarkers.forEach((item, index) => {
    const path = `payload.biomarkers[${index}]`;
    if (!isObject(item)) {
      errors.push(`${path} must be an object`);
      return;
    }
    const code = canonicalMarkerCode(item.code);
    if (!code) errors.push(`${path}.code is not one of the supported 13 markers`);
    if (code && seen.has(code)) errors.push(`${path}.code is duplicated (${code})`);
    if (code) seen.add(code);
    requireNumber(errors, item, 'value', `${path}.value`);
    requireString(errors, item, 'unit', `${path}.unit`);
  });
  return errors;
}

function validateEnvelope(type, envelope) {
  const errors = validateCommon(envelope);
  if (isObject(envelope.payload)) {
    if (type === 'gut') errors.push(...validateGutPayload(envelope.payload));
    if (type === 'blood') errors.push(...validateBloodPayload(envelope.payload));
  }
  if (errors.length > 0) {
    throw new ClinicalValidationError('Clinical ingestion payload is invalid', errors);
  }
  return envelope;
}

module.exports = {
  ClinicalConflictError,
  ClinicalValidationError,
  canonicalMarkerCode,
  isFiniteNumber,
  isObject,
  validateEnvelope,
};
