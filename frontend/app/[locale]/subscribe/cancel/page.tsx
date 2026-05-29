"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";

export default function SubscribeCancelPage() {
  const t = useTranslations("subscribeCancel");
  const params = useParams<{ locale: string }>();

  return (
    <main className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4 text-center">
        <h1 className="text-2xl font-bold">{t("title")}</h1>
        <p className="text-gray-600">{t("description")}</p>
        <Link
          href={`/${params.locale}/subscribe`}
          className="inline-block rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700"
        >
          {t("tryAgainLink")}
        </Link>
      </div>
    </main>
  );
}
