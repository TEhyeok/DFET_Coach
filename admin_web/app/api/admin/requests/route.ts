import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';
import { isAssignedMember } from '@/lib/member-scope';

const schema = z.object({
  id: z.string().min(1),
  status: z.enum(['pending', 'in_progress', 'completed', 'rejected']),
  adminFeedback: z.string().trim().max(4000).optional(),
});

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || !['admin', 'trainer'].includes(actor.role)) return NextResponse.json({ error: '요청 처리 권한이 없습니다.' }, { status: 403 });
    const input = schema.parse(await request.json());
    const requestRef = adminDb.collection('requests').doc(input.id);
    const requestDocument = await requestRef.get();
    if (!requestDocument.exists) {
      return NextResponse.json({ error: '요청을 찾을 수 없습니다.' }, { status: 404 });
    }
    const requestData = requestDocument.data() ?? {};
    const memberUid = String(requestData.userId ?? requestData.memberId ?? '');
    if (actor.role === 'trainer' && !(await isAssignedMember(actor.uid, memberUid))) {
      return NextResponse.json({ error: '담당 회원의 요청만 처리할 수 있습니다.' }, { status: 403 });
    }
    const feedback = input.adminFeedback?.trim();
    await requestRef.set(
      {
        status: input.status,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor.uid,
        ...(feedback ? {
          adminFeedback: feedback,
          respondedAt: FieldValue.serverTimestamp(),
          respondedBy: actor.uid,
        } : {}),
      },
      { merge: true },
    );
    await writeAudit(actor, 'request.status.update', { requestId: input.id }, {
      status: input.status,
      hasFeedback: Boolean(feedback),
    });
    return NextResponse.json({ ok: true });
  } catch (cause) {
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '요청 상태 변경 실패' }, { status: 400 });
  }
}
