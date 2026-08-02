'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export function ConfigEditor({ kind }: { kind: 'referenceRangeVersions' | 'insightPolicyVersions' }) {
  const router = useRouter();
  const [version, setVersion] = useState('');
  const [status, setStatus] = useState('draft');
  const [policyKind, setPolicyKind] = useState(kind === 'referenceRangeVersions' ? 'blood' : 'integrated');
  const [active, setActive] = useState(false);
  const [config, setConfig] = useState('{}');
  const [message, setMessage] = useState('');
  async function submit(event: FormEvent) {
    event.preventDefault();
    try {
      const response = await fetch('/api/clinical/config', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ collection: kind, policyKind, version, status, active, config: JSON.parse(config) }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error);
      setMessage('설정을 저장했습니다.');
      router.refresh();
    } catch (cause) {
      setMessage(cause instanceof Error ? cause.message : '저장 실패');
    }
  }
  return (
    <form className="card form-stack" onSubmit={submit}>
      <h3>버전형 설정 등록</h3>
      <input className="input" placeholder="예: 2026.08.1" required value={version} onChange={(event) => setVersion(event.target.value)} />
      {kind === 'referenceRangeVersions' ? <select className="select" value={policyKind} onChange={(event) => setPolicyKind(event.target.value)}><option value="blood">blood</option><option value="gut">gut</option></select> : null}
      <select className="select" value={status} onChange={(event) => setStatus(event.target.value)}>
        <option value="draft">draft</option>
        <option value="approved">approved</option>
      </select>
      <label><input type="checkbox" checked={active} disabled={status !== 'approved'} onChange={(event) => setActive(event.target.checked)} /> 승인 즉시 활성화</label>
      <textarea className="textarea" value={config} onChange={(event) => setConfig(event.target.value)} />
      <div className="notice">기관 승인본만 approved로 게시하십시오. 미승인 설정은 점수 산정에 사용되지 않습니다.</div>
      {message ? <div className={message.includes('저장') ? 'notice' : 'error'}>{message}</div> : null}
      <button className="button" type="submit">설정 저장</button>
    </form>
  );
}
