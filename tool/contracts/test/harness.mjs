// Test harness for the contracts generator (DF-004): temp repository roots and CLI runs.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { REPO_ROOT } from './helpers.mjs';

export const GENERATOR = path.join(REPO_ROOT, 'tool', 'contracts', 'generate.mjs');
export const CONTRACT_FILES = ['metric-catalog.v1.json', 'vocab.v1.json', 'prohibited-terms.v1.json', 'feature-flags.v1.json'];

// Copies the inputs (contracts/*.v1.json + meta-schema) into a fresh temp root.
// With { withGenerated: true } the committed generated directories are copied as well.
export function makeRoot({ withGenerated = false, generatedDirs = [] } = {}) {
  const root = mkdtempSync(path.join(tmpdir(), 'dfet-contracts-'));
  mkdirSync(path.join(root, 'contracts'));
  mkdirSync(path.join(root, 'schemas'));
  for (const f of CONTRACT_FILES) {
    cpSync(path.join(REPO_ROOT, 'contracts', f), path.join(root, 'contracts', f));
  }
  cpSync(
    path.join(REPO_ROOT, 'schemas', 'contracts-meta.schema.json'),
    path.join(root, 'schemas', 'contracts-meta.schema.json'),
  );
  if (withGenerated) {
    for (const dir of generatedDirs) {
      const src = path.join(REPO_ROOT, dir);
      if (existsSync(src)) cpSync(src, path.join(root, dir), { recursive: true });
    }
  }
  return root;
}

export function removeRoot(root) {
  rmSync(root, { recursive: true, force: true });
}

export function runCli(args) {
  const r = spawnSync(process.execPath, [GENERATOR, ...args], { encoding: 'utf8' });
  return { code: r.status, stdout: r.stdout, stderr: r.stderr };
}

export function readJson(root, rel) {
  return JSON.parse(readFileSync(path.join(root, rel), 'utf8'));
}

// Writes JSON in the canonical contracts format (2-space, LF, trailing newline).
export function writeJson(root, rel, doc) {
  writeFileSync(path.join(root, rel), `${JSON.stringify(doc, null, 2)}\n`);
}

// Minimal RFC 6901 pointer patching for the bad-* fixtures: op is remove | replace | add.
function parsePointer(pointer) {
  return pointer
    .split('/')
    .slice(1)
    .map((s) => s.replace(/~1/g, '/').replace(/~0/g, '~'));
}

export function applyPatch(doc, ops) {
  for (const { op, path: pointer, value } of ops) {
    const keys = parsePointer(pointer);
    const last = keys.pop();
    let parent = doc;
    for (const k of keys) parent = parent[Array.isArray(parent) ? Number(k) : k];
    if (Array.isArray(parent)) {
      const i = last === '-' ? parent.length : Number(last);
      if (op === 'remove') parent.splice(i, 1);
      else if (op === 'add') parent.splice(i, 0, structuredClone(value));
      else parent[i] = structuredClone(value);
    } else if (op === 'remove') {
      delete parent[last];
    } else {
      parent[last] = structuredClone(value);
    }
  }
  return doc;
}
