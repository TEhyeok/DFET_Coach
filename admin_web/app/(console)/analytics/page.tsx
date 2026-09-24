import { PageHead } from '@/components/page-head';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';

export const dynamic = 'force-dynamic';

function activeCutoffMillis() {
  return Date.now() - 30 * 24 * 60 * 60 * 1000;
}

export default async function AnalyticsPage() {
  await requireConsoleUser(['admin']);
  const [users, mealCount, workoutCount, snapshotCount] = await Promise.all([
    adminDb.collection('users').limit(1000).get(),
    adminDb.collectionGroup('meals').count().get(),
    adminDb.collectionGroup('workouts').count().get(),
    adminDb.collection('healthSnapshots').count().get(),
  ]);
  const careCounts = { fitness: 0, microbiome: 0, both: 0 };
  let active30 = 0;
  const cutoff = activeCutoffMillis();
  for (const doc of users.docs) {
    const data = doc.data();
    const care = String(data.careType ?? 'fitness');
    if (care in careCounts) careCounts[care as keyof typeof careCounts] += 1;
    if ((data.lastLoginAt?.toMillis?.() ?? 0) >= cutoff) active30 += 1;
  }
  const maxCare = Math.max(1, ...Object.values(careCounts));

  return (
    <>
      <PageHead title="운영 분석" description="매출 추정값 없이 Firestore에 실제 저장된 회원·기록·스냅샷만 집계합니다." />
      <div className="grid stats">
        <div className="card"><div className="stat-label">전체 회원</div><div className="stat-value">{users.size}</div></div>
        <div className="card"><div className="stat-label">30일 활성</div><div className="stat-value">{active30}</div></div>
        <div className="card"><div className="stat-label">식단·운동 기록</div><div className="stat-value">{mealCount.data().count + workoutCount.data().count}</div><div className="details">식단 {mealCount.data().count} · 운동 {workoutCount.data().count}</div></div>
        <div className="card"><div className="stat-label">4축 스냅샷</div><div className="stat-value">{snapshotCount.data().count}</div></div>
      </div>
      <div style={{ height: 16 }} />
      <section className="card">
        <h3>케어유형 분포</h3>
        {Object.entries(careCounts).map(([label, value]) => (
          <div key={label} style={{ marginTop: 16 }}>
            <div className="action-row"><strong>{label}</strong><span>{value}명</span></div>
            <div className="progress-track" style={{ marginTop: 7 }}><div className="progress-value" style={{ width: `${Math.round(value / maxCare * 100)}%` }} /></div>
          </div>
        ))}
      </section>
    </>
  );
}
