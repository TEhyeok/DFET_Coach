'use strict';

// v2 callable adapter moved verbatim from index.js:32-48 (DF-037, ADR-017 decision 1).
// It keeps the legacy (data, context) handler contract while registering on the v2 runtime:
// handler(request.data, {auth: request.auth}). Behaviour must not change; the export snapshot
// in test/unit/exports.test.js pins it.

const {HttpsError, onCall} = require('firebase-functions/v2/https');

function callable(handler, options = undefined) {
  const adapted = (request) => handler(request.data, {auth: request.auth});
  return options ? onCall(options, adapted) : onCall(adapted);
}

// 기존 구현의 (data, context) 계약을 유지하면서 등록 런타임만 v2로 전환한다.
const functions = {
  https: {
    HttpsError,
    onCall: (handler) => callable(handler),
  },
  region: (region) => ({
    https: {
      onCall: (handler) => callable(handler, {region}),
    },
  }),
};

module.exports = {callable, functions};
