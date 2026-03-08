"use client";

import { AuthApiError, authApi } from "@/shared/api/auth";
import { persistAuthSession } from "@/shared/auth/session";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { type FormEvent, useMemo, useState } from "react";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const googleButtonLabel = useMemo(() => {
    return "Continue with Google";
  }, []);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (loading) return;
    setError("");

    if (!email.trim() || !password) {
      setError("Please provide email and password.");
      return;
    }

    setLoading(true);
    try {
      const data = await authApi.login({
        email: email.trim(),
        password,
      });

      const accessToken = typeof data.access_token === "string" ? data.access_token : "";
      const user = data.user;

      if (!accessToken || !user) {
        setError("Invalid response from server.");
        setLoading(false);
        return;
      }

      persistAuthSession(accessToken, user, rememberMe);
      const isNewUser = data.is_new_user === true;
      const showPremiumScreen = data.show_premium_screen === true;
      if (showPremiumScreen) {
        router.replace("/premium");
        return;
      }
      router.replace(isNewUser ? "/onboarding" : "/dashboard");
    } catch (submitError) {
      if (submitError instanceof AuthApiError) {
        const requiresOtp =
          submitError.status === 403 &&
          submitError.detail.toLowerCase().includes("email not verified");
        if (requiresOtp) {
          router.push(`/verify?email=${encodeURIComponent(email.trim())}`);
          return;
        }
      }
      setError(submitError instanceof Error ? submitError.message : "Login failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignin = () => {
    window.location.assign(authApi.getGoogleSigninUrl());
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-1.5">
        <label htmlFor="email" className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
          Email Address
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          placeholder="someone@example.com"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 text-sm text-[var(--foreground)] outline-none transition placeholder:text-[var(--muted)] focus:border-[var(--electric-blue)] focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_28%,transparent)]"
          required
        />
      </div>

      <div className="space-y-1.5">
        <div className="flex items-center justify-between">
          <label htmlFor="password" className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
            Password
          </label>
          <a href="#" className="text-xs text-[var(--muted)] hover:text-[var(--electric-blue)] hover:underline">
            Forgot Password?
          </a>
        </div>
        <div className="relative">
          <input
            id="password"
            name="password"
            type={showPassword ? "text" : "password"}
            autoComplete="current-password"
            placeholder="**********************"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            className="h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 pr-10 text-sm text-[var(--foreground)] outline-none transition placeholder:text-[var(--muted)] focus:border-[var(--electric-blue)] focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_28%,transparent)]"
            required
          />
          <button
            type="button"
            onClick={() => setShowPassword((prev) => !prev)}
            aria-label={showPassword ? "Hide password" : "Show password"}
            className="absolute right-2 top-1/2 inline-flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface-subtle)] text-[var(--muted)]"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
              <path d="M12 5c4.9 0 8.7 3 10 7-1.3 4-5.1 7-10 7S3.3 16 2 12c1.3-4 5.1-7 10-7Zm0 3.2a3.8 3.8 0 1 0 0 7.6 3.8 3.8 0 0 0 0-7.6Z" />
            </svg>
          </button>
        </div>
      </div>

      <label className="flex items-center gap-2 text-xs text-[var(--muted)]">
        <input
          type="checkbox"
          checked={rememberMe}
          onChange={(event) => setRememberMe(event.target.checked)}
          className="h-3.5 w-3.5 rounded border-[var(--border)] accent-[var(--electric-blue)]"
        />
        Remember me
      </label>

      {error ? <p className="text-xs text-red-500">{error}</p> : null}

      <button
        type="submit"
        disabled={loading}
        className="h-10 w-full rounded-md bg-[var(--electric-blue)] text-sm font-semibold text-white transition hover:brightness-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--insight-gold)] disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:brightness-100"
      >
        {loading ? "Signing in..." : "Sign in"}
      </button>

      <p className="text-center text-xs text-[var(--muted)]">
        Need to create a new account?{" "}
        <Link href="/signup" className="font-medium text-[var(--electric-blue)] hover:underline">
          Sign up
        </Link>
      </p>

      <div className="flex items-center gap-3 pt-0.5 text-[10px] uppercase tracking-[0.2em] text-[var(--muted)]">
        <span className="h-px flex-1 bg-[var(--border)]" />
        OR
        <span className="h-px flex-1 bg-[var(--border)]" />
      </div>

      <button
        type="button"
        onClick={handleGoogleSignin}
        disabled={loading}
        className="inline-flex h-10 w-full items-center justify-center gap-2 rounded-md border border-[var(--border)] bg-[var(--surface)] text-sm text-[var(--deep-navy)] transition hover:bg-[var(--surface-subtle)] disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:bg-[var(--surface)] dark:text-[var(--foreground)]"
      >
        <span
          className="inline-flex h-4 w-4 items-center justify-center rounded-full border border-[#d1d5db] bg-white text-[10px] font-bold text-[#4285F4]"
          aria-hidden="true"
        >
          G
        </span>
        {googleButtonLabel}
      </button>
    </form>
  );
}
