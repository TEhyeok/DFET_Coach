'use strict';

// Caller checks for NEW Cloud Functions (DF-037, V1-06 §3.3, ADR-018).
// `context` is either the legacy adapter context `{auth}` or a v2 CallableRequest; both carry `auth`.
// Each check returns the caller uid on success.
//
// Legacy exports keep their own verifyAdmin in index.js (Korean messages, unchanged by DF-037).

const {authRequired, fail} = require('./errors');

function requireAuth(context) {
  const auth = context && context.auth;
  if (!auth || typeof auth.uid !== 'string' || auth.uid.length === 0) {
    throw authRequired();
  }
  return auth.uid;
}

function tokenOf(context) {
  return (context.auth && context.auth.token) || {};
}

function requireTrainer(context) {
  const uid = requireAuth(context);
  if (tokenOf(context).trainer !== true) {
    fail('permission-denied', 'auth.notTrainer');
  }
  return uid;
}

// Same claim as the legacy verifyAdmin (index.js): custom claim admin === true (ADR-018).
function requireAdminClaim(context) {
  const uid = requireAuth(context);
  if (tokenOf(context).admin !== true) {
    fail('permission-denied', 'auth.notAdmin');
  }
  return uid;
}

module.exports = {requireAdminClaim, requireAuth, requireTrainer};
