import { NextRequest, NextResponse } from 'next/server';

import { SESSION_COOKIE } from '@/lib/auth';
import { assertSameOrigin } from '@/lib/request-security';

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const response = NextResponse.json({ ok: true });
    response.cookies.set(SESSION_COOKIE, '', {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.SESSION_COOKIE_SECURE === 'true',
      path: '/',
      maxAge: 0,
    });
    return response;
  } catch {
    return NextResponse.json({ error: '잘못된 요청입니다.' }, { status: 403 });
  }
}
