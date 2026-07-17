"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/api";

export default function SignUpPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const t = useTranslations("auth");
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [confirmationSent, setConfirmationSent] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const { data: newUser } = await auth.signUp(email, password);
      // With :confirmable enabled on the API, sign-in is blocked until the
      // email is confirmed — show a notice instead of signing in.
      if (newUser.confirmationRequired) {
        setConfirmationSent(true);
        return;
      }
      const { data } = await auth.signIn(email, password);
      void data;
      const { locale } = await params;
      router.push(`/${locale}/dashboard`);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("errorUnknown"));
    } finally {
      setLoading(false);
    }
  }

  if (confirmationSent) {
    return (
      <main className="flex flex-1 items-center justify-center px-4">
        <div className="w-full max-w-sm space-y-6 text-center">
          <h1 className="text-2xl font-bold">{t("checkEmailTitle")}</h1>
          <p className="text-sm text-gray-600">{t("checkEmail")}</p>
          <p className="text-sm text-gray-600">
            <Link href="../sign-in" className="underline">
              {t("backToSignIn")}
            </Link>
          </p>
        </div>
      </main>
    );
  }

  return (
    <main className="flex flex-1 items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <h1 className="text-2xl font-bold text-center">{t("signUpTitle")}</h1>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="block text-sm font-medium mb-1">{t("email")}</label>
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

          <div>
            <label htmlFor="password" className="block text-sm font-medium mb-1">{t("password")}</label>
            <input
              id="password"
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

          {error && (
            <p className="text-red-600 text-sm">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-black text-white rounded py-2 text-sm font-medium disabled:opacity-50"
          >
            {loading ? t("loading") : t("signUpButton")}
          </button>
        </form>

        <p className="text-center text-sm text-gray-600">
          {t("alreadyHaveAccount")}{" "}
          <Link href="../sign-in" className="underline">
            {t("signInLink")}
          </Link>
        </p>
      </div>
    </main>
  );
}
