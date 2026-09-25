'use strict';

// Region wrappers for every NEW Cloud Function (DF-037, NFR-16, ADR-017).
//
// - callableV2 / scheduled register in REGION (asia-northeast3).
// - firestoreTrigger registers in FIRESTORE_TRIGGER_REGION: an Eventarc Firestore trigger must run in
//   the database's location. The value stays a separate constant until G-09 (DF-909) confirms the
//   production database location (ASM-P0-10, ASM-04-15).
// - Callers cannot pass `region`; a wrapper that silently accepted another region would defeat NFR-16.
//
// Legacy exports in index.js keep their current regions and do not use these wrappers
// (test/unit/exports.test.js pins them).

const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {callable} = require('./callable');

const REGION = 'asia-northeast3';
const FIRESTORE_TRIGGER_REGION = 'asia-northeast3';
const SCHEDULE_TIME_ZONE = 'Asia/Seoul';

function withoutRegion(wrapper, opts) {
  if (opts === null || typeof opts !== 'object' || Array.isArray(opts)) {
    throw new TypeError(`${wrapper}: opts must be a plain object`);
  }
  if (Object.prototype.hasOwnProperty.call(opts, 'region')) {
    throw new TypeError(`${wrapper}: region is fixed by src/shared/region.js; remove opts.region`);
  }
  return opts;
}

function requireFunction(wrapper, handler) {
  if (typeof handler !== 'function') {
    throw new TypeError(`${wrapper}: handler must be a function`);
  }
}

// New onCall function in REGION. The handler keeps the (data, context) contract of
// src/shared/callable.js: handler(request.data, {auth: request.auth}).
function callableV2(handler, opts = {}) {
  requireFunction('callableV2', handler);
  return callable(handler, {...withoutRegion('callableV2', opts), region: REGION});
}

// New onDocumentWritten trigger in FIRESTORE_TRIGGER_REGION.
function firestoreTrigger(document, handler, opts = {}) {
  if (typeof document !== 'string' || document.length === 0) {
    throw new TypeError('firestoreTrigger: document path pattern is required');
  }
  requireFunction('firestoreTrigger', handler);
  return onDocumentWritten(
    {...withoutRegion('firestoreTrigger', opts), document, region: FIRESTORE_TRIGGER_REGION},
    handler
  );
}

// New onSchedule function in REGION, Asia/Seoul time zone unless the caller sets one.
function scheduled(schedule, handler, opts = {}) {
  if (typeof schedule !== 'string' || schedule.length === 0) {
    throw new TypeError('scheduled: schedule expression is required');
  }
  requireFunction('scheduled', handler);
  return onSchedule(
    {timeZone: SCHEDULE_TIME_ZONE, ...withoutRegion('scheduled', opts), schedule, region: REGION},
    handler
  );
}

module.exports = {
  FIRESTORE_TRIGGER_REGION,
  REGION,
  SCHEDULE_TIME_ZONE,
  callableV2,
  firestoreTrigger,
  scheduled,
};
