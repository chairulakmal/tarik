"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { auth, subscriptions, type User, type Subscription } from "@/lib/api";
import { clearToken, isAuthenticated } from "@/lib/auth";

export default function DashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const t = useTranslations("dashboard");
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [locale, setLocale] = useState("en");
  const [loading, setLoading] = useState(true);
  const [canceling, setCanceling] = useState(false);

  useEffect(() => {
    params.then(({ locale: l }) => setLocale(l));

    if (!isAuthenticated()) {
      params.then(({ locale: l }) => router.replace(`/${l}/sign-in`));
      return;
    }

    Promise.all([auth.me(), subscriptions.current()])
      .then(([userRes, subRes]) => {
        setUser(userRes.data);
        setSubscription(subRes.data);
      })
      .catch(() => {
        clearToken();
        params.then(({ locale: l }) => router.replace(`/${l}/sign-in`));
      })
      .finally(() => setLoading(false));
  }, []);

  async function handleSignOut() {
    try {
      await auth.signOut();
    } finally {
      router.push(`/${locale}/sign-in`);
    }
  }

  async function handleCancelSubscription() {
    setCanceling(true);
    try {
      await subscriptions.cancel();
      const { data } = await subscriptions.current();
      setSubscription(data);
    } catch {
      // subscription panel will reflect current state on next load
    } finally {
      setCanceling(false);
    }
  }

  if (loading) {
    return (
      <main className="flex flex-1 items-center justify-center">
        <p className="text-sm text-gray-500">{t("loading")}</p>
      </main>
    );
  }

  const isActive = subscription?.status === "active" || subscription?.status === "trialing";

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-6 px-4">
      <h1 className="text-2xl font-bold">{t("title")}</h1>

      {user && (
        <p className="text-sm text-gray-600">
          {t("signedInAs")} <span className="font-medium">{user.email}</span>
        </p>
      )}

      <section className="w-full max-w-sm rounded-lg border p-4 space-y-3">
        <h2 className="text-sm font-semibold text-gray-700">{t("subscriptionTitle")}</h2>

        {subscription ? (
          <>
            <div className="flex items-center gap-2">
              <span
                className={`inline-block h-2 w-2 rounded-full ${isActive ? "bg-green-500" : "bg-gray-400"}`}
              />
              <span className="text-sm capitalize">{subscription.status}</span>
              <span className="text-sm text-gray-500">— {subscription.planName}</span>
            </div>

            {subscription.currentPeriodEnd && (
              <p className="text-xs text-gray-500">
                {t("renewsOn")} {new Date(subscription.currentPeriodEnd).toLocaleDateString()}
              </p>
            )}

            {isActive && (
              <button
                onClick={handleCancelSubscription}
                disabled={canceling}
                className="text-xs text-red-600 hover:underline disabled:opacity-50"
              >
                {canceling ? t("loading") : t("cancelSubscription")}
              </button>
            )}
          </>
        ) : (
          <>
            <p className="text-sm text-gray-500">{t("noSubscription")}</p>
            <Link
              href={`/${locale}/subscribe`}
              className="inline-block rounded-md bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700"
            >
              {t("subscribeNow")}
            </Link>
          </>
        )}
      </section>

      <button
        onClick={handleSignOut}
        className="border rounded px-4 py-2 text-sm hover:bg-gray-50"
      >
        {t("signOut")}
      </button>
    </main>
  );
}
