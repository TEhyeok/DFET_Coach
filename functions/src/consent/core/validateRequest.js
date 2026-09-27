'use strict';

const {fail} = require('../../shared/errors');

const MVP_TYPES = Object.freeze(['required', 'healthData', 'bodyImaging']);
const ISO_INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/;

function object(value) {
  return value !== null && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype;
}

function onlyKeys(value, keys) {
  return object(value) && Object.keys(value).every(key => keys.includes(key));
}

function documentId(value) {
  return typeof value === 'string' && value.length > 0 && value.length <= 128 &&
    !value.includes('/') && value !== '.' && value !== '..';
}

function invalid(field) {
  fail('invalid-argument', 'consent.invalidRequest', {fields: [field]});
}

// DEC-22: pending members, in-person grants of ①②③, no signature storage or deferred call paths.
function validateRequest(data) {
  if (!onlyKeys(data, ['memberKey', 'clientCaptureId', 'channel', 'selections', 'capturedAt',
    'signaturePngBase64', 'reconfirmOf'])) invalid('request');
  if (!onlyKeys(data.memberKey, ['pendingMemberId']) || !documentId(data.memberKey.pendingMemberId)) {
    invalid('memberKey');
  }
  if (typeof data.clientCaptureId !== 'string' || !/^[A-Za-z0-9_-]{8,64}$/.test(data.clientCaptureId)) {
    invalid('clientCaptureId');
  }
  if (data.channel !== 'trainerDeviceInPerson') invalid('channel');
  if (data.signaturePngBase64 != null) invalid('signaturePngBase64');
  if (data.reconfirmOf != null) invalid('reconfirmOf');
  if (!Array.isArray(data.selections) || data.selections.length < 1 || data.selections.length > 3) {
    invalid('selections');
  }
  const seen = new Set();
  const selections = data.selections.map(selection => {
    if (!onlyKeys(selection, ['consentType', 'action', 'documentVersion']) ||
      !MVP_TYPES.includes(selection.consentType) || selection.action !== 'grant' ||
      !documentId(selection.documentVersion)) invalid('selections');
    if (seen.has(selection.consentType)) fail('invalid-argument', 'consent.duplicateType');
    seen.add(selection.consentType);
    return {...selection};
  }).sort((a, b) => MVP_TYPES.indexOf(a.consentType) - MVP_TYPES.indexOf(b.consentType));
  let capturedAt = null;
  if (data.capturedAt != null) {
    if (typeof data.capturedAt !== 'string' || !ISO_INSTANT.test(data.capturedAt)) invalid('capturedAt');
    capturedAt = new Date(data.capturedAt);
    if (!Number.isFinite(capturedAt.getTime())) invalid('capturedAt');
  }
  return {
    memberKey: {...data.memberKey}, clientCaptureId: data.clientCaptureId,
    channel: data.channel, selections, capturedAt,
  };
}

// A previously committed capture can be replayed after this window; only a new capture is rejected.
function validateCaptureTime(capturedAt, now) {
  if (capturedAt !== null && (capturedAt.getTime() < now.getTime() - 7 * 86400000 ||
    capturedAt.getTime() > now.getTime() + 300000)) {
    fail('invalid-argument', 'consent.captureTimeInvalid', {fields: ['capturedAt']});
  }
}

module.exports = {MVP_TYPES, validateRequest, validateCaptureTime};
