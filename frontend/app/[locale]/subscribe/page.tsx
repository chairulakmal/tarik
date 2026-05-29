"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { isAuthenticated } from "@/lib/auth";
import { subscriptions } from "@/lib/api";
import { stripePromise } from "@/lib/stripe";

export default function SubscribePage() {
  const t = useTranslations("subscribe");
  const router = useRouter();
  const params = useParams<{ locale: string }>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace(`/${params.locale}/sign-in`);
    }
  }, [router, params.locale]);

  async function handleSubscribe() {
    if (!stripePromise) {
      setError(t("stripeNotConfigured"));
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const priceId = process.env.NEXT_PUBLIC_STRIPE_PRICE_ID ?? "";
      const base = window.location.origin;
      const { data } = await subscriptions.createCheckout(
        priceId,
        `${base}/${params.locale}/subscribe/success`,
        `${base}/${params.locale}/subscribe/cancel`
      );
      window.location.href = data.checkout_url;
    } catch (err) {
      setError(err instanceof Error ? err.message : t("errorUnknown"));
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-6">
        <h1 className="text-2xl font-bold text-center">{t("title")}</h1>
        <p className="text-center text-gray-600">{t("description")}</p>

        {error && (
          <p className="text-sm text-red-600 text-center">{error}</p>
        )}

        <button
          onClick={handleSubscribe}
          disabled={loading}
          className="w-full rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading ? t("loading") : t("subscribeButton")}
        </button>

        <p className="text-xs text-center text-gray-500">{t("testCardHint")}</p>
      </div>
    </main>
  );
}
