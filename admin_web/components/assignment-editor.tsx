'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

export function AssignmentEditor({
  memberUid,
  currentTrainer,
  trainers,
}: {
  memberUid: string;
  currentTrainer: string;
  trainers: Array<{ uid: string; label: string }>;
}) {
  const router = useRouter();
  const [value, setValue] = useState(currentTrainer);
  return (
    <div style={{ display: 'flex', gap: 6 }}>
      <select className="select" value={value} onChange={(event) => setValue(event.target.value)}>
        <option value="">배정 없음</option>
        {trainers.map((trainer) => <option key={trainer.uid} value={trainer.uid}>{trainer.label}</option>)}
      </select>
      <button
        className="button secondary"
        disabled={value === currentTrainer}
        type="button"
        onClick={async () => {
          const response = await fetch('/api/admin/assignments', {
            method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ memberUid, trainerUid: value || null }),
          });
          if (response.ok) router.refresh();
        }}
      >저장</button>
    </div>
  );
}
