import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminAuth, adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';

const schema = z.object({
  uid: z.string().min(1),
  decision: z.enum(['approve', 'reject']),
});

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') {
      return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    }
    const input = schema.parse(await request.json());
    const reference = adminDb.collection('admins').doc(input.uid);
    const application = await reference.get();
    if (!application.exists) {
      return NextResponse.json({ error: '승인 신청을 찾을 수 없습니다.' }, { status: 404 });
    }
    if (application.data()?.approvalStatus !== 'pending') {
      return NextResponse.json({ error: '이미 처리된 신청입니다.' }, { status: 409 });
    }

    if (input.decision === 'approve') {
      const user = await adminAuth.getUser(input.uid);
      await adminAuth.setCustomUserClaims(input.uid, {
        ...user.customClaims,
        role: 'admin',
        admin: true,
      });
      await Promise.all([
        reference.set({
          approvalStatus: 'approved',
          role: 'admin',
          approvedAt: FieldValue.serverTimestamp(),
          approvedBy: actor.uid,
        }, { merge: true }),
        adminDb.collection('users').doc(input.uid).set({
          role: 'admin',
          isAdmin: true,
          isApproved: true,
          roleUpdatedAt: FieldValue.serverTimestamp(),
          roleUpdatedBy: actor.uid,
        }, { merge: true }),
      ]);
    } else {
      await reference.set({
        approvalStatus: 'rejected',
        rejectedAt: FieldValue.serverTimestamp(),
        rejectedBy: actor.uid,
      }, { merge: true });
    }

    await writeAudit(actor, `admin.application.${input.decision}`, { uid: input.uid });
    return NextResponse.json({ ok: true });
  } catch (cause) {
    return NextResponse.json({
      error: cause instanceof Error ? cause.message : '승인 처리 실패',
    }, { status: 400 });
  }
}
