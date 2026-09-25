'use strict';

// Audit log writer for NEW Cloud Functions (DF-037, PRD §9.7, V1-05 §4.18/§11.5, V1-06 §3.9).
//
// writeAuditEntry(writer, entry, options) validates the entry and writes one auditLogs document with
// `writer.create(ref, data)` in the caller's transaction or batch and returns the DocumentReference.
// When the writer is a Firestore instance it calls `ref.create(data)` and returns a Promise of the ref.
//
// entry:   {action, actorUid, actorRole, targetCollection, targetId, memberUid, metadata}
// options: {allowedKeys, registry, db, docId}
//   allowedKeys  metadata keys this action may use. Required until DF-033 generates AUDIT_ACTIONS.
//   registry     DF-033 generated AUDIT_ACTIONS ([{action, metadataKeys}]). When given, the action must
//                be registered and its metadataKeys are the whitelist; allowedKeys must then be omitted.
//   db           Firestore used to build the document reference when `writer` is a transaction or batch.
//   docId        deterministic id (triggers use `<action>_<targetId>`); omitted = auto id.
//
// Any metadata key outside the whitelist throws (TypeError) instead of being dropped, so tests fail.
// Metadata values are limited to strings, booleans, safe integers and flat maps of safe integers
// (`counts`): no health values, names, emails, free text or paths (PRD §9.7, NFR-10).
// `at` is serverTimestamp(); `createdAt` carries the same value for readers of the legacy shape (§9.2).

const {FieldValue} = require('firebase-admin/firestore');

const AUDIT_COLLECTION = 'auditLogs';
const AUDIT_SCHEMA_VERSION = 1;
const ACTOR_ROLES = Object.freeze(['member', 'trainer', 'admin', 'system']);
const MAX_METADATA_STRING_LENGTH = 64;

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype;
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.length > 0;
}

function resolveAllowedKeys(action, options) {
  const {allowedKeys, registry} = options;
  if (registry !== undefined) {
    if (allowedKeys !== undefined) {
      throw new TypeError('writeAuditEntry: pass either registry (AUDIT_ACTIONS) or allowedKeys, not both');
    }
    if (!Array.isArray(registry)) {
      throw new TypeError('writeAuditEntry: registry must be the AUDIT_ACTIONS array');
    }
    const registered = registry.find((item) => item && item.action === action);
    if (!registered) {
      throw new TypeError(`writeAuditEntry: action '${action}' is not registered in AUDIT_ACTIONS`);
    }
    return new Set(registered.metadataKeys || []);
  }
  if (!Array.isArray(allowedKeys) || !allowedKeys.every(isNonEmptyString)) {
    throw new TypeError('writeAuditEntry: allowedKeys (string[]) is required until DF-033 AUDIT_ACTIONS exists');
  }
  return new Set(allowedKeys);
}

function isAllowedMetadataValue(value) {
  if (typeof value === 'boolean') return true;
  if (typeof value === 'number') return Number.isSafeInteger(value);
  if (typeof value === 'string') return value.length > 0 && value.length <= MAX_METADATA_STRING_LENGTH;
  if (isPlainObject(value)) {
    return Object.values(value).every((count) => Number.isSafeInteger(count) && count >= 0);
  }
  return false;
}

function validateMetadata(action, metadata, allowed) {
  if (metadata === undefined) return {};
  if (!isPlainObject(metadata)) {
    throw new TypeError('writeAuditEntry: metadata must be a plain object');
  }
  for (const [key, value] of Object.entries(metadata)) {
    if (!allowed.has(key)) {
      throw new TypeError(`writeAuditEntry: metadata key '${key}' is not allowed for action '${action}'`);
    }
    if (!isAllowedMetadataValue(value)) {
      throw new TypeError(
        `writeAuditEntry: metadata.${key} must be a short string, boolean, integer or map of integer counts`
      );
    }
  }
  return {...metadata};
}

function buildAuditEntry(entry, options = {}) {
  if (!isPlainObject(entry)) {
    throw new TypeError('writeAuditEntry: entry must be a plain object');
  }
  const {action, actorUid, actorRole, targetCollection, targetId, memberUid, metadata} = entry;
  if (!isNonEmptyString(action)) {
    throw new TypeError('writeAuditEntry: action is required');
  }
  if (actorUid !== null && !isNonEmptyString(actorUid)) {
    throw new TypeError('writeAuditEntry: actorUid must be a uid or null (system)');
  }
  if (!ACTOR_ROLES.includes(actorRole)) {
    throw new TypeError(`writeAuditEntry: actorRole must be one of ${ACTOR_ROLES.join(', ')}`);
  }
  if (!isNonEmptyString(targetCollection) || !isNonEmptyString(targetId)) {
    throw new TypeError('writeAuditEntry: targetCollection and targetId are required');
  }
  if (memberUid !== null && !isNonEmptyString(memberUid)) {
    throw new TypeError('writeAuditEntry: memberUid must be a uid or null (pending member)');
  }
  const allowed = resolveAllowedKeys(action, options);
  const timestamp = FieldValue.serverTimestamp();
  return {
    action,
    actorUid,
    actorRole,
    targetCollection,
    targetId,
    memberUid,
    metadata: validateMetadata(action, metadata, allowed),
    at: timestamp,
    createdAt: timestamp,
    schemaVersion: AUDIT_SCHEMA_VERSION,
  };
}

function isFirestore(writer) {
  return typeof writer.collection === 'function' && typeof writer.batch === 'function';
}

function writeAuditEntry(writer, entry, options = {}) {
  if (!writer || (typeof writer.create !== 'function' && !isFirestore(writer))) {
    throw new TypeError('writeAuditEntry: writer must be a Transaction, WriteBatch or Firestore');
  }
  if (!isPlainObject(options)) {
    throw new TypeError('writeAuditEntry: options must be a plain object');
  }
  const data = buildAuditEntry(entry, options);
  const db = options.db ?? (isFirestore(writer) ? writer : null);
  if (!db) {
    throw new TypeError('writeAuditEntry: options.db is required when writer is a transaction or batch');
  }
  if (options.docId !== undefined && !isNonEmptyString(options.docId)) {
    throw new TypeError('writeAuditEntry: docId must be a non-empty string');
  }
  const collection = db.collection(AUDIT_COLLECTION);
  const ref = options.docId === undefined ? collection.doc() : collection.doc(options.docId);
  if (isFirestore(writer)) {
    return ref.create(data).then(() => ref);
  }
  writer.create(ref, data);
  return ref;
}

module.exports = {
  ACTOR_ROLES,
  AUDIT_COLLECTION,
  AUDIT_SCHEMA_VERSION,
  buildAuditEntry,
  writeAuditEntry,
};
