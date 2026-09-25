// DF-027 TC-DF027-04 (AC-DF-027.4): every featureOn('<key>') argument in the security rules is a key of
// contracts/feature-flags.v1.json. Reads firestore.rules and storage.rules; never edits them.
// A key the contract does not know would read as false forever (featureOn defaults to false), so the
// gated write could never open from the admin screen (AD-07).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

import { REPO_ROOT, readContract } from './helpers.mjs';

const RULES_FILES = ['firestore.rules', 'storage.rules'];
const CONTRACT_KEYS = readContract('feature-flags.v1.json').flags.map((f) => f.key);

// Blanks out // and /* */ comments while keeping string literals intact, so a commented-out call
// is not counted and a `//` inside a string does not start a comment.
function stripRuleComments(src) {
  let out = '';
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === "'" || c === '"') {
      let j = i + 1;
      while (j < src.length && src[j] !== c && src[j] !== '\n') j += src[j] === '\\' ? 2 : 1;
      out += src.slice(i, j + 1);
      i = j + 1;
    } else if (c === '/' && src[i + 1] === '/') {
      while (i < src.length && src[i] !== '\n') i += 1;
    } else if (c === '/' && src[i + 1] === '*') {
      const end = src.indexOf('*/', i + 2);
      const stop = end === -1 ? src.length : end + 2;
      out += src.slice(i, stop).replace(/[^\n]/g, ' ');
      i = stop;
    } else {
      out += c;
      i += 1;
    }
  }
  return out;
}

// { keys: [{key, line}], nonLiteral: [{text, line}] } for every featureOn(...) call. The helper's own
// declaration `function featureOn(key)` is not a call.
function featureOnCalls(src) {
  const code = stripRuleComments(src);
  const lineOf = (index) => code.slice(0, index).split('\n').length;
  const keys = [];
  const nonLiteral = [];
  for (const m of code.matchAll(/(\bfunction\s+)?\bfeatureOn\s*\(([^)]*)\)/g)) {
    if (m[1]) continue;
    const arg = m[2].trim();
    const literal = /^(['"])([^'"]*)\1$/.exec(arg);
    if (literal) keys.push({ key: literal[2], line: lineOf(m.index) });
    else nonLiteral.push({ text: m[0], line: lineOf(m.index) });
  }
  return { keys, nonLiteral };
}

for (const file of RULES_FILES) {
  const abs = path.join(REPO_ROOT, file);
  test(`AC-DF-027.4 / TC-DF027-04 ${file}: featureOn keys are a subset of contracts/feature-flags.v1.json`, (t) => {
    if (!existsSync(abs)) return t.skip(`${file} not present`);
    const { keys, nonLiteral } = featureOnCalls(readFileSync(abs, 'utf8'));
    const unknown = keys.filter((k) => !CONTRACT_KEYS.includes(k.key));
    assert.deepEqual(unknown, [], `${file}: featureOn keys missing from the contract: ${unknown.map((u) => `${u.key} (line ${u.line})`).join(', ')}`);
    // A computed key cannot be checked, so the rules must pass a literal.
    assert.deepEqual(nonLiteral, [], `${file}: featureOn must be called with a string literal`);
  });
}

test('AC-DF-027.4 firestore.rules gates soap_notes v2 with a contract key (the scan finds real calls)', () => {
  const { keys } = featureOnCalls(readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8'));
  assert.ok(keys.length > 0, 'expected at least one featureOn call in firestore.rules');
  assert.ok(keys.some((k) => k.key === 'soapV2'), 'soap_notes v2 create is gated by featureOn(\'soapV2\') (DF-020)');
});

test('AC-DF-027.4 featureOn in firestore.rules reads a missing document or key as off (AC-IA-02)', () => {
  const code = stripRuleComments(readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8'));
  const body = /function\s+featureOn\s*\(\s*key\s*\)\s*\{([^}]*)\}/.exec(code);
  assert.ok(body, 'featureOn helper is defined');
  assert.match(body[1], /appConfig\/features\)\.data\.get\(key,\s*false\)\s*==\s*true/);
});

test('TC-DF027-04 the scanner reports unknown and computed keys and ignores comments', () => {
  const rules = [
    "function featureOn(key) { return true; }",
    "allow create: if featureOn('soapV2') && featureOn(\"lidarBeta\");",
    "allow update: if featureOn( 'bodyScanV9' );",
    "// allow delete: if featureOn('commentedOut');",
    "/* featureOn('blockComment') */ allow read: if featureOn(someKey);",
    "allow get: if request.path == '//not/a/comment' && featureOn('gut');",
  ].join('\n');
  const { keys, nonLiteral } = featureOnCalls(rules);
  assert.deepEqual(keys, [
    { key: 'soapV2', line: 2 },
    { key: 'lidarBeta', line: 2 },
    { key: 'bodyScanV9', line: 3 },
    { key: 'gut', line: 6 },
  ]);
  assert.deepEqual(nonLiteral, [{ text: 'featureOn(someKey)', line: 5 }]);
  assert.deepEqual(keys.filter((k) => !CONTRACT_KEYS.includes(k.key)).map((k) => k.key), ['bodyScanV9']);
});
