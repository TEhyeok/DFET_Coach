import { PageHead } from '@/components/page-head';
import { RoleEditor } from '@/components/role-editor';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate } from '@/lib/format';
import { getAssignedMemberIds, getMemberDocuments } from '@/lib/member-scope';

export const dynamic = 'force-dynamic';

export default async function UsersPage() {
  const actor = await requireConsoleUser(['admin', 'trainer']);
  const docs = actor.role === 'admin'
    ? (await adminDb.collection('users').orderBy('createdAt', 'desc').limit(200).get()).docs
    : await getMemberDocuments(await getAssignedMemberIds(actor.uid));
  return (
    <>
      <PageHead title="회원·권한" description="회원 프로필과 운영 역할을 관리합니다. 역할 변경은 세션 토큰 재발급 후 적용됩니다." />
      <div className="table-wrap"><table className="table">
        <thead><tr><th>회원</th><th>케어유형</th><th>담당 트레이너</th><th>가입</th><th>역할</th></tr></thead>
        <tbody>{docs.map((doc) => {
          const data = doc.data();
          const role = data.role ?? (data.isAdmin ? 'admin' : data.isTrainer ? 'trainer' : 'member');
          return <tr key={doc.id}><td><Link className="record-link" href={`/users/${doc.id}`}><strong>{String(data.displayName ?? '이름 없음')}</strong><br /><span className="mono">{String(data.email ?? doc.id)}</span></Link></td><td>{String(data.careType ?? 'fitness')}</td><td className="mono">{String(data.trainerId ?? data.assignedTrainerId ?? '—')}</td><td>{formatDate(data.createdAt)}</td><td>{actor.role === 'admin' ? <RoleEditor uid={doc.id} role={String(role)} /> : String(role)}</td></tr>;
        })}</tbody>
      </table></div>
    </>
  );
}
import Link from 'next/link';
