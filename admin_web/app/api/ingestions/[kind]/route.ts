import { createHmac } from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';

import { getConsoleUser } from '@/lib/auth';
import { ingestionEnvelopeSchema } from '@/lib/clinical-schema';
import { assertSameOrigin } from '@/lib/request-security';
import { writeAudit } from '@/lib/audit';

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ kind: string }> },
) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor) return NextResponse.json({ error: '로그인이 필요합니다.' }, { status: 401 });
    if (!['admin', 'lab_operator'].includes(actor.role)) {
      return NextResponse.json({ error: '검사 수집 권한이 없습니다.' }, { status: 403 });
    }

    const { kind } = await context.params;
    if (kind !== 'gut' && kind !== 'blood') {
      return NextResponse.json({ error: '지원하지 않는 검사 유형입니다.' }, { status: 404 });
    }
    const parsed = ingestionEnvelopeSchema.parse(await request.json());
    const body = JSON.stringify(parsed);
    const timestamp = Date.now().toString();
    const keyId = process.env.INGEST_HMAC_KEY_ID;
    const secret = process.env.INGEST_HMAC_SECRET;
    const baseUrl = process.env.FUNCTIONS_INGESTION_BASE_URL;
    if (!keyId || !secret || !baseUrl) {
      throw new Error('서버의 검사 수집 HMAC 환경변수가 설정되지 않았습니다.');
    }
    const signature = createHmac('sha256', secret)
      .update(`${timestamp}.${body}`)
      .digest('hex');
    const upstream = await fetch(`${baseUrl}/v1/ingestions/${kind}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-dfet-key-id': keyId,
        'x-dfet-timestamp': timestamp,
        'x-dfet-signature': signature,
      },
      body,
      cache: 'no-store',
    });
    const result = (await upstream.json()) as Record<string, unknown>;
    await writeAudit(actor, 'clinical.ingestion.submit', {
      kind,
      externalReportId: parsed.externalReportId,
      idempotencyKey: parsed.idempotencyKey,
    }, { upstreamStatus: upstream.status }).catch((error) => {
      console.error('Failed to write ingestion submission audit', error);
    });
    return NextResponse.json(result, { status: upstream.status });
  } catch (cause) {
    return NextResponse.json(
      { error: cause instanceof Error ? cause.message : '검사 수집 실패' },
      { status: 400 },
    );
  }
}
