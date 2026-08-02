import { FieldValue } from 'firebase-admin/firestore';
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

import { writeAudit } from '@/lib/audit';
import { getConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';

const schema = z.object({ memberUid: z.string().min(1), trainerUid: z.string().min(1).nullable() });

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    const input = schema.parse(await request.json());
    const memberRef = adminDb.collection('users').doc(input.memberUid);
    await adminDb.runTransaction(async (transaction) => {
      const member = await transaction.get(memberRef);
      if (!member.exists) throw new Error('회원을 찾을 수 없습니다.');
      const previousTrainerUid = String(
        member.data()?.trainerId ?? member.data()?.assignedTrainerId ?? '',
      );
      if (input.trainerUid) {
        const nextTrainerRef = adminDb.collection('trainers').doc(input.trainerUid);
        const nextTrainer = await transaction.get(nextTrainerRef);
        if (!nextTrainer.exists || nextTrainer.data()?.approvalStatus === 'revoked') {
          throw new Error('승인된 트레이너를 찾을 수 없습니다.');
        }
      }
      if (previousTrainerUid && previousTrainerUid !== input.trainerUid) {
        transaction.set(
          adminDb.collection('trainers').doc(previousTrainerUid),
          {
            memberIds: FieldValue.arrayRemove(input.memberUid),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      if (input.trainerUid) {
        transaction.set(
          adminDb.collection('trainers').doc(input.trainerUid),
          {
            memberIds: FieldValue.arrayUnion(input.memberUid),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      transaction.set(
        memberRef,
        {
          trainerId: input.trainerUid || FieldValue.delete(),
          assignedTrainerId: input.trainerUid || FieldValue.delete(),
          assignmentUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    await writeAudit(actor, 'member.assignment.update', { uid: input.memberUid }, { trainerUid: input.trainerUid });
    return NextResponse.json({ ok: true });
  } catch (cause) {
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '회원 배정 실패' }, { status: 400 });
  }
}
