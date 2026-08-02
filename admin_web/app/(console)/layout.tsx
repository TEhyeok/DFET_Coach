import type { ReactNode } from 'react';

import { ConsoleShell } from '@/components/console-shell';
import { requireConsoleUser } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export default async function ConsoleLayout({ children }: { children: ReactNode }) {
  const user = await requireConsoleUser();
  return <ConsoleShell user={user}>{children}</ConsoleShell>;
}
