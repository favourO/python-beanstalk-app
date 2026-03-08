"use client";

import { AuthApiError, authApi } from "@/shared/api/auth";
import { hasValidAuthSession, persistAuthSession } from "@/shared/auth/session";
import { Container } from "@/shared/ui/container";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { type FormEvent, useEffect, useMemo, useState } from "react";

export function VerifyScreen() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const email = useMemo(() => searchParams.get("email") ?? "", [searchParams]);

  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (hasValidAuthSession()) {
      router.replace("/projects");
    }
  }, [router]);

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (loading) return;
    setError("");

    if (!email) {
      setError("Missing email. Please return to login.");
      return;
    }
    if (!code.trim()) {
      setError("Enter the OTP code.");
      return;
    }

    setLoading(true);
    try {
      const data = await authApi.verify({
        email: email.trim(),
        code: code.trim(),
      });

      const accessToken = typeof data.access_token === "string" ? data.access_token : "";
      const user = data.user;
      if (!accessToken || !user) {
        setError("Invalid verify response from server.");
        return;
      }

      persistAuthSession(accessToken, user, true);
      const isNewUser = data.is_new_user === true;
      const showPremiumScreen = data.show_premium_screen === true;
      if (showPremiumScreen) {
        router.replace("/premium");
        return;
      }
      router.replace(isNewUser ? "/onboarding" : "/projects");
    } catch (submitError) {
      if (submitError instanceof AuthApiError) {
        setError(submitError.detail);
      } else {
        setError(submitError instanceof Error ? submitError.message : "Verification failed.");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="relative min-h-screen overflow-hidden bg-[#f8faf8] text-[var(--charcoal)]">
      <div className="absolute inset-0 bg-[linear-gradient(180deg,color-mix(in_oklab,var(--accent-teal)_30%,white)_0%,#f9fbfb_40%,color-mix(in_oklab,var(--insight-gold)_14%,white)_100%)]" />
      <Container className="relative z-10 flex min-h-screen items-center justify-center py-8 md:py-12">
        <section className="w-full max-w-[460px] rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-[0_28px_60px_-48px_rgba(11,19,43,0.75)] dark:border-[var(--border-strong)] dark:bg-[var(--charcoal)] md:p-6">
          <header className="mb-4">
            <h1 className="text-3xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
              Verify email
            </h1>
            <p className="mt-1 text-sm text-[var(--muted)]">
              Enter the OTP sent to <span className="font-medium">{email || "your email"}</span>.
            </p>
          </header>

          <form onSubmit={onSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <label htmlFor="otp-code" className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                OTP Code
              </label>
              <input
                id="otp-code"
                name="otp-code"
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                placeholder="Enter 6-digit code"
                value={code}
                onChange={(event) => setCode(event.target.value)}
                className="h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 text-sm text-[var(--foreground)] outline-none transition placeholder:text-[var(--muted)] focus:border-[var(--electric-blue)] focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_28%,transparent)]"
              />
            </div>

            {error ? <p className="text-xs text-red-500">{error}</p> : null}

            <button
              type="submit"
              disabled={loading}
              className="h-10 w-full rounded-md bg-[var(--electric-blue)] text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading ? "Verifying..." : "Verify"}
            </button>

            <p className="text-center text-xs text-[var(--muted)]">
              Back to{" "}
              <Link href="/login" className="font-medium text-[var(--electric-blue)] hover:underline">
                login
              </Link>
            </p>
          </form>
        </section>
      </Container>
    </main>
  );
}
