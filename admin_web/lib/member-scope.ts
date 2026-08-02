import type { QueryDocumentSnapshot } from 'firebase-admin/firestore';

import { adminDb } from './firebase-admin';

const IN_QUERY_LIMIT = 30;

export async function getAssignedMemberIds(trainerUid: string): Promise<string[]> {
  const trainer = await adminDb.collection('trainers').doc(trainerUid).get();
  const values = trainer.data()?.memberIds;
  return Array.isArray(values)
    ? [...new Set(values.filter((value): value is string => typeof value === 'string'))]
    : [];
}

export async function isAssignedMember(
  trainerUid: string,
  memberUid: string,
): Promise<boolean> {
  const memberIds = await getAssignedMemberIds(trainerUid);
  return memberIds.includes(memberUid);
}

export async function getMemberDocuments(
  memberIds: string[],
): Promise<QueryDocumentSnapshot[]> {
  if (memberIds.length === 0) return [];
  const snapshots = await Promise.all(
    memberIds.map((uid) => adminDb.collection('users').doc(uid).get()),
  );
  return snapshots.filter(
    (snapshot): snapshot is QueryDocumentSnapshot => snapshot.exists,
  );
}

export async function queryDocumentsForMembers(
  collection: string,
  memberIds: string[],
  memberField = 'userId',
): Promise<QueryDocumentSnapshot[]> {
  if (memberIds.length === 0) return [];
  const chunks: string[][] = [];
  for (let index = 0; index < memberIds.length; index += IN_QUERY_LIMIT) {
    chunks.push(memberIds.slice(index, index + IN_QUERY_LIMIT));
  }
  const snapshots = await Promise.all(
    chunks.map((chunk) =>
      adminDb.collection(collection).where(memberField, 'in', chunk).limit(300).get(),
    ),
  );
  return snapshots.flatMap((snapshot) => snapshot.docs);
}

export function sortByTimestampDescending(
  docs: QueryDocumentSnapshot[],
  field: string,
): QueryDocumentSnapshot[] {
  return docs.sort((left, right) => {
    const leftValue = left.data()[field];
    const rightValue = right.data()[field];
    const leftMillis = typeof leftValue?.toMillis === 'function' ? leftValue.toMillis() : 0;
    const rightMillis = typeof rightValue?.toMillis === 'function' ? rightValue.toMillis() : 0;
    return rightMillis - leftMillis;
  });
}
