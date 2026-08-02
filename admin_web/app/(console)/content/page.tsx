import { ContentEditor } from '@/components/content-editor';
import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';

export const dynamic = 'force-dynamic';

export default async function ContentPage() {
  await requireConsoleUser(['admin']);
  const [foods, workouts] = await Promise.all([
    adminDb.collection('content_foods').limit(100).get(),
    adminDb.collection('content_workouts').limit(100).get(),
  ]);
  const rows = [...foods.docs.map((doc) => ({ type: '식품', doc })), ...workouts.docs.map((doc) => ({ type: '운동', doc }))];
  return <><PageHead title="콘텐츠 관리" description="회원 앱의 식품·운동 기준 콘텐츠를 관리합니다." /><div className="grid two"><ContentEditor /><div className="table-wrap"><table className="table"><thead><tr><th>유형</th><th>제목</th><th>상태</th></tr></thead><tbody>{rows.map(({ type, doc }) => { const data = doc.data(); return <tr key={`${type}-${doc.id}`}><td>{type}</td><td>{String(data.title ?? data.name ?? doc.id)}</td><td><StatusPill status={data.active === false ? 'inactive' : 'active'} /></td></tr>; })}</tbody></table></div></div></>;
}
