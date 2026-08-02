import { FeatureFlagEditor } from '@/components/feature-flag-editor';
import { PageHead } from '@/components/page-head';
import { requireConsoleUser } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';

export const dynamic = 'force-dynamic';

export default async function FeatureFlagsPage() {
  await requireConsoleUser(['admin']);
  const document = await adminDb.collection('appConfig').doc('features').get();
  const data = document.data() ?? {};
  return <>
    <PageHead title="기능 플래그" description="장→혈액→통합 인사이트를 독립적으로 점진 활성화합니다." />
    <FeatureFlagEditor initial={{
      gut: data.gut === true,
      blood: data.blood === true,
      insights: data.insights === true,
    }} />
  </>;
}
