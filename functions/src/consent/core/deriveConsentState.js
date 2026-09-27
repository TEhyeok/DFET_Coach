'use strict';

// memberConsentStates derivation (DF-109, F-PRIV-02.2, V1-05 §4.12, V1-06 §6.2.4 step 5). Pure: no Firebase imports.
//
// derive(prevState, newRecords) -> nextState
//   prevState   the stored memberConsentStates document data, or null when there is none.
//   newRecords  [{recordId, consentType, action, documentVersion, recordedAt}] written in this call.
//   nextState   {<consentType>: {granted, documentVersion, recordId, updatedAt}} for every type that has an entry.
//
// Per type the entry with the latest time wins (stored entry: updatedAt, new record: recordedAt). On equal times a
// withdraw beats a grant. A type with neither a stored entry nor a new record gets no key (no key = not granted).
// Times are Firestore Timestamps (admin or client SDK); only toMillis() and toDate() are used.

const CONSENT_TYPES = Object.freeze(['required', 'healthData', 'bodyImaging', 'sharing', 'research']);

function millis(time) {
  if (!time || typeof time.toMillis !== 'function') {
    throw new TypeError('deriveConsentState: times must be Timestamps');
  }
  return time.toMillis();
}

// Later time wins; on a tie the entry that is not granted (a withdraw) wins.
function newer(a, b) {
  if (!a) return b;
  const diff = millis(b.updatedAt) - millis(a.updatedAt);
  if (diff !== 0) return diff > 0 ? b : a;
  return b.granted ? a : b;
}

function entryOf(record) {
  return {
    granted: record.action === 'grant',
    documentVersion: record.documentVersion,
    recordId: record.recordId,
    updatedAt: record.recordedAt,
  };
}

function derive(prevState, newRecords) {
  if (!Array.isArray(newRecords)) {
    throw new TypeError('deriveConsentState: newRecords must be an array');
  }
  const next = {};
  for (const type of CONSENT_TYPES) {
    const stored = prevState && prevState[type];
    let winner = stored ? {
      granted: stored.granted === true,
      documentVersion: stored.documentVersion,
      recordId: stored.recordId,
      updatedAt: stored.updatedAt,
    } : null;
    for (const record of newRecords) {
      if (record.consentType === type) winner = newer(winner, entryOf(record));
    }
    if (winner) next[type] = winner;
  }
  return next;
}

// Response shape (V1-06 §3.12 ConsentState): the five type keys only, times as ISO 8601 UTC strings.
function toResponseState(state) {
  const out = {};
  for (const type of CONSENT_TYPES) {
    const entry = state && state[type];
    if (!entry) continue;
    out[type] = {
      granted: entry.granted === true,
      documentVersion: entry.documentVersion,
      recordId: entry.recordId,
      updatedAt: entry.updatedAt.toDate().toISOString(),
    };
  }
  return out;
}

module.exports = {CONSENT_TYPES, derive, toResponseState};
