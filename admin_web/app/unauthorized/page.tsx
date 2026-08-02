import Link from 'next/link';

export default function UnauthorizedPage() {
  return (
    <main className="login-shell">
      <section className="login-card">
        <h1>접근 권한이 없습니다</h1>
        <p>이 계정의 역할로는 요청한 화면을 볼 수 없습니다.</p>
        <Link className="button" href="/dashboard">
          허용된 화면으로 이동
        </Link>
      </section>
    </main>
  );
}
