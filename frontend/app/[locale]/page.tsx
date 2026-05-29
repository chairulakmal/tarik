import { useTranslations } from 'next-intl';

export default function HomePage() {
  const t = useTranslations('common');

  return (
    <main className="flex flex-1 items-center justify-center">
      <h1 className="text-4xl font-bold">{t('appName')}</h1>
    </main>
  );
}
