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
  const rows = [
    ...foods.docs.map((doc) => ({ type: '식품', collection: 'content_foods' as const, doc })),
    ...workouts.docs.map((doc) => ({ type: '운동', collection: 'content_workouts' as const, doc })),
  ];
  return <><PageHead title="콘텐츠 관리" description="회원 앱의 식품·운동 기준 콘텐츠를 추가·편집·비활성화합니다." /><div className="grid two"><ContentEditor /><div className="table-wrap"><table className="table"><thead><tr><th>유형</th><th>제목</th><th>상태</th><th>관리</th></tr></thead><tbody>{rows.map(({ type, collection, doc }) => { const data = doc.data(); const title = String(data.title ?? data.name ?? doc.id); return <tr key={`${type}-${doc.id}`}><td>{type}</td><td><strong>{title}</strong><br /><span className="details">{String(data.description ?? '')}</span></td><td><StatusPill status={data.active === false ? 'inactive' : 'active'} /></td><td><details><summary className="button secondary">편집</summary><div style={{ minWidth: 280, paddingTop: 10 }}><ContentEditor compact initial={{ collection, id: doc.id, title, description: String(data.description ?? ''), active: data.active !== false }} /></div></details></td></tr>; })}</tbody></table></div></div></>;
}
