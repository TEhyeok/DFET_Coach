import { PageHead } from '@/components/page-head';
import { RequestResolutionEditor } from '@/components/request-resolution-editor';
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
  return <><PageHead title="회원 요청" description="코칭·상담 요청을 확인하고 회원 앱에 전달할 피드백까지 기록합니다." /><div className="table-wrap"><table className="table"><thead><tr><th>요청</th><th>회원</th><th>내용</th><th>생성</th><th>처리·피드백</th></tr></thead><tbody>{docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{doc.id}</td><td className="mono">{String(data.userId ?? data.memberId ?? '—')}</td><td><strong>{String(data.title ?? '제목 없음')}</strong><br /><span className="details">{String(data.description ?? data.content ?? data.message ?? '—')}</span></td><td>{formatDate(data.createdAt)}</td><td><RequestResolutionEditor id={doc.id} status={String(data.status ?? 'pending')} feedback={String(data.adminFeedback ?? '')} /></td></tr>; })}</tbody></table></div></>;
}
