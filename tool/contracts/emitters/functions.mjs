// Functions emitter (DF-004): functions/src/shared/generated/{contracts.js,json/*.json}.
// The deploy bundle only contains functions/, so the inputs are copied next to the module (ADR-005).
import { lines, pluralConstName, sqString, typeName } from './common.mjs';

export const FUNCTIONS_DIR = 'functions/src/shared/generated';

const str = (s) => sqString(s);

function frozenList(values, indent = '') {
  if (values.length === 0) return 'Object.freeze([])';
  return `Object.freeze([\n${values.map((v) => `${indent}  ${str(v)},`).join('\n')}\n${indent}])`;
}

export function renderContracts({ metricCatalog, vocab }) {
  const out = [
    "'use strict';",
    '',
    '// Contract values for Cloud Functions. Import from here, never from the repository-level contracts/.',
    '// METRIC_CATALOG and VOCAB_ENUMS are the verbatim JSON copies in ./json (deep-frozen).',
    '',
    `const metricCatalogJson = require('./json/${metricCatalog.file}');`,
    `const vocabJson = require('./json/${vocab.file}');`,
    '',
    'function deepFreeze(value) {',
    "  if (value !== null && typeof value === 'object' && !Object.isFrozen(value)) {",
    '    for (const child of Object.values(value)) deepFreeze(child);',
    '    Object.freeze(value);',
    '  }',
    '  return value;',
    '}',
    '',
    'const CONTRACTS_VERSION = Object.freeze({',
  ];
  for (const input of [metricCatalog, vocab]) {
    const { doc } = input;
    out.push(
      `  ${input.key}: Object.freeze({ contract: ${str(doc.contract)}, version: ${doc.version}, revision: ${doc.revision}, sha256: ${str(input.sha12)} }),`,
    );
  }
  out.push(
    '});',
    '',
    '/** metricCode values in PRD appendix A.1 order. */',
    `const METRIC_CODES = ${frozenList(metricCatalog.doc.metrics.map((m) => m.metricCode))};`,
    '',
    '/** Reserved or excluded codes (PRD appendix A.4). Reject on write. */',
    `const EXCLUDED_METRIC_CODES = ${frozenList(metricCatalog.doc.excludedMetricCodes)};`,
    '',
    '/** metricCode -> metrics[] entry, in catalog order. */',
    'const METRIC_CATALOG = Object.freeze(',
    '  Object.fromEntries(deepFreeze(metricCatalogJson.metrics).map((entry) => [entry.metricCode, entry])),',
    ');',
    '',
    '/** Vocab enum name -> allowed wire values. */',
    'const VOCAB = Object.freeze({',
  );
  for (const [key, entry] of Object.entries(vocab.doc.enums)) {
    out.push(`  ${key}: ${frozenList(entry.values, '  ')},`);
  }
  out.push(
    '});',
    '',
    '/** Vocab enum name -> {status, confirmBy?, values, labelsKo?} as in contracts/vocab.v1.json. */',
    'const VOCAB_ENUMS = deepFreeze(vocabJson.enums);',
    '',
    '/** Allowed joint/motion pairs. Empty while draft; do not check pairs until confirmed (ASM-P0-04). */',
    'const JOINT_MOTION_PAIRS = deepFreeze(vocabJson.jointMotionPairs);',
    '',
  );
  const perEnum = [];
  for (const key of Object.keys(vocab.doc.enums)) {
    const name = pluralConstName(typeName(key));
    perEnum.push(name);
    out.push(`const ${name} = VOCAB.${key};`);
  }
  out.push(
    '',
    'module.exports = Object.freeze({',
    '  CONTRACTS_VERSION,',
    '  METRIC_CODES,',
    '  EXCLUDED_METRIC_CODES,',
    '  METRIC_CATALOG,',
    '  VOCAB,',
    '  VOCAB_ENUMS,',
    '  JOINT_MOTION_PAIRS,',
    ...perEnum.map((n) => `  ${n},`),
    '});',
  );
  return lines(out);
}

// Verbatim copy of an input file. JSON has no comment syntax, so this output has no header line.
function jsonCopy(key) {
  return {
    id: `functions.json.${key}`,
    path: (inputs) => `${FUNCTIONS_DIR}/json/${inputs[key].file}`,
    comment: null,
    uses: [key],
    render: (ctx) => ctx[key].text,
  };
}

export const functionsEmitters = Object.freeze({
  metricCatalogJson: jsonCopy('metricCatalog'),
  vocabJson: jsonCopy('vocab'),
  contracts: {
    id: 'functions.contracts',
    path: `${FUNCTIONS_DIR}/contracts.js`,
    comment: '//',
    uses: ['metricCatalog', 'vocab'],
    render: renderContracts,
  },
});
