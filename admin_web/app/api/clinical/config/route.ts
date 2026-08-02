import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';

const schema = z.object({
  collection: z.enum(['referenceRangeVersions', 'insightPolicyVersions']),
  policyKind: z.enum(['gut', 'blood', 'integrated']),
  version: z.string().min(1).max(80),
  status: z.enum(['draft', 'approved']),
  active: z.boolean().default(false),
  config: z.record(z.string(), z.unknown()),
}).superRefine((input, context) => {
  const valid = input.collection === 'referenceRangeVersions'
    ? input.policyKind === 'gut' || input.policyKind === 'blood'
    : input.policyKind === 'integrated';
  if (!valid) context.addIssue({ code: 'custom', message: '설정 종류와 정책 종류가 일치하지 않습니다.' });
  if (input.active && input.status !== 'approved') {
    context.addIssue({ code: 'custom', message: '승인된 설정만 활성화할 수 있습니다.' });
  }
});

function validateApprovedConfig(input: z.infer<typeof schema>) {
  if (input.status !== 'approved') return;
  const asRecord = (value: unknown): Record<string, unknown> | null =>
    value !== null && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  const validateDefinitions = (value: unknown, requiredKeys: string[], label: string) => {
    const definitions = asRecord(value);
    if (!definitions) throw new Error(`${label} 승인 설정이 필요합니다.`);
    for (const key of requiredKeys) {
      const definition = asRecord(definitions[key]);
      const bands = definition?.bands;
      if (!Array.isArray(bands) || bands.length === 0) {
        throw new Error(`${label}.${key}.bands가 필요합니다.`);
      }
      for (const rawBand of bands) {
        const band = asRecord(rawBand);
        const score = Number(band?.score);
        const minimum = band?.min === undefined ? null : Number(band.min);
        const maximum = band?.max === undefined ? null : Number(band.max);
        if (!band || !Number.isFinite(score) || score < 0 || score > 100) {
          throw new Error(`${label}.${key}의 score는 0~100 숫자여야 합니다.`);
        }
        if ((minimum !== null && !Number.isFinite(minimum)) ||
            (maximum !== null && !Number.isFinite(maximum)) ||
            (minimum !== null && maximum !== null && minimum > maximum)) {
          throw new Error(`${label}.${key}의 min/max 범위가 올바르지 않습니다.`);
        }
      }
    }
  };
  if (input.policyKind === 'blood') {
    validateDefinitions(
      input.config.markers,
      ['ALT', 'AST', 'TBIL', 'DBIL', 'TP', 'ALB', 'UREA', 'CRE', 'UA', 'GLU', 'TG', 'CHOL', 'HDL-C'],
      'markers',
    );
  }
  if (input.policyKind === 'gut') {
    validateDefinitions(
      input.config.metrics,
      ['shannon', 'simpson', 'chao1', 'observedOtus'],
      'metrics',
    );
  }
  if (input.policyKind === 'integrated') {
    const minimumAxes = Number(input.config.minimumAxes);
    if (!Number.isInteger(minimumAxes) || minimumAxes < 1 || minimumAxes > 4) {
      throw new Error('통합 승인 설정의 minimumAxes는 1~4 정수여야 합니다.');
    }
    const weights = asRecord(input.config.axisWeights);
    if (!weights) {
      throw new Error('통합 승인 설정에는 axisWeights가 필요합니다.');
    }
    for (const axis of ['fitness', 'diet', 'gut', 'blood']) {
      if (!Number.isFinite(Number(weights[axis])) || Number(weights[axis]) <= 0) {
        throw new Error(`axisWeights.${axis}는 0보다 큰 숫자여야 합니다.`);
      }
    }
  }
}

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    const input = schema.parse(await request.json());
    validateApprovedConfig(input);
    const documentId = `${input.policyKind}--${input.version.replace(/[^a-zA-Z0-9._-]/g, '-')}`;
    const collection = adminDb.collection(input.collection);
    const document = collection.doc(documentId);
    await adminDb.runTransaction(async (transaction) => {
      const [existing, activeVersions] = await Promise.all([
        transaction.get(document),
        input.active
          ? transaction.get(
              collection
                .where('kind', '==', input.policyKind)
                .where('active', '==', true),
            )
          : Promise.resolve(null),
      ]);
      if (existing.exists && existing.data()?.status === 'approved') {
        throw new Error('승인된 버전은 변경할 수 없습니다. 새 버전을 등록해 주세요.');
      }
      activeVersions?.docs.forEach((activeVersion) => {
        if (activeVersion.id !== documentId) {
          transaction.update(activeVersion.ref, {
            active: false,
            deactivatedAt: FieldValue.serverTimestamp(),
            deactivatedBy: actor.uid,
          });
        }
      });
      transaction.set(document, {
        ...input.config,
        kind: input.policyKind,
        version: input.version,
        status: input.status,
        approved: input.status === 'approved',
        active: input.status === 'approved' && input.active,
        ...(input.status === 'approved'
          ? {
              publishedAt: FieldValue.serverTimestamp(),
              approvedAt: FieldValue.serverTimestamp(),
              approvedBy: actor.uid,
            }
          : {}),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor.uid,
      });
    });
    await writeAudit(
      actor,
      'clinical.config.publish',
      { collection: input.collection, version: input.version, policyKind: input.policyKind },
      { status: input.status, active: input.active },
    );
    return NextResponse.json({ ok: true });
  } catch (cause) {
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '설정 저장 실패' }, { status: 400 });
  }
}
