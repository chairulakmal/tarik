"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { auth, type User } from "@/lib/api";
import { clearToken, isAuthenticated } from "@/lib/auth";

export default function SettingsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const t = useTranslations("settings");
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [locale, setLocale] = useState("en");
  const [loading, setLoading] = useState(true);

  const [newEmail, setNewEmail] = useState("");
  const [emailPassword, setEmailPassword] = useState("");
  const [emailNotice, setEmailNotice] = useState<string | null>(null);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [emailSaving, setEmailSaving] = useState(false);

  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [passwordNotice, setPasswordNotice] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSaving, setPasswordSaving] = useState(false);

  const [deletePassword, setDeletePassword] = useState("");
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    params.then(({ locale: l }) => setLocale(l));

    if (!isAuthenticated()) {
      params.then(({ locale: l }) => router.replace(`/${l}/sign-in`));
      return;
    }

    auth
      .me()
      .then(({ data }) => setUser(data))
      .catch(() => {
        clearToken();
        params.then(({ locale: l }) => router.replace(`/${l}/sign-in`));
      })
      .finally(() => setLoading(false));
  }, []);

  async function handleEmailChange(e: React.FormEvent) {
    e.preventDefault();
    setEmailNotice(null);
    setEmailError(null);
    setEmailSaving(true);
    try {
      const { data } = await auth.updateEmail(newEmail, emailPassword);
      setUser(data);
      setNewEmail("");
      setEmailPassword("");
      setEmailNotice(t("emailUpdated"));
    } catch (err) {
      setEmailError(err instanceof Error ? err.message : t("errorUnknown"));
    } finally {
      setEmailSaving(false);
    }
  }

  async function handlePasswordChange(e: React.FormEvent) {
    e.preventDefault();
    setPasswordNotice(null);
    setPasswordError(null);
    setPasswordSaving(true);
    try {
      await auth.updatePassword(currentPassword, newPassword);
      setCurrentPassword("");
      setNewPassword("");
      setPasswordNotice(t("passwordUpdated"));
    } catch (err) {
      setPasswordError(err instanceof Error ? err.message : t("errorUnknown"));
    } finally {
      setPasswordSaving(false);
    }
  }

  async function handleDelete(e: React.FormEvent) {
    e.preventDefault();
    setDeleteError(null);
    setDeleting(true);
    try {
      await auth.deleteAccount(deletePassword);
      clearToken();
      router.push(`/${locale}`);
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : t("errorUnknown"));
      setDeleting(false);
    }
  }

  if (loading) {
    return (
      <main className="flex flex-1 items-center justify-center">
        <p className="text-sm text-gray-500">{t("loading")}</p>
      </main>
    );
  }

  const inputClass = "w-full border rounded px-3 py-2 text-sm";
  const labelClass = "block text-sm font-medium mb-1";

  return (
    <main className="flex flex-1 flex-col items-center gap-6 px-4 py-10">
      <h1 className="text-2xl font-bold">{t("title")}</h1>

      {user && (
        <p className="text-sm text-gray-600">
          {t("signedInAs")} <span className="font-medium">{user.email}</span>
        </p>
      )}

      <section className="w-full max-w-sm rounded-lg border p-4 space-y-3">
        <h2 className="text-sm font-semibold text-gray-700">
          {t("emailSection")}
        </h2>
        <form onSubmit={handleEmailChange} className="space-y-3">
          <div>
            <label className={labelClass}>{t("newEmail")}</label>
            <input
              type="email"
              required
              value={newEmail}
              onChange={(e) => setNewEmail(e.target.value)}
              className={inputClass}
              autoComplete="email"
            />
          </div>
          <div>
            <label className={labelClass}>{t("currentPassword")}</label>
            <input
              type="password"
              required
              value={emailPassword}
              onChange={(e) => setEmailPassword(e.target.value)}
              className={inputClass}
              autoComplete="current-password"
            />
          </div>
          {emailNotice && (
            <p className="text-green-700 text-sm">{emailNotice}</p>
          )}
          {emailError && <p className="text-red-600 text-sm">{emailError}</p>}
          <button
            type="submit"
            disabled={emailSaving}
            className="w-full bg-black text-white rounded py-2 text-sm font-medium disabled:opacity-50"
          >
            {emailSaving ? t("saving") : t("updateEmailButton")}
          </button>
        </form>
      </section>

      <section className="w-full max-w-sm rounded-lg border p-4 space-y-3">
        <h2 className="text-sm font-semibold text-gray-700">
          {t("passwordSection")}
        </h2>
        <form onSubmit={handlePasswordChange} className="space-y-3">
          <div>
            <label className={labelClass}>{t("currentPassword")}</label>
            <input
              type="password"
              required
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className={inputClass}
              autoComplete="current-password"
            />
          </div>
          <div>
            <label className={labelClass}>{t("newPassword")}</label>
            <input
              type="password"
              required
              minLength={15}
              maxLength={128}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className={inputClass}
              autoComplete="new-password"
            />
            <p className="text-xs text-gray-500 mt-1">{t("passwordHint")}</p>
          </div>
          {passwordNotice && (
            <p className="text-green-700 text-sm">{passwordNotice}</p>
          )}
          {passwordError && (
            <p className="text-red-600 text-sm">{passwordError}</p>
          )}
          <button
            type="submit"
            disabled={passwordSaving}
            className="w-full bg-black text-white rounded py-2 text-sm font-medium disabled:opacity-50"
          >
            {passwordSaving ? t("saving") : t("updatePasswordButton")}
          </button>
        </form>
      </section>

      <section className="w-full max-w-sm rounded-lg border border-red-300 p-4 space-y-3">
        <h2 className="text-sm font-semibold text-red-700">
          {t("dangerSection")}
        </h2>
        <p className="text-sm text-gray-600">{t("deleteWarning")}</p>
        <form onSubmit={handleDelete} className="space-y-3">
          <div>
            <label className={labelClass}>{t("currentPassword")}</label>
            <input
              type="password"
              required
              value={deletePassword}
              onChange={(e) => setDeletePassword(e.target.value)}
              className={inputClass}
              autoComplete="current-password"
            />
            <p className="text-xs text-gray-500 mt-1">
              {t("deleteConfirmHint")}
            </p>
          </div>
          {deleteError && <p className="text-red-600 text-sm">{deleteError}</p>}
          <button
            type="submit"
            disabled={deleting}
            className="w-full border border-red-600 text-red-600 rounded py-2 text-sm font-medium hover:bg-red-50 disabled:opacity-50"
          >
            {deleting ? t("saving") : t("deleteButton")}
          </button>
        </form>
      </section>

      <Link
        href={`/${locale}/dashboard`}
        className="text-sm text-gray-600 underline"
      >
        {t("backToDashboard")}
      </Link>
    </main>
  );
}
