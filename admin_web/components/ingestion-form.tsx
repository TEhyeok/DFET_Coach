'use client';

import Papa from 'papaparse';
import { ChangeEvent, FormEvent, useCallback, useMemo, useState } from 'react';

import { KitScanner } from './kit-scanner';

type Kind = 'gut' | 'blood';

function csvToPayload(text: string, kind: Kind): Record<string, unknown> {
  const result = Papa.parse<Record<string, string>>(text, {
    header: true,
    skipEmptyLines: true,
  });
  if (result.errors.length) throw new Error(result.errors[0].message);
  if (kind === 'blood') {
    return {
      biomarkers: result.data.map((row) => ({
        code: row.code,
        value: Number(row.value),
        unit: row.unit,
      })),
    };
  }
  const rows = result.data;
  return {
    alpha: Object.fromEntries(
      rows
        .filter((row) => row.section === 'alpha')
        .map((row) => [row.name, Number(row.value)]),
    ),
    beta: {
      pcoa: rows
        .filter((row) => row.section === 'pcoa')
        .map((row) => ({
          pc1: Number(row.pc1),
          pc2: Number(row.pc2),
          label: row.label || undefined,
          group: row.group || undefined,
          isSubject: row.isSubject === 'true',
        })),
      explainedVariance: rows
        .filter((row) => row.section === 'explainedVariance')
        .map((row) => Number(row.value)),
    },
    abundance: {
      phylum: rows
        .filter((row) => row.section === 'phylum')
        .map((row) => ({ name: row.name, value: Number(row.value) })),
      genus: rows
        .filter((row) => row.section === 'genus')
        .map((row) => ({ name: row.name, value: Number(row.value) })),
    },
    unifrac: Object.fromEntries(
      rows
        .filter((row) => row.section === 'unifrac')
        .map((row) => [row.name, Number(row.value)]),
    ),
    metadata: Object.fromEntries(
      rows
        .filter((row) => row.section === 'metadata')
        .map((row) => [row.name, row.value]),
    ),
  };
}

export function IngestionForm() {
  const [kind, setKind] = useState<Kind>('blood');
  const [memberRef, setMemberRef] = useState('');
  const [memberRefType, setMemberRefType] = useState<'uid' | 'externalId'>('uid');
  const [externalId, setExternalId] = useState('');
  const [revision, setRevision] = useState(1);
  const [kit, setKit] = useState('');
  const [lot, setLot] = useState('');
  const [expiresAt, setExpiresAt] = useState('');
  const [payload, setPayload] = useState('{\n  "biomarkers": []\n}');
  const [uploadSource, setUploadSource] = useState<'admin_json' | 'admin_csv'>('admin_json');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const now = useMemo(() => new Date().toISOString(), []);
  const onScanned = useCallback((value: string) => setKit(value), []);

  function changeKind(value: Kind) {
    setKind(value);
    setPayload(
      value === 'blood'
        ? '{\n  "biomarkers": []\n}'
        : '{\n  "alpha": {},\n  "beta": { "pcoa": [] },\n  "abundance": { "phylum": [], "genus": [] },\n  "unifrac": {}\n}',
    );
  }

  async function loadFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    const content = await file.text();
    const parsed = file.name.toLowerCase().endsWith('.csv')
      ? csvToPayload(content, kind)
      : JSON.parse(content);
    setUploadSource(file.name.toLowerCase().endsWith('.csv') ? 'admin_csv' : 'admin_json');
    setPayload(JSON.stringify(parsed, null, 2));
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage('');
    try {
      const envelope = {
        schemaVersion: '1.0',
        source: uploadSource,
        externalReportId: externalId,
        revision,
        memberRef: memberRefType === 'uid'
          ? memberRef
          : { type: 'externalId', value: memberRef },
        sampledAt: now,
        reportedAt: new Date().toISOString(),
        payload: JSON.parse(payload),
        kit: kit || lot || expiresAt
          ? {
              qr: kit || undefined,
              udi: kit || undefined,
              lot: lot || undefined,
              expiresAt: expiresAt || undefined,
            }
          : undefined,
        idempotencyKey: `${kind}:${externalId}:${revision}`,
      };
      const response = await fetch(`/api/ingestions/${kind}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(envelope),
      });
      const result = (await response.json()) as {
        error?: string | { message?: string };
        data?: { jobId?: string };
      };
      if (!response.ok) {
        const error = typeof result.error === 'string'
          ? result.error
          : result.error?.message;
        throw new Error(error ?? '수집 요청이 거절됐습니다.');
      }
      setMessage(`수집 작업이 생성됐습니다: ${result.data?.jobId ?? '접수 완료'}`);
    } catch (cause) {
      setMessage(cause instanceof Error ? cause.message : '수집 요청 실패');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="grid two" onSubmit={submit}>
      <section className="card form-stack">
        <div className="field">
          <label htmlFor="kind">검사 유형</label>
          <select className="select" id="kind" value={kind} onChange={(event) => changeKind(event.target.value as Kind)}>
            <option value="blood">혈액 POCT</option>
            <option value="gut">장내미생물 16S</option>
          </select>
        </div>
        <div className="field">
          <label htmlFor="memberRef">회원 UID 또는 외부 회원키</label>
          <select className="select" value={memberRefType} onChange={(event) => setMemberRefType(event.target.value as 'uid' | 'externalId')}>
            <option value="uid">Firebase UID</option>
            <option value="externalId">외부 회원키</option>
          </select>
          <input className="input" id="memberRef" required value={memberRef} onChange={(event) => setMemberRef(event.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="externalId">외부 리포트 ID</label>
          <input className="input" id="externalId" required value={externalId} onChange={(event) => setExternalId(event.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="revision">리비전</label>
          <input className="input" id="revision" type="number" min="1" required value={revision} onChange={(event) => setRevision(Number(event.target.value))} />
        </div>
        <div className="field">
          <label htmlFor="kit">QR/UDI</label>
          <input className="input" id="kit" value={kit} onChange={(event) => setKit(event.target.value)} />
        </div>
        <div className="field"><label htmlFor="lot">키트 Lot</label><input className="input" id="lot" value={lot} onChange={(event) => setLot(event.target.value)} /></div>
        <div className="field"><label htmlFor="expiresAt">키트 유효기간</label><input className="input" id="expiresAt" type="date" value={expiresAt} onChange={(event) => setExpiresAt(event.target.value)} /></div>
        <KitScanner onValue={onScanned} />
        <div className="field">
          <label htmlFor="file">JSON 또는 CSV</label>
          <input id="file" type="file" accept=".json,.csv,application/json,text/csv" onChange={loadFile} />
        </div>
      </section>
      <section className="card form-stack">
        <div className="field">
          <label htmlFor="payload">정규화 전 payload</label>
          <textarea className="textarea" id="payload" required value={payload} onChange={(event) => setPayload(event.target.value)} />
        </div>
        <div className="notice">JSON과 CSV는 동일한 HMAC·스키마·중복방지 파이프라인으로 전송됩니다.</div>
        {message ? <div className={message.includes('생성') ? 'notice' : 'error'}>{message}</div> : null}
        <button className="button" disabled={busy} type="submit">{busy ? '검증·수집 중…' : '검사 결과 수집'}</button>
      </section>
    </form>
  );
}
