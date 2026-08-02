'use strict';

const {BLOOD_PANELS} = require('./constants');
const {round} = require('./normalization');

const UNSCORED = Object.freeze({
  score: null,
  status: 'unscored',
  label: '산정 준비 중',
  referenceRange: null,
});

function isValidBandDefinition(definition) {
  return Boolean(
    definition &&
    Array.isArray(definition.bands) &&
    definition.bands.length > 0 &&
    definition.bands.every((band) =>
      Number.isFinite(band.score) &&
      band.score >= 0 &&
      band.score <= 100 &&
      (band.min === undefined || Number.isFinite(band.min)) &&
      (band.max === undefined || Number.isFinite(band.max)) &&
      (band.min === undefined || band.max === undefined || band.min <= band.max),
    )
  );
}

function isApprovedBloodPolicy(config) {
  return Boolean(
    config?.status === 'approved' &&
    typeof config.version === 'string' &&
    Object.keys(BLOOD_PANELS)
      .flatMap((panel) => BLOOD_PANELS[panel])
      .every((code) => isValidBandDefinition(config.markers?.[code])),
  );
}

function isApprovedGutPolicy(config) {
  return Boolean(
    config?.status === 'approved' &&
    typeof config.version === 'string' &&
    ['shannon', 'simpson', 'chao1', 'observedOtus']
      .every((metric) => isValidBandDefinition(config.metrics?.[metric])),
  );
}

function matchesBand(value, band) {
  const aboveMinimum = band.min === undefined || value >= band.min;
  const belowMaximum = band.max === undefined || value <= band.max;
  return aboveMinimum && belowMaximum;
}

function scoreMetric(value, definition) {
  if (!definition || !Array.isArray(definition.bands)) return {...UNSCORED};
  const band = definition.bands.find((candidate) => matchesBand(value, candidate));
  if (!band || !Number.isFinite(band.score)) return {...UNSCORED};
  return {
    score: Math.max(0, Math.min(100, round(band.score, 1))),
    status: band.status || 'review',
    label: band.label || '검토 필요',
    referenceRange: definition.referenceRange || null,
  };
}

function weightedScore(items) {
  const scored = items.filter((item) => Number.isFinite(item.score));
  if (scored.length === 0) return null;
  const weighted = scored.reduce(
    (acc, item) => {
      const weight = Number.isFinite(item.weight) && item.weight > 0 ? item.weight : 1;
      return {total: acc.total + item.score * weight, weight: acc.weight + weight};
    },
    {total: 0, weight: 0},
  );
  return round(weighted.total / weighted.weight, 1);
}

function scoreBloodReport(normalized, config) {
  if (!isApprovedBloodPolicy(config)) {
    return {
      policyVersion: null,
      biomarkers: normalized.biomarkers.map((marker) => ({...marker, ...UNSCORED})),
      panels: Object.fromEntries(
        Object.keys(BLOOD_PANELS).map((panel) => [
          panel,
          {score: null, status: 'unscored', completeness: 0},
        ]),
      ),
      overall: {...UNSCORED},
    };
  }

  const biomarkers = normalized.biomarkers.map((marker) => ({
    ...marker,
    ...scoreMetric(marker.value, config.markers?.[marker.code]),
  }));
  const panels = {};
  for (const [panel, expectedCodes] of Object.entries(BLOOD_PANELS)) {
    const present = biomarkers.filter((marker) => marker.panel === panel);
    const score = weightedScore(
      present.map((marker) => ({
        score: marker.score,
        weight: config.markers?.[marker.code]?.weight,
      })),
    );
    panels[panel] = {
      score,
      status: score === null ? 'unscored' : 'scored',
      completeness: round(present.length / expectedCodes.length, 2),
    };
  }
  const overallScore = weightedScore(
    Object.entries(panels).map(([panel, value]) => ({
      score: value.score,
      weight: config.panelWeights?.[panel],
    })),
  );
  return {
    policyVersion: config.version,
    biomarkers,
    panels,
    overall: overallScore === null
      ? {...UNSCORED}
      : {score: overallScore, status: 'scored', label: '참고용 점수', referenceRange: null},
  };
}

function scoreGutReport(normalized, config) {
  const metricEntries = Object.entries(normalized.alpha);
  if (!isApprovedGutPolicy(config)) {
    return {
      policyVersion: null,
      metrics: Object.fromEntries(
        metricEntries.map(([key, value]) => [key, {value, ...UNSCORED}]),
      ),
      overall: {...UNSCORED},
    };
  }
  const metrics = Object.fromEntries(
    metricEntries.map(([key, value]) => [
      key,
      {value, ...scoreMetric(value, config.metrics?.[key])},
    ]),
  );
  const overallScore = weightedScore(
    Object.entries(metrics).map(([key, metric]) => ({
      score: metric.score,
      weight: config.metrics?.[key]?.weight,
    })),
  );
  return {
    policyVersion: config.version,
    metrics,
    overall: overallScore === null
      ? {...UNSCORED}
      : {score: overallScore, status: 'scored', label: '참고용 점수', referenceRange: null},
  };
}

module.exports = {
  UNSCORED,
  matchesBand,
  isApprovedBloodPolicy,
  isApprovedGutPolicy,
  isValidBandDefinition,
  scoreBloodReport,
  scoreGutReport,
  scoreMetric,
  weightedScore,
};
