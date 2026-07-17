"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import Link from "next/link";
import { auth } from "@/lib/api";

export default function ForgotPasswordPage() {
  const t = useTranslations("auth");
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await auth.requestPasswordReset(email);
      setSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("errorUnknown"));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex flex-1 items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <h1 className="text-2xl font-bold text-center">
          {t("forgotPasswordTitle")}
        </h1>

        {sent ? (
          <p className="text-sm text-gray-600 text-center">{t("resetSent")}</p>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <p className="text-sm text-gray-600">{t("forgotPasswordHint")}</p>

            <div>
              <label htmlFor="email" className="block text-sm font-medium mb-1">
                {t("email")}
              </label>
              <input
                id="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full border rounded px-3 py-2 text-sm"
                autoComplete="email"
              />
            </div>

            {error && <p className="text-red-600 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-black text-white rounded py-2 text-sm font-medium disabled:opacity-50"
            >
              {loading ? t("loading") : t("sendResetLink")}
            </button>
          </form>
        )}

        <p className="text-center text-sm text-gray-600">
          <Link href="../sign-in" className="underline">
            {t("backToSignIn")}
          </Link>
        </p>
      </div>
    </main>
  );
}
