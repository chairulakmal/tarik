"use client";

import { Suspense, useState } from "react";
import { useTranslations } from "next-intl";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/api";

// useSearchParams requires a Suspense boundary during prerender,
// so the form lives in a child component.
function ResetPasswordForm() {
  const t = useTranslations("auth");
  const token = useSearchParams().get("token") ?? "";
  const [password, setPassword] = useState("");
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await auth.resetPassword(token, password);
      setDone(true);
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
          {t("resetPasswordTitle")}
        </h1>

        {done ? (
          <p className="text-sm text-gray-600 text-center">
            {t("resetSuccess")}
          </p>
        ) : token === "" ? (
          <p className="text-sm text-gray-600 text-center">
            {t("missingToken")}
          </p>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label
                htmlFor="new-password"
                className="block text-sm font-medium mb-1"
              >
                {t("newPassword")}
              </label>
              <input
                id="new-password"
                type="password"
                required
                minLength={15}
                maxLength={128}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full border rounded px-3 py-2 text-sm"
                autoComplete="new-password"
              />
              <p className="text-xs text-gray-500 mt-1">{t("passwordHint")}</p>
            </div>

            {error && <p className="text-red-600 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-black text-white rounded py-2 text-sm font-medium disabled:opacity-50"
            >
              {loading ? t("loading") : t("resetButton")}
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

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={null}>
      <ResetPasswordForm />
    </Suspense>
  );
}
