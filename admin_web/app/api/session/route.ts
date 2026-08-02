import { NextRequest, NextResponse } from 'next/server';

import { adminAuth } from '@/lib/firebase-admin';
import { assertSameOrigin } from '@/lib/request-security';
import { SESSION_COOKIE, SESSION_MAX_AGE_MS } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const { idToken } = (await request.json()) as { idToken?: string };
    if (!idToken) throw new Error('ID 토큰이 없습니다.');

    const decoded = await adminAuth.verifyIdToken(idToken, true);
    const role = decoded.role;
    const allowed =
      decoded.admin === true ||
      decoded.trainer === true ||
      role === 'admin' ||
      role === 'trainer' ||
      role === 'lab_operator';
    if (!allowed) {
      return NextResponse.json(
        { error: '운영 콘솔 권한이 없는 계정입니다.' },
        { status: 403 },
      );
    }

    const sessionCookie = await adminAuth.createSessionCookie(idToken, {
      expiresIn: SESSION_MAX_AGE_MS,
    });
    const consoleRole = decoded.admin === true
      ? 'admin'
      : decoded.trainer === true
        ? 'trainer'
        : role;
    const response = NextResponse.json({ ok: true, role: consoleRole });
    response.cookies.set(SESSION_COOKIE, sessionCookie, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.SESSION_COOKIE_SECURE === 'true',
      path: '/',
      maxAge: SESSION_MAX_AGE_MS / 1000,
    });
    return response;
  } catch (cause) {
    return NextResponse.json(
      { error: cause instanceof Error ? cause.message : '세션 생성 실패' },
      { status: 401 },
    );
  }
}
