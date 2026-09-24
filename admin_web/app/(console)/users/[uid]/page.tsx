import { notFound, redirect } from 'next/navigation';

import { PageHead } from '@/components/page-head';
import { StatusPill } from '@/components/status-pill';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { formatDate, text } from '@/lib/format';
import { isAssignedMember } from '@/lib/member-scope';

export const dynamic = 'force-dynamic';

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ uid: string }>;
}) {
  const actor = await requireConsoleUser(['admin', 'trainer']);
  const { uid } = await params;
  if (actor.role === 'trainer' && !(await isAssignedMember(actor.uid, uid))) {
    redirect('/unauthorized');
  }

  const [profile, meals, workouts, gut, blood, snapshots, soap, requests] = await Promise.all([
    adminDb.collection('users').doc(uid).get(),
    adminDb.collection('users').doc(uid).collection('meals').orderBy('date', 'desc').limit(30).get(),
    adminDb.collection('users').doc(uid).collection('workouts').orderBy('timestamp', 'desc').limit(30).get(),
    adminDb.collection('gutReports').where('userId', '==', uid).limit(20).get(),
    adminDb.collection('bloodReports').where('userId', '==', uid).limit(20).get(),
    adminDb.collection('healthSnapshots').where('userId', '==', uid).limit(20).get(),
    adminDb.collection('soap_notes').where('memberId', '==', uid).limit(30).get(),
    adminDb.collection('requests').where('userId', '==', uid).limit(30).get(),
  ]);
  if (!profile.exists) notFound();

  const user = profile.data() ?? {};
  const calorieTotal = meals.docs.reduce((sum, doc) => sum + Number(doc.data().calories ?? 0), 0);
  const workoutMinutes = workouts.docs.reduce((sum, doc) => sum + Number(doc.data().duration ?? 0), 0);
  const latestSnapshots = [...snapshots.docs].sort((a, b) => {
    const left = a.data().asOf?.toMillis?.() ?? 0;
    const right = b.data().asOf?.toMillis?.() ?? 0;
    return right - left;
  });
  const latestSnapshot = latestSnapshots[0]?.data();
  const completeness = Math.round(Number(latestSnapshot?.completeness ?? 0) * 100);

  return (
    <>
      <PageHead
        title={String(user.displayName ?? '이름 없음')}
        description="프로필, 생활 기록, 검사, SOAP, 요청을 실제 저장 데이터 기준으로 확인합니다."
      />
      <div className="grid stats">
        <div className="card"><div className="stat-label">최근 식단</div><div className="stat-value">{meals.size}</div><div className="details">합계 {calorieTotal.toLocaleString('ko-KR')} kcal</div></div>
        <div className="card"><div className="stat-label">최근 운동</div><div className="stat-value">{workouts.size}</div><div className="details">유산소 {workoutMinutes}분</div></div>
        <div className="card"><div className="stat-label">임상 검사</div><div className="stat-value">{gut.size + blood.size}</div><div className="details">장 {gut.size} · 혈액 {blood.size}</div></div>
        <div className="card"><div className="stat-label">4축 완성도</div><div className="stat-value">{latestSnapshot ? `${completeness}%` : '—'}</div><div className="progress-track"><div className="progress-value" style={{ width: `${completeness}%` }} /></div></div>
      </div>
      <div style={{ height: 16 }} />
      <div className="grid two">
        <section className="card">
          <h3>회원 프로필</h3>
          <div className="details">UID · {uid}</div>
          <p>{text(user.email)}</p>
          <div className="action-row"><span className="status">{text(user.role ?? 'member')}</span><span className="status">care · {text(user.careType ?? 'fitness')}</span></div>
          <p className="details">담당 트레이너 · {text(user.trainerId ?? user.assignedTrainerId)}</p>
          <p className="details">가입 · {formatDate(user.createdAt)}<br />최근 로그인 · {formatDate(user.lastLoginAt)}</p>
        </section>
        <section className="card">
          <h3>코칭 연결</h3>
          <div className="grid two">
            <div><div className="stat-label">SOAP 노트</div><div className="stat-value">{soap.size}</div></div>
            <div><div className="stat-label">회원 요청</div><div className="stat-value">{requests.size}</div></div>
          </div>
        </section>
      </div>
      <div style={{ height: 16 }} />
      <section className="table-wrap">
        <table className="table">
          <thead><tr><th>최근 식단</th><th>일시</th><th>열량</th><th>탄·단·지</th></tr></thead>
          <tbody>{meals.docs.map((doc) => { const data = doc.data(); return <tr key={doc.id}><td>{text(data.name)}</td><td>{text(data.date)} {text(data.time)}</td><td>{text(data.calories)} kcal</td><td>{text(data.carbs)} · {text(data.protein)} · {text(data.fat)} g</td></tr>; })}</tbody>
        </table>
      </section>
      <div style={{ height: 16 }} />
      <section className="table-wrap">
        <table className="table">
          <thead><tr><th>최근 운동</th><th>유형</th><th>일시</th><th>기록</th><th>자세점수</th></tr></thead>
          <tbody>{workouts.docs.map((doc) => { const data = doc.data(); const sets = Array.isArray(data.sets) ? data.sets.length : 0; return <tr key={doc.id}><td>{text(data.name)}</td><td>{text(data.category)}</td><td>{text(data.date)}</td><td>{Number(data.duration ?? 0) > 0 ? `${data.duration}분` : `${sets}세트`}</td><td>{text(data.postureScore)}</td></tr>; })}</tbody>
        </table>
      </section>
      <div style={{ height: 16 }} />
      <section className="table-wrap">
        <table className="table">
          <thead><tr><th>연결 데이터</th><th>건수</th><th>최근 상태</th></tr></thead>
          <tbody>
            <tr><td>장내미생물</td><td>{gut.size}</td><td><StatusPill status={gut.docs[0]?.data().status ?? gut.docs[0]?.data().overall?.status} /></td></tr>
            <tr><td>혈액 POCT</td><td>{blood.size}</td><td><StatusPill status={blood.docs[0]?.data().status ?? blood.docs[0]?.data().summary?.status} /></td></tr>
            <tr><td>4축 스냅샷</td><td>{snapshots.size}</td><td>{latestSnapshot ? `누락 축 · ${text(latestSnapshot.missingAxes)}` : '—'}</td></tr>
          </tbody>
        </table>
      </section>
    </>
  );
}
