"use client";

import { Suspense, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/api";

// Landing page for the confirmation link in the sign-up email.
// Only functional when :confirmable is enabled on the API (see bin/setup).
// useSearchParams requires a Suspense boundary during prerender,
// so the content lives in a child component.
function ConfirmContent() {
  const t = useTranslations("auth");
  const token = useSearchParams().get("confirmation_token") ?? "";
  const [status, setStatus] = useState<"pending" | "success" | "error">(
    "pending"
  );
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;
    auth
      .confirmEmail(token)
      .then(() => setStatus("success"))
      .catch((err) => {
        setStatus("error");
        setError(err instanceof Error ? err.message : null);
      });
  }, [token]);

  return (
    <main className="flex flex-1 items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6 text-center">
        <h1 className="text-2xl font-bold">{t("confirmTitle")}</h1>

        {token === "" ? (
          <p className="text-sm text-red-600">{t("missingToken")}</p>
        ) : (
          <>
            {status === "pending" && (
              <p className="text-sm text-gray-500">{t("confirming")}</p>
            )}
            {status === "success" && (
              <p className="text-sm text-gray-600">{t("confirmSuccess")}</p>
            )}
            {status === "error" && (
              <p className="text-sm text-red-600">
                {error ?? t("errorUnknown")}
              </p>
            )}
          </>
        )}

        <p className="text-sm text-gray-600">
          <Link href="../sign-in" className="underline">
            {t("backToSignIn")}
          </Link>
        </p>
      </div>
    </main>
  );
}

export default function ConfirmPage() {
  return (
    <Suspense fallback={null}>
      <ConfirmContent />
    </Suspense>
  );
}
