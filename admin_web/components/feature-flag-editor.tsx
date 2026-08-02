'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

type Flags = { gut: boolean; blood: boolean; insights: boolean };

export function FeatureFlagEditor({ initial }: { initial: Flags }) {
  const router = useRouter();
  const [flags, setFlags] = useState(initial);
  const [message, setMessage] = useState('');

  async function save() {
    setMessage('');
    const response = await fetch('/api/admin/feature-flags', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(flags),
    });
    const body = (await response.json()) as { error?: string };
    setMessage(response.ok ? '기능 플래그를 저장했습니다.' : body.error ?? '저장 실패');
    if (response.ok) router.refresh();
  }

  return (
    <section className="card form-stack">
      {(['gut', 'blood', 'insights'] as const).map((key) => (
        <label key={key}>
          <input
            type="checkbox"
            checked={flags[key]}
            onChange={(event) => setFlags({ ...flags, [key]: event.target.checked })}
          />{' '}{key}
        </label>
      ))}
      <div className="notice">모바일은 문서가 없거나 필드가 누락되면 안전하게 비활성화합니다.</div>
      {message ? <div className={message.includes('저장') ? 'notice' : 'error'}>{message}</div> : null}
      <button className="button" type="button" onClick={save}>기능 플래그 저장</button>
    </section>
  );
}
