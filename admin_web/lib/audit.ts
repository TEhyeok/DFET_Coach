import { FieldValue } from 'firebase-admin/firestore';

import type { ConsoleUser } from './auth';
import { adminDb } from './firebase-admin';

export async function writeAudit(
  actor: ConsoleUser,
  action: string,
  target: Record<string, unknown>,
  metadata: Record<string, unknown> = {},
) {
  await adminDb.collection('auditLogs').add({
    actorUid: actor.uid,
    actorEmail: actor.email ?? null,
    actorRole: actor.role,
    action,
    target,
    metadata,
    createdAt: FieldValue.serverTimestamp(),
  });
}
