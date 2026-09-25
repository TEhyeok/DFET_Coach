// Naming and literal helpers shared by the contracts emitters (DF-004).
// Everything here is pure and deterministic: same input -> same bytes.

// Vocab enum key -> type name in Swift, Dart and TypeScript. Default is UpperCamelCase of the key.
// Overrides avoid clashes with platform types (Foundation.Unit in Swift).
export const TYPE_NAME_OVERRIDES = Object.freeze({ unit: 'MetricUnit' });

// Type names the emitters declare themselves. A vocab enum must not map onto one of them.
export const RESERVED_TYPE_NAMES = Object.freeze([
  'MetricCode',
  'MetricCatalog',
  'MetricCatalogEntry',
  'MetricStorage',
  'MetricRange',
  'ContractVersion',
  'ContractsVersion',
  'VocabStatus',
  'JointMotionPair',
  'JointMotionPairs',
  'ProhibitedTerms',
  'TermRule',
  'TermSeverity',
  'TermBoundary',
  'TermCausalPattern',
  'TermAllowEntry',
]);

// metrics[] field -> vocab enum that holds its allowed values (V1-05 §13.1).
export const METRIC_FIELD_ENUMS = Object.freeze({
  family: 'family',
  unit: 'unit',
  scale: 'scale',
  sideRule: 'sideRule',
  allowedSourceGrades: 'sourceGrade',
  screeningOnlySourceGrades: 'sourceGrade',
  betaSourceGrades: 'sourceGrade',
  reliabilityTier: 'reliabilityTier',
  improvementDirection: 'improvementDirection',
  availability: 'availability',
});

export function upperFirst(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function typeName(enumKey) {
  return TYPE_NAME_OVERRIDES[enumKey] ?? upperFirst(enumKey);
}

// camelCase / UpperCamelCase -> SCREAMING_SNAKE_CASE.
export function screamingSnake(name) {
  return name
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/([A-Z])([A-Z][a-z])/g, '$1_$2')
    .toUpperCase();
}

// Plural used for TypeScript/JS value-list constants: SourceGrade -> SOURCE_GRADES.
export function pluralConstName(typeNameValue) {
  const snake = screamingSnake(typeNameValue);
  if (/(S|X|SH|CH)$/.test(snake)) return `${snake}ES`;
  if (/[^AEIOU]Y$/.test(snake)) return `${snake.slice(0, -1)}IES`;
  return `${snake}S`;
}

// JSON number -> source literal. JSON.stringify gives the shortest round-trip form in every
// target language we emit (no exponent for the ranges the contracts use).
export function numberLiteral(n) {
  if (!Number.isFinite(n)) throw new Error(`non-finite number ${n}`);
  return JSON.stringify(n);
}

// Double-quoted Swift string literal. Escapes backslash (so `\(` cannot interpolate), quote and
// newline/tab; rejects other control characters.
export function dqString(s) {
  let out = '"';
  for (const ch of s) {
    const code = ch.codePointAt(0);
    if (ch === '\\') out += '\\\\';
    else if (ch === '"') out += '\\"';
    else if (ch === '\n') out += '\\n';
    else if (ch === '\t') out += '\\t';
    else if (code < 0x20) throw new Error(`control character U+${code.toString(16)} in contract string`);
    else out += ch;
  }
  return `${out}"`;
}

// Single-quoted string literal for TypeScript/JavaScript (house style) and Dart.
// Dart needs `$` escaped (interpolation); in JS/TS that escape would be useless, so it is opt-in.
export function sqString(s, { escapeDollar = false } = {}) {
  let out = "'";
  for (const ch of s) {
    const code = ch.codePointAt(0);
    if (ch === '\\') out += '\\\\';
    else if (ch === "'") out += "\\'";
    else if (ch === '$' && escapeDollar) out += '\\$';
    else if (ch === '\n') out += '\\n';
    else if (ch === '\t') out += '\\t';
    else if (code < 0x20) throw new Error(`control character U+${code.toString(16)} in contract string`);
    else out += ch;
  }
  return `${out}'`;
}

export function statusComment(entry) {
  return entry.status === 'draft' ? `draft, confirmBy ${entry.confirmBy}` : entry.status;
}

// Joins lines with LF and guarantees exactly one trailing newline.
export function lines(list) {
  return `${list.join('\n').replace(/\n+$/, '')}\n`;
}
