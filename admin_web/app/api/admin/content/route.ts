import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';

const schema = z.object({
  collection: z.enum(['content_foods', 'content_workouts']),
  id: z.string().min(1).optional(),
  title: z.string().min(1).max(160),
  description: z.string().max(2000),
  active: z.boolean(),
});

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    const input = schema.parse(await request.json());
    const ref = input.id
      ? adminDb.collection(input.collection).doc(input.id)
      : adminDb.collection(input.collection).doc();
    await ref.set({
      title: input.title,
      name: input.title,
      description: input.description,
      active: input.active,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    }, { merge: true });
    await writeAudit(actor, 'content.upsert', { collection: input.collection, id: ref.id });
    return NextResponse.json({ ok: true, id: ref.id });
  } catch (cause) {
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '콘텐츠 저장 실패' }, { status: 400 });
  }
}
