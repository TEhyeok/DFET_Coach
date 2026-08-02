import Link from 'next/link';
import type { ReactNode } from 'react';

import type { ConsoleUser } from '@/lib/auth';
import { roleCanAccess } from '@/lib/auth';

import { LogoutButton } from './logout-button';

const nav = [
  { section: '운영', label: '대시보드', href: '/dashboard', icon: '◫' },
  { section: '운영', label: '회원', href: '/users', icon: '◎' },
  { section: '운영', label: '회원 배정', href: '/assignments', icon: '⇄' },
  { section: '운영', label: '요청', href: '/requests', icon: '✉' },
  { section: '운영', label: '콘텐츠', href: '/content', icon: '▤' },
  { section: '검사', label: '검사 수집', href: '/clinical/ingestions', icon: '⇧' },
  { section: '검사', label: '수집 작업', href: '/clinical/jobs', icon: '⌁' },
  { section: '검사', label: '전문가 리포트', href: '/clinical/reports', icon: '⌘' },
  { section: '설정', label: '정상범위', href: '/settings/reference-ranges', icon: '↔' },
  { section: '설정', label: '통합 정책', href: '/settings/insight-policies', icon: '◇' },
  { section: '설정', label: '기능 플래그', href: '/settings/feature-flags', icon: '◌' },
  { section: '설정', label: '감사 로그', href: '/audit', icon: '◉' },
];

export function ConsoleShell({
  user,
  children,
}: {
  user: ConsoleUser;
  children: ReactNode;
}) {
  const visibleNav = nav.filter((item) => roleCanAccess(user.role, item.href));
  const homeHref = user.role === 'lab_operator' ? '/clinical/ingestions' : '/dashboard';
  return (
    <div className="console">
      <aside className="sidebar">
        <Link className="brand" href={homeHref}>
          <span className="brand-mark">DF</span>
          <span>D-FET ADMIN</span>
        </Link>
        <nav className="nav">
          {visibleNav.map((item, index) => {
            const showSection = visibleNav[index - 1]?.section !== item.section;
            return (
              <div key={item.href}>
                {showSection ? <div className="nav-section">{item.section}</div> : null}
                <Link className="nav-link" href={item.href}>
                  {item.icon} <span>{item.label}</span>
                </Link>
              </div>
            );
          })}
        </nav>
        <div className="account">
          <strong>{user.name ?? user.email ?? '운영자'}</strong>
          <span className="email">{user.email}</span>
          <LogoutButton />
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <h1>통합 케어 운영</h1>
          <span className="role-pill">{user.role}</span>
        </header>
        <main className="content">{children}</main>
      </div>
    </div>
  );
}
