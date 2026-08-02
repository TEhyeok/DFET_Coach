'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

export function RoleEditor({ uid, role }: { uid: string; role: string }) {
  const router = useRouter();
  const [value, setValue] = useState(role);
  const [busy, setBusy] = useState(false);
  return (
    <div style={{ display: 'flex', gap: 6 }}>
      <select className="select" value={value} onChange={(event) => setValue(event.target.value)}>
        <option value="member">member</option>
        <option value="trainer">trainer</option>
        <option value="lab_operator">lab_operator</option>
        <option value="admin">admin</option>
      </select>
      <button
        className="button secondary"
        disabled={busy || value === role}
        type="button"
        onClick={async () => {
          setBusy(true);
          const response = await fetch('/api/admin/roles', {
            method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ uid, role: value }),
          });
          setBusy(false);
          if (response.ok) router.refresh();
        }}
      >
        저장
      </button>
    </div>
  );
}
