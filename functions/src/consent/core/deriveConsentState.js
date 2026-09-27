'use strict';

// DF-109: pure append-only record reduction (V1-05 §4.12). The MVP callable only accepts grants;
// historical withdrawals still win a timestamp tie so a reducer cannot resurrect withdrawn consent.
const TYPES = Object.freeze(['required', 'healthData', 'bodyImaging', 'sharing', 'research']);

function compareTime(a, b) {
  if (!a) return b ? -1 : 0;
  if (!b) return 1;
  return a.seconds === b.seconds ? Math.sign(a.nanoseconds - b.nanoseconds) : Math.sign(a.seconds - b.seconds);
}

function derive(prevState, newRecords) {
  const next = {...prevState, schemaVersion: 1};
  for (const record of newRecords) {
    const {id, consentType, action, recordedAt, documentVersion} = record;
    if (!TYPES.includes(consentType) || !['grant', 'withdraw'].includes(action)) {
      throw new TypeError('derive: invalid consent type or action');
    }
    const previous = next[consentType];
    const granted = action === 'grant';
    const order = compareTime(recordedAt, previous?.updatedAt);
    const winsTie = order === 0 && (
      (previous.granted && !granted) ||
      (previous.granted === granted && id > previous.recordId)
    );
    if (!previous || order > 0 || winsTie) {
      next[consentType] = {granted, documentVersion, updatedAt: recordedAt, recordId: id};
    }
    if (compareTime(recordedAt, next.updatedAt) > 0) next.updatedAt = recordedAt;
  }
  return next;
}

module.exports = {derive};
