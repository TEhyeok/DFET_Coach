'use strict';

const BLOOD_MARKERS = Object.freeze({
  ALT: {panel: 'liver', canonicalUnit: 'U/L'},
  AST: {panel: 'liver', canonicalUnit: 'U/L'},
  TBIL: {panel: 'liver', canonicalUnit: 'mg/dL'},
  DBIL: {panel: 'liver', canonicalUnit: 'mg/dL'},
  TP: {panel: 'liver', canonicalUnit: 'g/dL'},
  ALB: {panel: 'liver', canonicalUnit: 'g/dL'},
  UREA: {panel: 'kidney', canonicalUnit: 'mg/dL'},
  CRE: {panel: 'kidney', canonicalUnit: 'mg/dL'},
  UA: {panel: 'kidney', canonicalUnit: 'mg/dL'},
  GLU: {panel: 'metabolic', canonicalUnit: 'mg/dL'},
  TG: {panel: 'lipid', canonicalUnit: 'mg/dL'},
  CHOL: {panel: 'lipid', canonicalUnit: 'mg/dL'},
  'HDL-C': {panel: 'lipid', canonicalUnit: 'mg/dL'},
});

const BLOOD_MARKER_ALIASES = Object.freeze({
  CREATININE: 'CRE',
  CREA: 'CRE',
  URIC_ACID: 'UA',
  GLUCOSE: 'GLU',
  TRIGLYCERIDE: 'TG',
  TRIGLYCERIDES: 'TG',
  TOTAL_CHOLESTEROL: 'CHOL',
  HDL: 'HDL-C',
  HDLC: 'HDL-C',
  TOTAL_BILIRUBIN: 'TBIL',
  DIRECT_BILIRUBIN: 'DBIL',
  TOTAL_PROTEIN: 'TP',
  ALBUMIN: 'ALB',
});

const BLOOD_PANELS = Object.freeze({
  liver: ['ALT', 'AST', 'TBIL', 'DBIL', 'TP', 'ALB'],
  kidney: ['UREA', 'CRE', 'UA'],
  metabolic: ['GLU'],
  lipid: ['TG', 'CHOL', 'HDL-C'],
});

const INGESTION_TYPES = Object.freeze(['gut', 'blood']);
const SCHEMA_VERSION = '1.0';

module.exports = {
  BLOOD_MARKERS,
  BLOOD_MARKER_ALIASES,
  BLOOD_PANELS,
  INGESTION_TYPES,
  SCHEMA_VERSION,
};
