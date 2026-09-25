'use strict';

// Standard error and success shapes for NEW Cloud Functions (DF-037, PRD §10.6, V1-06 §3.5-3.6).
//
// fail(code, message, details) throws HttpsError(code, message, {messageKey, retryable, fields, violations}).
// - `code` must be one of STANDARD_CODES. Anything else is a programming error and throws TypeError,
//   so it fails in unit tests instead of reaching a client.
// - `message` is an English message key (e.g. 'member.notAssigned'). The server sends no Korean
//   sentences; clients map the key to their own string catalog (V1-06 §3.5).
// - `details` accepts only `fields` and `violations` (arrays of strings or plain objects). Never put
//   health values, names, emails, uids, paths or free text in details (NFR-10).
//
// `unauthenticated` is outside the six domain codes: only src/shared/auth.js raises it, through
// authRequired(). Legacy exports keep their own `{success, message}` responses and errors.

const {HttpsError} = require('firebase-functions/v2/https');

const STANDARD_CODES = Object.freeze([
  'invalid-argument',
  'permission-denied',
  'failed-precondition',
  'not-found',
  'already-exists',
  'resource-exhausted',
]);

const RETRYABLE_CODES = new Set(['resource-exhausted']);
const DETAIL_KEYS = new Set(['fields', 'violations']);
const MESSAGE_KEY_PATTERN = /^[a-z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)+$/;

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype;
}

function assertMessageKey(fnName, message) {
  if (typeof message !== 'string' || !MESSAGE_KEY_PATTERN.test(message)) {
    throw new TypeError(`${fnName}: message must be a dotted English message key such as 'member.notAssigned'`);
  }
}

function buildDetails(message, code, details) {
  if (details === undefined) details = {};
  if (!isPlainObject(details)) {
    throw new TypeError('fail: details must be a plain object');
  }
  for (const [key, value] of Object.entries(details)) {
    if (!DETAIL_KEYS.has(key)) {
      throw new TypeError(`fail: details.${key} is not allowed; use fields or violations`);
    }
    if (!Array.isArray(value)) {
      throw new TypeError(`fail: details.${key} must be an array`);
    }
  }
  return {
    messageKey: message,
    retryable: RETRYABLE_CODES.has(code),
    fields: details.fields ?? [],
    violations: details.violations ?? [],
  };
}

function fail(code, message, details) {
  if (!STANDARD_CODES.includes(code)) {
    throw new TypeError(
      `fail: '${code}' is not a standard error code (${STANDARD_CODES.join(', ')})`
    );
  }
  assertMessageKey('fail', message);
  throw new HttpsError(code, message, buildDetails(message, code, details));
}

function authRequired() {
  return new HttpsError('unauthenticated', 'auth.required', {
    messageKey: 'auth.required',
    retryable: false,
    fields: [],
    violations: [],
  });
}

function ok(payload = {}) {
  if (!isPlainObject(payload)) {
    throw new TypeError('ok: payload must be a plain object');
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'ok')) {
    throw new TypeError('ok: payload must not set ok itself');
  }
  return {ok: true, ...payload};
}

module.exports = {STANDARD_CODES, authRequired, fail, ok};
