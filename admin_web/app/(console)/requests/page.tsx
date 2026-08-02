import { PageHead } from '@/components/page-head';
import { RequestStatusEditor } from '@/components/request-status-editor';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate } from '@/lib/format';
import { getAssignedMemberIds, queryDocumentsForMembers, sortByTimestampDescending } from '@/lib/member-scope';

export const dynamic = 'force-dynamic';

export default async function RequestsPage() {
  const actor = await requireConsoleUser(['admin', 'trainer']);
  const docs = actor.role === 'admin'
    ? (await adminDb.collection('requests').orderBy('createdAt', 'desc').limit(200).get()).docs
    : sortByTimestampDescending(
        await queryDocumentsForMembers('requests', await getAssignedMemberIds(actor.uid)),
        'createdAt',
      );
  return <><PageHead title="회원 요청" description="코칭·상담 요청을 확인하고 처리 상태를 갱신합니다." /><div className="table-wrap"><table className="table"><thead><tr><th>요청</th><th>회원</th><th>내용</th><th>생성</th><th>상태</th></tr></thead><tbody>{docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{doc.id}</td><td className="mono">{String(data.userId ?? data.memberId ?? '—')}</td><td>{String(data.title ?? data.content ?? data.message ?? '—')}</td><td>{formatDate(data.createdAt)}</td><td><RequestStatusEditor id={doc.id} status={String(data.status ?? 'pending')} /></td></tr>; })}</tbody></table></div></>;
}
