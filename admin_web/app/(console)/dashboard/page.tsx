import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate } from '@/lib/format';
import { getAssignedMemberIds, queryDocumentsForMembers } from '@/lib/member-scope';

export const dynamic = 'force-dynamic';

async function count(collection: string) {
  const snapshot = await adminDb.collection(collection).count().get();
  return snapshot.data().count;
}

export default async function DashboardPage() {
  const actor = await requireConsoleUser(['admin', 'trainer']);
  const isAdmin = actor.role === 'admin';
  const memberIds = isAdmin ? [] : await getAssignedMemberIds(actor.uid);
  const [users, gut, blood, jobs, latestJobs] = isAdmin
    ? await Promise.all([
        count('users'), count('gutReports'), count('bloodReports'), count('ingestionJobs'),
        adminDb.collection('ingestionJobs').orderBy('createdAt', 'desc').limit(8).get().then((value) => value.docs),
      ])
    : await Promise.all([
        Promise.resolve(memberIds.length),
        queryDocumentsForMembers('gutReports', memberIds).then((value) => value.length),
        queryDocumentsForMembers('bloodReports', memberIds).then((value) => value.length),
        Promise.resolve(0),
        Promise.resolve([]),
      ]);
  return (
    <>
      <PageHead title="운영 대시보드" description="회원과 임상 수집 파이프라인의 현재 상태입니다." />
      <div className="grid stats">
        <div className="card"><div className="stat-label">회원</div><div className="stat-value">{users}</div></div>
        <div className="card"><div className="stat-label">장 리포트</div><div className="stat-value">{gut}</div></div>
        <div className="card"><div className="stat-label">혈액 리포트</div><div className="stat-value">{blood}</div></div>
        {isAdmin ? <div className="card"><div className="stat-label">수집 작업</div><div className="stat-value">{jobs}</div></div> : null}
      </div>
      {isAdmin ? <><div style={{ height: 18 }} />
      <div className="table-wrap">
        <table className="table">
          <thead><tr><th>최근 수집 작업</th><th>유형</th><th>상태</th><th>생성</th></tr></thead>
          <tbody>
            {latestJobs.map((doc) => {
              const data = doc.data();
              return <tr key={doc.id}><td className="mono">{doc.id}</td><td>{String(data.kind ?? data.type ?? '—')}</td><td><StatusPill status={data.status} /></td><td>{formatDate(data.createdAt)}</td></tr>;
            })}
          </tbody>
        </table>
      </div></> : null}
    </>
  );
}
