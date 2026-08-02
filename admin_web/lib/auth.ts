import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

import { adminAuth } from './firebase-admin';

export const SESSION_COOKIE = '__session';
export const SESSION_MAX_AGE_MS = 5 * 24 * 60 * 60 * 1000;

export type ConsoleRole = 'admin' | 'trainer' | 'lab_operator';

export interface ConsoleUser {
  uid: string;
  email?: string;
  name?: string;
  role: ConsoleRole;
}

function readRole(claims: Record<string, unknown>): ConsoleRole | null {
  if (claims.admin === true || claims.role === 'admin') return 'admin';
  if (claims.trainer === true || claims.role === 'trainer') return 'trainer';
  if (claims.role === 'lab_operator') return 'lab_operator';
  return null;
}

export async function getConsoleUser(): Promise<ConsoleUser | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  try {
    const decoded = await adminAuth.verifySessionCookie(token, true);
    const role = readRole(decoded);
    if (!role) return null;
    return {
      uid: decoded.uid,
      email: decoded.email,
      name: decoded.name,
      role,
    };
  } catch {
    return null;
  }
}

export async function requireConsoleUser(
  allowed: ConsoleRole[] = ['admin', 'trainer', 'lab_operator'],
): Promise<ConsoleUser> {
  const user = await getConsoleUser();
  if (!user) redirect('/login');
  if (!allowed.includes(user.role)) redirect('/unauthorized');
  return user;
}

export function roleCanAccess(role: ConsoleRole, href: string): boolean {
  if (role === 'admin') return true;
  if (role === 'trainer') {
    return ['/dashboard', '/users', '/requests', '/clinical/reports'].some(
      (allowed) => href === allowed || href.startsWith(`${allowed}/`),
    );
  }
  return href === '/clinical/ingestions' || href === '/clinical/jobs';
}
