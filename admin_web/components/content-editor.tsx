'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export function ContentEditor() {
  const router = useRouter();
  const [collection, setCollection] = useState('content_foods');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  async function submit(event: FormEvent) {
    event.preventDefault();
    const response = await fetch('/api/admin/content', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ collection, title, description, active: true }),
    });
    if (response.ok) {
      setTitle(''); setDescription(''); router.refresh();
    }
  }
  return (
    <form className="card form-stack" onSubmit={submit}>
      <h3>콘텐츠 추가</h3>
      <select className="select" value={collection} onChange={(event) => setCollection(event.target.value)}>
        <option value="content_foods">식품</option>
        <option value="content_workouts">운동</option>
      </select>
      <input className="input" placeholder="제목" required value={title} onChange={(event) => setTitle(event.target.value)} />
      <textarea className="textarea" placeholder="설명" value={description} onChange={(event) => setDescription(event.target.value)} />
      <button className="button" type="submit">저장</button>
    </form>
  );
}
