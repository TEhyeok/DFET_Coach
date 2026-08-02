import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminAuth, adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';

const schema = z.object({
  uid: z.string().min(1),
  role: z.enum(['member', 'trainer', 'admin', 'lab_operator']),
});

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') {
      return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    }
    const input = schema.parse(await request.json());
    const existing = await adminAuth.getUser(input.uid);
    const claims = { ...existing.customClaims };
    delete claims.admin;
    delete claims.trainer;
    if (input.role === 'member') delete claims.role;
    else claims.role = input.role;
    if (input.role === 'admin') claims.admin = true;
    if (input.role === 'trainer') claims.trainer = true;
    await adminAuth.setCustomUserClaims(input.uid, claims);
    await adminDb.collection('users').doc(input.uid).set(
      {
        role: input.role,
        isAdmin: input.role === 'admin',
        isTrainer: input.role === 'trainer',
        roleUpdatedAt: FieldValue.serverTimestamp(),
        roleUpdatedBy: actor.uid,
      },
      { merge: true },
    );
    const trainerRef = adminDb.collection('trainers').doc(input.uid);
    if (input.role === 'trainer') {
      const trainer = await trainerRef.get();
      await trainerRef.set({
        trainerId: input.uid,
        email: existing.email ?? null,
        displayName: existing.displayName ?? '',
        approvalStatus: 'approved',
        ...(!trainer.exists ? { memberIds: [] } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    } else if (existing.customClaims?.trainer === true || existing.customClaims?.role === 'trainer') {
      await trainerRef.set({
        approvalStatus: 'revoked',
        revokedAt: FieldValue.serverTimestamp(),
        revokedBy: actor.uid,
      }, { merge: true });
    }
    const adminRef = adminDb.collection('admins').doc(input.uid);
    if (input.role === 'admin') {
      await adminRef.set({
        email: existing.email ?? null,
        displayName: existing.displayName ?? '',
        role: 'admin',
        approvalStatus: 'approved',
        approvedAt: FieldValue.serverTimestamp(),
        approvedBy: actor.uid,
      }, { merge: true });
    } else if (existing.customClaims?.admin === true || existing.customClaims?.role === 'admin') {
      await adminRef.set({
        approvalStatus: 'rejected',
        revokedAt: FieldValue.serverTimestamp(),
        revokedBy: actor.uid,
      }, { merge: true });
    }
    await writeAudit(actor, 'auth.role.update', { uid: input.uid }, { role: input.role });
    return NextResponse.json({ ok: true });
  } catch (cause) {
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '역할 변경 실패' }, { status: 400 });
  }
}
