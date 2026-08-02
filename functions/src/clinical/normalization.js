'use strict';

const {BLOOD_MARKERS} = require('./constants');
const {ClinicalValidationError, canonicalMarkerCode} = require('./validation');

function round(value, digits = 4) {
  const factor = 10 ** digits;
  return Math.round((value + Number.EPSILON) * factor) / factor;
}

function normalizeUnit(unit) {
  return unit
    .trim()
    .replace(/μ/g, 'µ')
    .replace(/\s+/g, '')
    .replace(/IU\/L/i, 'U/L')
    .replace(/UMOL\/L/i, 'µmol/L')
    .replace(/ΜMOL\/L/i, 'µmol/L')
    .replace(/MMOL\/L/i, 'mmol/L')
    .replace(/MG\/DL/i, 'mg/dL')
    .replace(/G\/DL/i, 'g/dL')
    .replace(/G\/L/i, 'g/L')
    .replace(/U\/L/i, 'U/L');
}

function convertBloodValue(code, value, sourceUnit) {
  const unit = normalizeUnit(sourceUnit);
  const targetUnit = BLOOD_MARKERS[code].canonicalUnit;
  if (unit === targetUnit) return round(value);

  if ((code === 'ALT' || code === 'AST') && unit === 'U/L') return round(value);
  if ((code === 'TBIL' || code === 'DBIL') && unit === 'µmol/L') {
    return round(value / 17.104);
  }
  if ((code === 'TP' || code === 'ALB') && unit === 'g/L') {
    return round(value / 10);
  }
  if (code === 'UREA' && unit === 'mmol/L') return round(value * 6.006);
  if (code === 'CRE' && unit === 'µmol/L') return round(value / 88.4);
  if (code === 'UA' && unit === 'µmol/L') return round(value / 59.48);
  if (code === 'GLU' && unit === 'mmol/L') return round(value * 18.0182);
  if (code === 'TG' && unit === 'mmol/L') return round(value * 88.57);
  if ((code === 'CHOL' || code === 'HDL-C') && unit === 'mmol/L') {
    return round(value * 38.67);
  }

  throw new ClinicalValidationError('Unsupported biomarker unit', [
    `${code} does not support conversion from ${sourceUnit} to ${targetUnit}`,
  ]);
}

function normalizeBloodPayload(payload) {
  return {
    biomarkers: payload.biomarkers.map((item) => {
      const code = canonicalMarkerCode(item.code);
      const definition = BLOOD_MARKERS[code];
      return {
        code,
        panel: definition.panel,
        sourceValue: item.value,
        sourceUnit: item.unit,
        value: convertBloodValue(code, item.value, item.unit),
        unit: definition.canonicalUnit,
        flags: Array.isArray(item.flags) ? item.flags.map(String) : [],
      };
    }),
    analyzer: payload.analyzer || null,
    notes: typeof payload.notes === 'string' ? payload.notes : null,
  };
}

function normalizeComposition(values, path) {
  const sum = values.reduce((total, item) => total + item.value, 0);
  const usesRatio = values.every((item) => item.value <= 1) && sum <= 1.05;
  const normalized = values.map((item) => ({
    name: item.name.trim(),
    value: round(usesRatio ? item.value * 100 : item.value, 3),
  }));
  const normalizedSum = normalized.reduce((total, item) => total + item.value, 0);
  if (normalizedSum > 100.5) {
    throw new ClinicalValidationError('Microbiome composition exceeds 100%', [
      `${path} totals ${normalizedSum}%`,
    ]);
  }
  return normalized;
}

function normalizeGutPayload(payload) {
  return {
    alpha: {
      shannon: round(payload.alpha.shannon),
      simpson: round(payload.alpha.simpson),
      chao1: round(payload.alpha.chao1),
      observedOtus: round(payload.alpha.observedOtus),
    },
    beta: {
      distance: 'bray-curtis',
      pcoa: payload.beta.pcoa.map((point) => ({
        pc1: round(point.pc1, 6),
        pc2: round(point.pc2, 6),
        label: typeof point.label === 'string' ? point.label : null,
        group: typeof point.group === 'string' ? point.group : null,
        isSubject: point.isSubject === true,
      })),
      explainedVariance: Array.isArray(payload.beta.explainedVariance)
        ? payload.beta.explainedVariance.map((value) => round(value, 6))
        : [],
    },
    abundance: {
      phylum: normalizeComposition(payload.abundance.phylum, 'abundance.phylum'),
      genus: normalizeComposition(payload.abundance.genus, 'abundance.genus'),
    },
    unifrac: {
      weighted: round(payload.unifrac.weighted, 6),
      unweighted: round(payload.unifrac.unweighted, 6),
    },
    metadata: {
      assay: payload.metadata.assay || '16S rRNA V3-V4',
      sampleId: payload.metadata.sampleId || null,
      sequencingPlatform: payload.metadata.sequencingPlatform || null,
      pipeline: payload.metadata.pipeline || null,
      pipelineVersion: payload.metadata.pipelineVersion || null,
      readCount: Number.isFinite(payload.metadata.readCount)
        ? payload.metadata.readCount
        : null,
    },
  };
}

module.exports = {
  convertBloodValue,
  normalizeBloodPayload,
  normalizeComposition,
  normalizeGutPayload,
  normalizeUnit,
  round,
};
