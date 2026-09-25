// Shared loaders for the contracts tests (DF-003). Node 22 built-ins only.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

export function readContract(file) {
  const abs = path.join(REPO_ROOT, 'contracts', file);
  return JSON.parse(readFileSync(abs, 'utf8'));
}

export function readContractText(file) {
  return readFileSync(path.join(REPO_ROOT, 'contracts', file), 'utf8');
}

// Visits every (path, key, value) in a JSON tree. `path` is an array of keys/indices.
export function walk(node, visit, trail = []) {
  if (Array.isArray(node)) {
    node.forEach((item, i) => walk(item, visit, [...trail, i]));
    return;
  }
  if (node !== null && typeof node === 'object') {
    for (const [key, value] of Object.entries(node)) {
      visit([...trail, key], key, value);
      walk(value, visit, [...trail, key]);
    }
  }
}

export const HANGUL = /[ᄀ-ᇿ㄰-㆏가-힯]/;

export function duplicates(list) {
  const seen = new Set();
  const dup = new Set();
  for (const item of list) {
    if (seen.has(item)) dup.add(item);
    seen.add(item);
  }
  return [...dup];
}
