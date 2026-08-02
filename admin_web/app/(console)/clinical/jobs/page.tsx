import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate, text } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function JobsPage() {
  await requireConsoleUser(['admin', 'lab_operator']);
  const snapshot = await adminDb.collection('ingestionJobs').orderBy('createdAt', 'desc').limit(200).get();
  return <><PageHead title="수집 작업" description="중복방지, 검증, 정규화, 리포트 생성 상태와 오류를 추적합니다." /><div className="table-wrap"><table className="table"><thead><tr><th>작업</th><th>유형</th><th>외부 ID</th><th>상태</th><th>오류·검토</th><th>시간</th></tr></thead><tbody>{snapshot.docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{doc.id}</td><td>{text(data.kind ?? data.type)}</td><td className="mono">{text(data.externalReportId)}</td><td><StatusPill status={data.status} /></td><td className="details">{text(data.error ?? data.reviewReasons)}</td><td>{formatDate(data.createdAt)}</td></tr>; })}</tbody></table></div></>;
}
