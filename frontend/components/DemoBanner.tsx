"use client";

import { useTranslations } from "next-intl";

export default function DemoBanner() {
  const t = useTranslations("demo");

  return (
    <div className="bg-amber-50 border-b border-amber-200 px-4 py-2 text-center text-sm text-amber-800">
      {t("banner")}
    </div>
  );
}
