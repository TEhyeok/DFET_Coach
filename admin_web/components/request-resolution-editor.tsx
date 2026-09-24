'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

function normalizeStatus(status: string) {
  if (status === 'newRequest') return 'pending';
  if (status === 'inProgress') return 'in_progress';
  return status;
}

export function RequestResolutionEditor({
  id,
  status,
  feedback,
}: {
  id: string;
  status: string;
  feedback: string;
}) {
  const router = useRouter();
  const [value, setValue] = useState(normalizeStatus(status));
  const [note, setNote] = useState(feedback);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  return (
    <form
      className="request-editor"
      onSubmit={async (event) => {
        event.preventDefault();
        setBusy(true);
        setMessage('');
        const response = await fetch('/api/admin/requests', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ id, status: value, adminFeedback: note }),
        });
        const result = await response.json().catch(() => ({}));
        setBusy(false);
        if (!response.ok) {
          setMessage(String(result.error ?? '저장하지 못했습니다.'));
          return;
        }
        setMessage('회원 앱에 반영되었습니다.');
        router.refresh();
      }}
    >
      <select className="select" value={value} onChange={(event) => setValue(event.target.value)}>
        <option value="pending">대기</option>
        <option value="in_progress">처리 중</option>
        <option value="completed">완료</option>
        <option value="rejected">반려</option>
      </select>
      <textarea
        className="textarea"
        value={note}
        maxLength={4000}
        placeholder="회원에게 전달할 코치 피드백"
        onChange={(event) => setNote(event.target.value)}
      />
      <button className="button" disabled={busy} type="submit">
        {busy ? '저장 중…' : '상태·피드백 저장'}
      </button>
      {message ? <span className={message.includes('반영') ? 'notice' : 'error'}>{message}</span> : null}
    </form>
  );
}
