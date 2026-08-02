import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';

const schema = z.object({ gut: z.boolean(), blood: z.boolean(), insights: z.boolean() });

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') {
      return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    }
    const flags = schema.parse(await request.json());
    await adminDb.collection('appConfig').doc('features').set({
      ...flags,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    });
    await writeAudit(actor, 'app.feature_flags.update', { config: 'features' }, flags);
    return NextResponse.json({ ok: true });
  } catch (cause) {
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '기능 플래그 저장 실패' }, { status: 400 });
  }
}
