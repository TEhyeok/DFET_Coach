'use strict';

const {round} = require('./normalization');
const {weightedScore} = require('./scoring');

const AXES = Object.freeze(['fitness', 'diet', 'gut', 'blood']);

function isApprovedInsightPolicy(policy) {
  return Boolean(
    policy?.status === 'approved' &&
    typeof policy.version === 'string' &&
    Number.isInteger(policy.minimumAxes) &&
    policy.minimumAxes >= 1 &&
    policy.minimumAxes <= AXES.length &&
    AXES.every((axis) =>
      Number.isFinite(policy.axisWeights?.[axis]) && policy.axisWeights[axis] > 0,
    ),
  );
}

function evaluateRule(rule, axes) {
  if (!rule || !Array.isArray(rule.conditions)) return false;
  return rule.conditions.every((condition) => {
    const value = axes[condition.axis];
    if (!Number.isFinite(value)) return false;
    if (condition.operator === 'gte') return value >= condition.value;
    if (condition.operator === 'lte') return value <= condition.value;
    return false;
  });
}

function buildHealthSnapshot({asOf, axes, policy, sourceReportIds = {}}) {
  const normalizedAxes = Object.fromEntries(
    AXES.map((axis) => [axis, Number.isFinite(axes[axis]) ? round(axes[axis], 1) : null]),
  );
  const availableAxes = AXES.filter((axis) => normalizedAxes[axis] !== null);
  const missingAxes = AXES.filter((axis) => normalizedAxes[axis] === null);
  const approved = isApprovedInsightPolicy(policy);
  const meetsMinimum = approved && availableAxes.length >= policy.minimumAxes;
  const overallScore = meetsMinimum
    ? weightedScore(
      availableAxes.map((axis) => ({
        score: normalizedAxes[axis],
        weight: policy.axisWeights?.[axis],
      })),
    )
    : null;
  const insights = approved
    ? (policy.rules || [])
      .filter((rule) => evaluateRule(rule, normalizedAxes))
      .map((rule) => ({
        id: rule.id,
        title: rule.title,
        body: rule.body,
        action: rule.action || null,
        wording: 'association',
      }))
    : [];

  return {
    asOf,
    axes: normalizedAxes,
    availableAxes,
    missingAxes,
    completeness: round(availableAxes.length / AXES.length, 2),
    overallScore,
    status: overallScore === null ? 'unscored' : 'scored',
    label: overallScore === null ? '산정 준비 중' : '참고용 통합 점수',
    policyVersion: approved ? policy.version : null,
    insights,
    sourceReportIds,
  };
}

module.exports = {AXES, buildHealthSnapshot, evaluateRule, isApprovedInsightPolicy};
