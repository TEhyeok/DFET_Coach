#!/usr/bin/env node
'use strict';

/**
 * DF-109 MVP: publish the TEST consent documents ① required, ② healthData, ③ bodyImaging to
 * consentDocumentVersions (DEC-22, 00_README owner action list #10). recordConsent accepts a grant only for a
 * published document version (V1-06 §6.2.3 V5), so the Seoul project needs these before TR-14 can record consent.
 *
 * Dry-run is the default. It builds the documents from the copy deck, prints them and connects to nothing:
 *   node functions/scripts/publish-test-consent-documents.js
 * Apply is for the OWNER only, after `recordConsent` is deployed (owner action #9):
 *   node functions/scripts/publish-test-consent-documents.js --apply --project dfetmanage
 *   Credentials come from Application Default Credentials (`gcloud auth application-default login`) or
 *   GOOGLE_APPLICATION_CREDENTIALS. The script reads no key file itself.
 * Emulator (development): --apply --project demo-dfet with FIRESTORE_EMULATOR_HOST set.
 *
 * Guards: --apply needs --project. An emulator project ID (demo-*, dfet-e2e, dfet-rules-test) needs
 * FIRESTORE_EMULATOR_HOST; any other project ID refuses to run while FIRESTORE_EMULATOR_HOST is set. Exit 2.
 *
 * Content: the deck's consentDraft.<type>.* drafts (docs/v1/data/copy_ko.json, legalReview pendingG04). These are
 * NOT legal consent wording and this script adds none. What marks them as test documents: the title prefix
 * TEST_TITLE_PREFIX, version `test-1` (IDs `<type>--test-1`), privacyPolicyVersion `test-placeholder`, and the
 * retention month count (Q-24, undecided) left as the placeholder `N`. Test members only (DEC-22); retire them and
 * publish reviewed documents (DF-032, G-04) before any real member.
 *
 * Published documents are immutable (V1-05 §4.13). Apply runs one transaction: it creates missing documents, leaves
 * identical ones alone and, if a document with the same ID differs, writes nothing and exits 1.
 */

const fs = require('node:fs');
const path = require('node:path');
const {isDeepStrictEqual} = require('node:util');

const DECK_FILE = path.resolve(__dirname, '../../docs/v1/data/copy_ko.json');
const TEST_TYPES = Object.freeze(['required', 'healthData', 'bodyImaging']);
const TEST_VERSION = 'test-1';
const TEST_TITLE_PREFIX = '[테스트] ';
const TEST_PRIVACY_POLICY_VERSION = 'test-placeholder';
/** Deck placeholders and the marked value they get in a test document. Q-24 (retention months) is undecided. */
const PLACEHOLDER_VALUES = Object.freeze({retentionMonths: 'N'});
const TEXT_FIELDS = Object.freeze(['title', 'purpose', 'items', 'retention', 'refusalNotice']);
const EMULATOR_PROJECT_IDS = Object.freeze(['dfet-e2e', 'dfet-rules-test']);
const EXIT_USAGE = 1;
const EXIT_CONFLICT = 1;
const EXIT_GUARD = 2;

class PublishError extends Error {
  constructor(message, exitCode) {
    super(message);
    this.exitCode = exitCode;
  }
}

function isEmulatorProjectId(projectId) {
  return /^demo-[a-z0-9-]+$/.test(projectId) || EMULATOR_PROJECT_IDS.includes(projectId);
}

function parseArgs(argv) {
  const args = {apply: false, project: null};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') {
      args.apply = true;
    } else if (arg === '--project') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new PublishError('--project needs a value', EXIT_USAGE);
      args.project = value;
      i += 1;
    } else {
      throw new PublishError(`unknown argument: ${arg}`, EXIT_USAGE);
    }
  }
  return args;
}

/** {mode: 'dry-run'} or {mode: 'apply', projectId, emulator}. Throws PublishError on a guard violation. */
function resolveTarget(args, env) {
  if (!args.apply) return {mode: 'dry-run'};
  if (!args.project) throw new PublishError('--apply needs --project <id>', EXIT_USAGE);
  const emulatorHost = String(env.FIRESTORE_EMULATOR_HOST || '').trim();
  const emulator = isEmulatorProjectId(args.project);
  if (emulator && !emulatorHost) {
    throw new PublishError(`${args.project} is an emulator project: set FIRESTORE_EMULATOR_HOST`, EXIT_GUARD);
  }
  if (!emulator && emulatorHost) {
    throw new PublishError(`unset FIRESTORE_EMULATOR_HOST to publish to ${args.project}`, EXIT_GUARD);
  }
  return {mode: 'apply', projectId: args.project, emulator};
}

