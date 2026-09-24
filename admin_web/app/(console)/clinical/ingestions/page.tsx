import { IngestionForm } from '@/components/ingestion-form';
import { PageHead } from '@/components/page-head';
import { requireConsoleUser } from '@/lib/auth';

type Query = Promise<Record<string, string | string[] | undefined>>;

export default async function IngestionsPage({ searchParams }: { searchParams: Query }) {
  await requireConsoleUser(['admin', 'lab_operator']);
  const query = await searchParams;
  const first = (key: string) => {
    const value = query[key];
    return Array.isArray(value) ? value[0] : value;
  };
  const kind = first('kind');
  const revision = Number(first('revision'));
  const correcting = first('correction') === '1';
  return <>
    <PageHead title="검사 결과 수집" description="JSON·CSV 업로드와 QR/UDI 입력을 같은 검증 파이프라인으로 전송합니다." />
    {correcting ? <div className="notice">검증 오류를 수정한 파일을 선택하세요. 기존 결과는 보존되며 증가한 리비전으로 재수집합니다.</div> : null}
    <IngestionForm initial={{
      kind: kind === 'gut' || kind === 'blood' ? kind : undefined,
      memberRef: first('memberRef'),
      externalReportId: first('externalReportId'),
      revision: Number.isInteger(revision) && revision > 0 ? revision : undefined,
    }} />
  </>;
}
