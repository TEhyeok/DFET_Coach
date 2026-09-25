'use strict';

// Helper for test/unit/exports.test.js (DF-037). Not a *.test.js file, so the runner does not execute it.
//
// Describes each Cloud Function export by its deploy-visible contract:
// kind (callable | https | event | schedule), region, platform, memory and timeout.
// firebase-functions ^7 attaches `__endpoint` to v1 and v2 functions alike.

const DEFAULT_REGION = 'us-central1';

function kindOf(endpoint) {
  if (endpoint.callableTrigger) return 'callable';
  if (endpoint.httpsTrigger) return 'https';
  if (endpoint.eventTrigger) return 'event';
  if (endpoint.scheduleTrigger) return 'schedule';
  return 'unknown';
}

// Unset options are `null` or a firebase-functions ResetValue sentinel; both are recorded as null.
function scalarOrNull(value) {
  return typeof value === 'number' || typeof value === 'string' ? value : null;
}

function describeExport(fn) {
  const endpoint = fn && fn.__endpoint;
  if (!endpoint) return null;
  const region = Array.isArray(endpoint.region) && endpoint.region.length > 0
    ? endpoint.region.join(',')
    : DEFAULT_REGION;
  return {
    kind: kindOf(endpoint),
    region,
    platform: scalarOrNull(endpoint.platform),
    availableMemoryMb: scalarOrNull(endpoint.availableMemoryMb),
    timeoutSeconds: scalarOrNull(endpoint.timeoutSeconds),
  };
}

function describeExports(moduleExports) {
  const described = {};
  for (const name of Object.keys(moduleExports).sort()) {
    described[name] = describeExport(moduleExports[name]);
  }
  return described;
}

module.exports = {DEFAULT_REGION, describeExport, describeExports};
