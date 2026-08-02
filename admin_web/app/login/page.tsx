import { redirect } from 'next/navigation';

import { LoginForm } from '@/components/login-form';
import { getConsoleUser } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export default async function LoginPage() {
  const user = await getConsoleUser();
  if (user) redirect('/dashboard');
  return (
    <main className="login-shell">
      <section className="login-card">
        <div className="brand">
          <span className="brand-mark">DF</span>
          <span>D-FET ADMIN</span>
        </div>
        <h1 style={{ marginTop: 32, marginBottom: 8 }}>통합 케어 운영 콘솔</h1>
        <p style={{ color: 'var(--muted)', marginTop: 0, marginBottom: 24 }}>
          승인된 관리자·트레이너·검사자 계정만 접근할 수 있습니다.
        </p>
        <LoginForm />
      </section>
    </main>
  );
}
