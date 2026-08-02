'use client';

import { signOut } from 'firebase/auth';
import { useRouter } from 'next/navigation';

import { clientAuth } from '@/lib/firebase-client';

export function LogoutButton() {
  const router = useRouter();
  return (
    <button
      className="logout"
      onClick={async () => {
        await fetch('/api/logout', { method: 'POST' });
        await signOut(clientAuth).catch(() => undefined);
        router.replace('/login');
        router.refresh();
      }}
      type="button"
    >
      로그아웃
    </button>
  );
}
