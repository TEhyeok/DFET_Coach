import { ConfigEditor } from '@/components/config-editor';
import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function InsightPoliciesPage() {
  await requireConsoleUser(['admin']);
  const snapshot = await adminDb.collection('insightPolicyVersions').orderBy('updatedAt', 'desc').limit(50).get();
  return <><PageHead title="통합 점수 정책" description="기간·가중치·최소 데이터량을 버전형 정책으로 관리합니다." /><div className="grid two"><ConfigEditor kind="insightPolicyVersions" /><div className="table-wrap"><table className="table"><thead><tr><th>버전</th><th>상태</th><th>활성</th><th>갱신</th></tr></thead><tbody>{snapshot.docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td className="mono">{String(data.version ?? doc.id)}</td><td><StatusPill status={data.status ?? (data.approved ? 'approved' : 'draft')} /></td><td>{data.active ? '활성' : '—'}</td><td>{formatDate(data.updatedAt)}</td></tr>; })}</tbody></table></div></div></>;
}
