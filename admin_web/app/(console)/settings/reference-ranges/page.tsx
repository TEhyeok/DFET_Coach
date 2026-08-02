import { ConfigEditor } from '@/components/config-editor';
import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function ReferenceRangesPage() {
  await requireConsoleUser(['admin']);
  const snapshot = await adminDb.collection('referenceRangeVersions').orderBy('updatedAt', 'desc').limit(50).get();
  return <><PageHead title="정상범위 버전" description="장 지표와 13종 바이오마커 범위·판정 정책을 재현 가능한 버전으로 관리합니다." /><div className="grid two"><ConfigEditor kind="referenceRangeVersions" /><div className="table-wrap"><table className="table"><thead><tr><th>종류</th><th>버전</th><th>상태</th><th>활성</th><th>갱신</th></tr></thead><tbody>{snapshot.docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td>{String(data.kind ?? '—')}</td><td className="mono">{String(data.version ?? doc.id)}</td><td><StatusPill status={data.status ?? (data.approved ? 'approved' : 'draft')} /></td><td>{data.active ? '활성' : '—'}</td><td>{formatDate(data.updatedAt)}</td></tr>; })}</tbody></table></div></div></>;
}
