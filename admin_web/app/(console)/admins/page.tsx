import { AdminApprovalActions } from '@/components/admin-approval-actions';
import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate, text } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function AdminsPage() {
  await requireConsoleUser(['admin']);
  const snapshot = await adminDb.collection('admins').orderBy('createdAt', 'desc').limit(200).get();
  return (
    <>
      <PageHead title="관리자 승인" description="가입 신청을 검토하고 승인 시 Auth 권한과 운영 프로필을 함께 갱신합니다." />
      <div className="table-wrap"><table className="table">
        <thead><tr><th>신청자</th><th>신청일</th><th>상태</th><th>처리</th></tr></thead>
        <tbody>{snapshot.docs.map((doc) => { const data = doc.data(); const pending = String(data.approvalStatus ?? 'pending') === 'pending'; return <tr key={doc.id}><td><strong>{text(data.displayName)}</strong><br /><span className="mono">{text(data.email ?? doc.id)}</span></td><td>{formatDate(data.createdAt)}</td><td><StatusPill status={data.approvalStatus} /></td><td>{pending ? <AdminApprovalActions uid={doc.id} /> : <span className="details">{formatDate(data.approvedAt ?? data.rejectedAt ?? data.revokedAt)}</span>}</td></tr>; })}</tbody>
      </table></div>
    </>
  );
}
