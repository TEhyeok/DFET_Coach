import { IngestionForm } from '@/components/ingestion-form';
import { PageHead } from '@/components/page-head';
import { requireConsoleUser } from '@/lib/auth';

export default async function IngestionsPage() {
  await requireConsoleUser(['admin', 'lab_operator']);
  return <><PageHead title="검사 결과 수집" description="JSON·CSV 업로드와 QR/UDI 입력을 같은 검증 파이프라인으로 전송합니다." /><IngestionForm /></>;
}
