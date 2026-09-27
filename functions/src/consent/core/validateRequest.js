'use strict';

// recordConsent request checks that need no database (DF-109, V1-06 §6.2.1 schema, §6.2.3 V1·V7·V9·V10).
// Pure apart from HttpsError: every failure goes through shared/errors.fail().
//
// validateRequest(data, nowMillis) -> {clientCaptureId, memberKey, channel, selections, capturedAtMillis, hasSignature}
//   memberKey is {memberUid} or {pendingMemberId}; capturedAtMillis is null when the client sent no capturedAt.
//   A non-null reconfirmOf is only valid on the memberApp channel (V9), so the trainer channel never carries one.
// assertMvpScope(request) rejects what the MVP does not record yet (DEC-22, DF-109 '### MVP 범위'):
//   uid members, the memberApp channel, sharing/research, withdraw and signatures -> failed-precondition
//   'consent.unsupportedInMvp' with the offending field in details.fields. Remove the call to lift the gate.
//
// Optional fields (signaturePngBase64, capturedAt, reconfirmOf) accept null as "absent".

const {fail} = require('../../shared/errors');
const {CONSENT_TYPES} = require('./deriveConsentState');

const TOP_LEVEL_KEYS = new Set([
  'clientCaptureId', 'memberKey', 'channel', 'selections', 'signaturePngBase64', 'capturedAt', 'reconfirmOf',
]);
const SELECTION_KEYS = new Set(['consentType', 'action', 'documentVersion']);
const CONSENT_ACTIONS = Object.freeze(['grant', 'withdraw']);
const CONSENT_CHANNELS = Object.freeze(['trainerDeviceInPerson', 'memberApp']);
const MVP_CONSENT_TYPES = Object.freeze(['required', 'healthData', 'bodyImaging']);

const CLIENT_CAPTURE_ID = /^[A-Za-z0-9_-]{8,64}$/;
const DOC_ID = /^[A-Za-z0-9_-]{1,128}$/;
// consentDocumentVersions IDs are `{consentType}--{version}` with a dotted version such as `healthData--1.0`
// (V1-05 §4.13, ASM-05-15), so dots are allowed here, unlike the generic DocId. '.' and '..' are not IDs.
const DOCUMENT_VERSION_ID = /^(?!\.{1,2}$)[A-Za-z0-9_.-]{1,128}$/;
const ISO_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/;
const MAX_SIGNATURE_BASE64 = 1400000;
const MAX_RECONFIRM_OF = 200;
const CAPTURED_AT_PAST_MS = 7 * 24 * 3600 * 1000;   // now − 7 days (AS-32)
const CAPTURED_AT_FUTURE_MS = 5 * 60 * 1000;        // now + 5 minutes (V1-06 §3.11)

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype;
}

function isAbsent(value) {
  return value === undefined || value === null;
}

function invalid(field, messageKey = 'common.invalidArgument') {
  fail('invalid-argument', messageKey, {fields: [field]});
}

function checkMemberKey(memberKey) {
  if (!isPlainObject(memberKey)) invalid('memberKey');
  const keys = Object.keys(memberKey);
  if (keys.length !== 1 || !['memberUid', 'pendingMemberId'].includes(keys[0])) invalid('memberKey');
  const [key] = keys;
  if (typeof memberKey[key] !== 'string' || !DOC_ID.test(memberKey[key])) invalid(`memberKey.${key}`);
  return {[key]: memberKey[key]};
}