function loadDeck(file = DECK_FILE) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function deckText(deck, key) {
  const entry = deck.strings && deck.strings[key];
  if (!entry || entry.audience !== 'consentDraft' || typeof entry.ko !== 'string') {
    throw new Error(`deck key ${key} is missing or not a consentDraft entry`);
  }
  let text = entry.ko;
  for (const arg of entry.args || []) {
    if (!Object.prototype.hasOwnProperty.call(PLACEHOLDER_VALUES, arg)) {
      throw new Error(`deck key ${key}: no test value for placeholder {${arg}}`);
    }
    text = text.replaceAll(`{${arg}}`, PLACEHOLDER_VALUES[arg]);
  }
  if (/[{}]/.test(text) || text.trim().length === 0) {
    throw new Error(`deck key ${key}: empty text or unresolved placeholder`);
  }
  return text;
}

/** Splits the deck's comma-separated item list, keeping commas inside parentheses. */
function splitItems(text) {
  const items = [];
  let depth = 0;
  let current = '';
  for (const char of text) {
    if (char === '(') depth += 1;
    if (char === ')') depth -= 1;
    if (char === ',' && depth === 0) {
      items.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  items.push(current.trim());
  return items.filter((item) => item.length > 0);
}

/** [{id, data}] for ①②③. publishedAt is added at apply time. */
function buildTestConsentDocuments(deck) {
  return TEST_TYPES.map((consentType) => {
    const text = Object.fromEntries(
      TEXT_FIELDS.map((field) => [field, deckText(deck, `consentDraft.${consentType}.${field}`)]),
    );
    const data = {
      consentType,
      version: TEST_VERSION,
      title: `${TEST_TITLE_PREFIX}${text.title}`,
      purpose: text.purpose,
      items: splitItems(text.items),
      retention: text.retention,
      recipient: null,
      refusalNotice: text.refusalNotice,
      privacyPolicyVersion: TEST_PRIVACY_POLICY_VERSION,
      status: 'published',
      schemaVersion: 1,
    };
    return {id: `${consentType}--${TEST_VERSION}`, data};
  });
}

function sameContent(stored, data) {
  const {publishedAt: _publishedAt, ...rest} = stored;
  return isDeepStrictEqual(rest, data);
}

/**
 * Creates the documents that do not exist in one transaction. Throws PublishError (nothing written) when an
 * existing document with the same ID has different content. Returns {created, unchanged} ID lists.
 */
async function publishConsentDocuments(db, documents) {
  const {FieldValue} = require('firebase-admin/firestore');
  const refs = documents.map(({id}) => db.collection('consentDocumentVersions').doc(id));
  return db.runTransaction(async (tx) => {
    const snaps = await tx.getAll(...refs);
    const created = [];
    const unchanged = [];
    const conflicts = [];
    snaps.forEach((snap, i) => {
      const {id, data} = documents[i];
      if (!snap.exists) created.push(i);
      else if (sameContent(snap.data(), data)) unchanged.push(id);
      else conflicts.push(id);
    });
    if (conflicts.length > 0) {
      throw new PublishError(
        `published documents are immutable; these IDs already exist with different content: ${conflicts.join(', ')}`,
        EXIT_CONFLICT,
      );
    }
    for (const i of created) {
      tx.create(refs[i], {...documents[i].data, publishedAt: FieldValue.serverTimestamp()});
    }
    return {created: created.map((i) => documents[i].id), unchanged};
  });
}

async function main(argv = process.argv.slice(2), env = process.env) {
  const target = resolveTarget(parseArgs(argv), env);
  const documents = buildTestConsentDocuments(loadDeck());
  for (const {id, data} of documents) {
    console.log(`consentDocumentVersions/${id}`);
    console.log(JSON.stringify(data, null, 2));
  }
  if (target.mode === 'dry-run') {
    console.log(`[dry-run] ${documents.length} test consent documents. Nothing was written.`);
    console.log('[dry-run] The owner publishes them with --apply --project <id>.');
    return;
  }
  const {deleteApp, initializeApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: target.projectId}, 'publish-test-consent-documents');
  try {
    const result = await publishConsentDocuments(getFirestore(app), documents);
    console.log(`[apply] ${target.projectId}${target.emulator ? ' (emulator)' : ''}: `
      + `created ${result.created.length} [${result.created.join(', ')}], `
      + `unchanged ${result.unchanged.length} [${result.unchanged.join(', ')}]`);
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`[error] ${error.message}`);
    process.exit(error instanceof PublishError ? error.exitCode : 1);
  });
}

module.exports = {
  EXIT_GUARD,
  PublishError,
  TEST_TITLE_PREFIX,
  TEST_TYPES,
  TEST_VERSION,
  buildTestConsentDocuments,
  loadDeck,
  parseArgs,
  publishConsentDocuments,
  resolveTarget,
  splitItems,
};
