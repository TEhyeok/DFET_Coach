'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

export function RequestStatusEditor({ id, status }: { id: string; status: string }) {
  const router = useRouter();
  const [value, setValue] = useState(status);
  return (
    <select
      className="select"
      value={value}
      onChange={async (event) => {
        const next = event.target.value;
        setValue(next);
        const response = await fetch('/api/admin/requests', {
          method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ id, status: next }),
        });
        if (response.ok) router.refresh();
      }}
    >
      <option value="pending">pending</option>
      <option value="in_progress">in_progress</option>
      <option value="completed">completed</option>
      <option value="rejected">rejected</option>
    </select>
  );
}