function checkSelections(selections) {
  if (!Array.isArray(selections) || selections.length < 1 || selections.length > CONSENT_TYPES.length) {
    invalid('selections');
  }
  const seen = new Set();
  return selections.map((selection, i) => {
    const at = `selections[${i}]`;
    if (!isPlainObject(selection)) invalid(at);
    for (const key of Object.keys(selection)) {
      if (!SELECTION_KEYS.has(key)) invalid(`${at}.${key}`);
    }
    const {consentType, action, documentVersion} = selection;
    if (!CONSENT_TYPES.includes(consentType)) invalid(`${at}.consentType`);
    if (!CONSENT_ACTIONS.includes(action)) invalid(`${at}.action`);
    if (typeof documentVersion !== 'string' || !DOCUMENT_VERSION_ID.test(documentVersion)) {
      invalid(`${at}.documentVersion`);
    }
    if (seen.has(consentType)) invalid(`${at}.consentType`, 'consent.duplicateType');   // V1
    seen.add(consentType);
    return {consentType, action, documentVersion};
  });
}

function checkCapturedAt(capturedAt, nowMillis) {
  if (isAbsent(capturedAt)) return null;
  const parsed = typeof capturedAt === 'string' && ISO_TIME.test(capturedAt) ? Date.parse(capturedAt) : NaN;
  if (!Number.isFinite(parsed)) invalid('capturedAt');
  if (parsed < nowMillis - CAPTURED_AT_PAST_MS || parsed > nowMillis + CAPTURED_AT_FUTURE_MS) {
    invalid('capturedAt', 'consent.capturedAtOutOfRange');                              // V10
  }
  return parsed;
}

function validateRequest(data, nowMillis) {
  if (!isPlainObject(data)) invalid('data');
  for (const key of Object.keys(data)) {
    if (!TOP_LEVEL_KEYS.has(key)) invalid(key);
  }
  const {clientCaptureId, channel, signaturePngBase64, reconfirmOf} = data;
  if (typeof clientCaptureId !== 'string' || !CLIENT_CAPTURE_ID.test(clientCaptureId)) invalid('clientCaptureId');
  const memberKey = checkMemberKey(data.memberKey);
  if (!CONSENT_CHANNELS.includes(channel)) invalid('channel');
  const selections = checkSelections(data.selections);
  if (!isAbsent(signaturePngBase64)
      && (typeof signaturePngBase64 !== 'string' || signaturePngBase64.length > MAX_SIGNATURE_BASE64)) {
    invalid('signaturePngBase64');
  }
  if (!isAbsent(reconfirmOf)) {
    if (typeof reconfirmOf !== 'string' || reconfirmOf.length === 0 || reconfirmOf.length > MAX_RECONFIRM_OF) {
      invalid('reconfirmOf');
    }
    // V9: reconfirmation is a memberApp-channel action of the member.
    if (channel !== 'memberApp') invalid('reconfirmOf', 'consent.reconfirmMismatch');
  }
  const capturedAtMillis = checkCapturedAt(data.capturedAt, nowMillis);
  selections.forEach((selection, i) => {
    // V7: ① is withdrawn by leaving (uid member) or cancelling the registration (pending member), never here.
    if (selection.consentType === 'required' && selection.action === 'withdraw') {
      fail('failed-precondition', 'consent.requiredWithdrawNotSupported', {fields: [`selections[${i}].action`]});
    }
  });
  return {
    clientCaptureId,
    memberKey,
    channel,
    selections,
    capturedAtMillis,
    hasSignature: !isAbsent(signaturePngBase64),
  };
}

function unsupported(field) {
  fail('failed-precondition', 'consent.unsupportedInMvp', {fields: [field]});
}

function assertMvpScope(request) {
  if (request.memberKey.memberUid !== undefined) unsupported('memberKey.memberUid');   // uid member path: DF-025
  if (request.channel !== 'trainerDeviceInPerson') unsupported('channel');              // memberApp: P2
  if (request.hasSignature) unsupported('signaturePngBase64');                          // signature PNG: after MVP
  request.selections.forEach((selection, i) => {
    if (!MVP_CONSENT_TYPES.includes(selection.consentType)) unsupported(`selections[${i}].consentType`);
    if (selection.action !== 'grant') unsupported(`selections[${i}].action`);          // withdraw: DF-112
  });
}

module.exports = {MVP_CONSENT_TYPES, assertMvpScope, validateRequest};
