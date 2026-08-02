import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate, text } from '@/lib/format';
import { getAssignedMemberIds, queryDocumentsForMembers, sortByTimestampDescending } from '@/lib/member-scope';

export const dynamic = 'force-dynamic';

export default async function ClinicalReportsPage() {
  const actor = await requireConsoleUser(['admin', 'trainer']);
  const memberIds = actor.role === 'trainer' ? await getAssignedMemberIds(actor.uid) : [];
  const [gutDocs, bloodDocs, snapshotDocs] = actor.role === 'admin'
    ? await Promise.all([
        adminDb.collection('gutReportExperts').orderBy('reportedAt', 'desc').limit(80).get().then((value) => value.docs),
        adminDb.collection('bloodReportExperts').orderBy('reportedAt', 'desc').limit(80).get().then((value) => value.docs),
        adminDb.collection('healthSnapshots').orderBy('asOf', 'desc').limit(80).get().then((value) => value.docs),
      ])
    : await Promise.all([
        queryDocumentsForMembers('gutReportExperts', memberIds).then((docs) => sortByTimestampDescending(docs, 'reportedAt')),
        queryDocumentsForMembers('bloodReportExperts', memberIds).then((docs) => sortByTimestampDescending(docs, 'reportedAt')),
        queryDocumentsForMembers('healthSnapshots', memberIds).then((docs) => sortByTimestampDescending(docs, 'asOf')),
      ]);
  return <><PageHead title="전문가 리포트" description="담당 트레이너와 관리자용 정규화 결과입니다. 회원 소비자 문서와 분리됩니다." />
    <div className="grid">
      <section><h3>장내미생물</h3><div className="table-wrap"><table className="table"><thead><tr><th>리포트</th><th>회원</th><th>정책</th><th>상태</th><th>보고</th></tr></thead><tbody>{gutDocs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{doc.id}</td><td className="mono">{text(data.userId)}</td><td>{text(data.policyVersion)}</td><td><StatusPill status={data.overall?.status ?? data.status} /></td><td>{formatDate(data.reportedAt)}</td></tr>; })}</tbody></table></div></section>
      <section><h3>혈액 POCT</h3><div className="table-wrap"><table className="table"><thead><tr><th>리포트</th><th>회원</th><th>정책</th><th>검토</th><th>보고</th></tr></thead><tbody>{bloodDocs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{doc.id}</td><td className="mono">{text(data.userId)}</td><td>{text(data.policyVersion)}</td><td>{text(data.summary?.reviewCount)}</td><td>{formatDate(data.reportedAt)}</td></tr>; })}</tbody></table></div></section>
      <section><h3>4축 스냅샷</h3><div className="table-wrap"><table className="table"><thead><tr><th>스냅샷</th><th>회원</th><th>점수</th><th>완성도</th><th>누락 축</th></tr></thead><tbody>{snapshotDocs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{doc.id}</td><td className="mono">{text(data.userId)}</td><td>{text(data.overallScore)}</td><td>{Math.round(Number(data.completeness ?? 0) * 100)}%</td><td>{text(data.missingAxes)}</td></tr>; })}</tbody></table></div></section>
    </div></>;
}
