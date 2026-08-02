'use client';

import { signInWithEmailAndPassword } from 'firebase/auth';
import { useRouter } from 'next/navigation';
import { FormEvent, useState } from 'react';

import { clientAuth } from '@/lib/firebase-client';

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const credential = await signInWithEmailAndPassword(
        clientAuth,
        email.trim(),
        password,
      );
      const idToken = await credential.user.getIdToken(true);
      const response = await fetch('/api/session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ idToken }),
      });
      if (!response.ok) {
        const body = (await response.json()) as { error?: string };
        throw new Error(body.error ?? '관리자 권한을 확인할 수 없습니다.');
      }
      const body = (await response.json()) as { role?: string };
      router.replace(body.role === 'lab_operator' ? '/clinical/ingestions' : '/dashboard');
      router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : '로그인에 실패했습니다.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="form-stack" onSubmit={submit}>
      <div className="field">
        <label htmlFor="email">이메일</label>
        <input
          className="input"
          id="email"
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
        />
      </div>
      <div className="field">
        <label htmlFor="password">비밀번호</label>
        <input
          className="input"
          id="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
      </div>
      {error ? <div className="error">{error}</div> : null}
      <button className="button" disabled={busy} type="submit">
        {busy ? '권한 확인 중…' : '운영 콘솔 로그인'}
      </button>
    </form>
  );
}
