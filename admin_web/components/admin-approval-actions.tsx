'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

export function AdminApprovalActions({ uid }: { uid: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function decide(decision: 'approve' | 'reject') {
    setBusy(true);
    setError('');
    const response = await fetch('/api/admin/approvals', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ uid, decision }),
    });
    const result = await response.json().catch(() => ({}));
    setBusy(false);
    if (!response.ok) {
      setError(String(result.error ?? '처리하지 못했습니다.'));
      return;
    }
    router.refresh();
  }

  return (
    <div>
      <div className="action-row">
        <button className="button" disabled={busy} onClick={() => decide('approve')} type="button">승인</button>
        <button className="button danger" disabled={busy} onClick={() => decide('reject')} type="button">거절</button>
      </div>
      {error ? <div className="error">{error}</div> : null}
    </div>
  );
}
