'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

type ContentDraft = {
  collection: 'content_foods' | 'content_workouts';
  id: string;
  title: string;
  description: string;
  active: boolean;
};

export function ContentEditor({ initial, compact = false }: { initial?: ContentDraft; compact?: boolean }) {
  const router = useRouter();
  const [collection, setCollection] = useState<'content_foods' | 'content_workouts'>(initial?.collection ?? 'content_foods');
  const [title, setTitle] = useState(initial?.title ?? '');
  const [description, setDescription] = useState(initial?.description ?? '');
  const [active, setActive] = useState(initial?.active ?? true);
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setMessage('');
    try {
      const response = await fetch('/api/admin/content', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ collection, id: initial?.id, title, description, active }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error ?? '콘텐츠 저장 실패');
      setMessage(initial ? '변경사항을 저장했습니다.' : '콘텐츠를 추가했습니다.');
      if (!initial) { setTitle(''); setDescription(''); setActive(true); }
      router.refresh();
    } catch (cause) {
      setMessage(cause instanceof Error ? cause.message : '콘텐츠 저장 실패');
    } finally {
      setBusy(false);
    }
  }
  return (
    <form className={compact ? 'form-stack' : 'card form-stack'} onSubmit={submit}>
      <h3>{initial ? '콘텐츠 편집' : '콘텐츠 추가'}</h3>
      <select className="select" disabled={Boolean(initial)} value={collection} onChange={(event) => setCollection(event.target.value as 'content_foods' | 'content_workouts')}>
        <option value="content_foods">식품</option>
        <option value="content_workouts">운동</option>
      </select>
      <input className="input" placeholder="제목" required value={title} onChange={(event) => setTitle(event.target.value)} />
      <textarea className="textarea" placeholder="설명" value={description} onChange={(event) => setDescription(event.target.value)} />
      <label><input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} /> 회원 앱에 노출</label>
      {message ? <div className={message.includes('저장') || message.includes('추가') ? 'notice' : 'error'}>{message}</div> : null}
      <button className="button" disabled={busy} type="submit">{busy ? '저장 중…' : '저장'}</button>
    </form>
  );
}
