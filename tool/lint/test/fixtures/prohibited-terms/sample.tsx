// 진단 (comment)
/* 치료 (comment) */
import { x } from './lib';

export function Page({ n }: { n: number }) {
  const title = '처방 목록';
  const hint = "진료 안내";
  const tpl = `회원 ${n}명 ${n > 1 ? '재활' : '운동'} 기록`;
  return (
    <section title="정상 범위">
      {/* 교정 (JSX comment) */}
      <p>재활 트레이닝</p>
      <span>{n}명 예방 관리</span>
      <p>일반 문장</p>
    </section>
  );
}
