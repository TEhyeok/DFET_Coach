import { NextRequest } from 'next/server';

export function assertSameOrigin(request: NextRequest) {
  const origin = request.headers.get('origin');
  if (!origin) return;
  const expected = new URL(request.url).origin;
  if (origin !== expected) throw new Error('허용되지 않은 요청 출처입니다.');
}
