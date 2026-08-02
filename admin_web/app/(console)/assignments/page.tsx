import { AssignmentEditor } from '@/components/assignment-editor';
import { PageHead } from '@/components/page-head';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';

export const dynamic = 'force-dynamic';

export default async function AssignmentsPage() {
  await requireConsoleUser(['admin']);
  const [membersSnapshot, trainersSnapshot] = await Promise.all([
    adminDb.collection('users').limit(300).get(),
    adminDb.collection('users').where('isTrainer', '==', true).get(),
  ]);
  const trainers = trainersSnapshot.docs.map((doc) => ({ uid: doc.id, label: String(doc.data().displayName ?? doc.data().email ?? doc.id) }));
  const members = membersSnapshot.docs.filter((doc) => !doc.data().isTrainer && !doc.data().isAdmin);
  return <><PageHead title="회원 배정" description="회원별 담당 트레이너를 배정합니다." /><div className="table-wrap"><table className="table"><thead><tr><th>회원</th><th>현재 배정</th><th>변경</th></tr></thead><tbody>{members.map((doc) => { const data = doc.data(); const current = String(data.trainerId ?? data.assignedTrainerId ?? ''); return <tr key={doc.id}><td><strong>{String(data.displayName ?? '이름 없음')}</strong><br /><span className="mono">{doc.id}</span></td><td className="mono">{current || '—'}</td><td><AssignmentEditor memberUid={doc.id} currentTrainer={current} trainers={trainers} /></td></tr>; })}</tbody></table></div></>;
}
