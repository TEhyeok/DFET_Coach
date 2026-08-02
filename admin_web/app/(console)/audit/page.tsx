import { PageHead } from '@/components/page-head';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate, text } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function AuditPage() {
  await requireConsoleUser(['admin']);
  const snapshot = await adminDb.collection('auditLogs').orderBy('createdAt', 'desc').limit(300).get();
  return <><PageHead title="감사 로그" description="역할·배정·수집·정책 게시 행위를 추적합니다." /><div className="table-wrap"><table className="table"><thead><tr><th>시간</th><th>행위자</th><th>행위</th><th>대상</th><th>메타데이터</th></tr></thead><tbody>{snapshot.docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td>{formatDate(data.createdAt)}</td><td>{text(data.actorEmail ?? data.actorUid)}<br /><span className="status">{text(data.actorRole)}</span></td><td>{text(data.action)}</td><td className="details">{text(data.target)}</td><td className="details">{text(data.metadata)}</td></tr>; })}</tbody></table></div></>;
}
