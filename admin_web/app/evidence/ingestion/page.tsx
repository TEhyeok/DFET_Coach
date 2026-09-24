import { notFound } from 'next/navigation';

import { IngestionForm } from '@/components/ingestion-form';
import { PageHead } from '@/components/page-head';

export default function IngestionEvidencePage() {
  if (process.env.DFET_EVIDENCE_MODE !== 'true') notFound();

  return (
    <div className="console">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">DF</span>
          <span>D-FET ADMIN</span>
        </div>
        <nav className="nav">
          <div className="nav-section">검사</div>
          <div className="nav-link">⇧ <span>검사 수집</span></div>
          <div className="nav-link">⌁ <span>수집 작업</span></div>
        </nav>
        <div className="account">
          <strong>검사 운영자</strong>
          <span className="email">합성 데이터 증빙 모드</span>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <h1>통합 케어 운영</h1>
          <span className="role-pill">lab_operator</span>
        </header>
        <main className="content">
          <PageHead
            title="검사 결과 수집"
            description="JSON·CSV 업로드와 QR/UDI 입력을 같은 검증 파이프라인으로 전송합니다."
          />
          <IngestionForm
            initial={{
              kind: 'blood',
              memberRef: 'SYNTHETIC-MEMBER-001',
              externalReportId: 'POCT-20260810-001',
              revision: 1,
            }}
          />
        </main>
      </div>
    </div>
  );
}
