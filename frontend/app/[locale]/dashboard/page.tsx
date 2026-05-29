"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { auth, type User } from "@/lib/api";
import { clearToken, isAuthenticated } from "@/lib/auth";

export default function DashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const t = useTranslations("dashboard");
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isAuthenticated()) {
      params.then(({ locale }) => router.replace(`/${locale}/sign-in`));
      return;
    }
    auth
      .me()
      .then(({ data }) => setUser(data))
      .catch(() => {
        clearToken();
        params.then(({ locale }) => router.replace(`/${locale}/sign-in`));
      })
      .finally(() => setLoading(false));
  }, []);

  async function handleSignOut() {
    await params;
    try {
      await auth.signOut();
    } finally {
      const { locale } = await params;
      router.push(`/${locale}/sign-in`);
    }
  }

  if (loading) {
    return (
      <main className="flex flex-1 items-center justify-center">
        <p className="text-sm text-gray-500">{t("loading")}</p>
      </main>
    );
  }

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-4 px-4">
      <h1 className="text-2xl font-bold">{t("title")}</h1>
      {user && (
        <p className="text-sm text-gray-600">
          {t("signedInAs")} <span className="font-medium">{user.email}</span>
        </p>
      )}
      <button
        onClick={handleSignOut}
        className="mt-4 border rounded px-4 py-2 text-sm hover:bg-gray-50"
      >
        {t("signOut")}
      </button>
    </main>
  );
}
