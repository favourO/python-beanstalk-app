"use client";

import { authApi } from "@/shared/api/auth";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { type FormEvent, useState } from "react";

export function SignupForm() {
  const router = useRouter();
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [accountType, setAccountType] = useState<"business" | "individual" | "">("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (submitting) return;
    setError("");

    if (!firstName.trim() || !lastName.trim()) {
      setError("Please enter first name and last name.");
      return;
    }
    if (!email.trim()) {
      setError("Please enter an email address.");
      return;
    }
    if (!accountType) {
      setError("Please select an account type.");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }

    setSubmitting(true);
    try {
      await authApi.signup({
        email: email.trim(),
        password,
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        country: "US",
        account_type: accountType,
      });

      router.push("/login");
    } catch (signupError) {
      setError(signupError instanceof Error ? signupError.message : "Signup failed.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form className="space-y-3.5" onSubmit={handleSubmit}>
      <Field label="First Name" htmlFor="firstName">
        <input
          id="firstName"
          name="firstName"
          type="text"
          placeholder="Enter your first name"
          value={firstName}
          onChange={(event) => setFirstName(event.target.value)}
          className="signup-input"
          required
        />
      </Field>

      <Field label="Last Name" htmlFor="lastName">
        <input
          id="lastName"
          name="lastName"
          type="text"
          placeholder="Enter your last name"
          value={lastName}
          onChange={(event) => setLastName(event.target.value)}
          className="signup-input"
          required
        />
      </Field>

      <Field label="Email Address" htmlFor="email">
        <input
          id="email"
          name="email"
          type="email"
          placeholder="someone@example.com"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="signup-input"
          required
        />
      </Field>

      <Field label="Account Type" htmlFor="accountType">
        <div className="relative">
          <select
            id="accountType"
            name="accountType"
            className="signup-input appearance-none pr-10"
            value={accountType}
            onChange={(event) => setAccountType(event.target.value as "business" | "individual" | "")}
          >
            <option value="" disabled>
              Business/Individual
            </option>
            <option value="business">Business</option>
            <option value="individual">Individual</option>
          </select>
          <span className="pointer-events-none absolute right-2 top-1/2 inline-flex h-6 w-6 -translate-y-1/2 items-center justify-center rounded bg-[color-mix(in_oklab,var(--charcoal)_8%,white)] text-[var(--muted)] dark:bg-[color-mix(in_oklab,var(--cool-gray)_12%,var(--charcoal))]">
            <svg viewBox="0 0 20 20" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
              <path d="m5 7 5 6 5-6" />
            </svg>
          </span>
        </div>
      </Field>

      <Field label="Password" htmlFor="password">
        <div className="rounded-md border border-dashed border-[var(--electric-blue)] p-0.5">
          <div className="relative">
            <input
              id="password"
              name="password"
              type={showPassword ? "text" : "password"}
              placeholder="**********************"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="signup-input pr-10 font-mono"
              required
            />
            <button
              type="button"
              onClick={() => setShowPassword((prev) => !prev)}
              aria-label={showPassword ? "Hide password" : "Show password"}
              className="absolute right-2 top-1/2 inline-flex h-6 w-6 -translate-y-1/2 items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface-subtle)] text-[var(--muted)]"
            >
              <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
                <path d="M12 5c4.9 0 8.7 3 10 7-1.3 4-5.1 7-10 7S3.3 16 2 12c1.3-4 5.1-7 10-7Zm0 3.2a3.8 3.8 0 1 0 0 7.6 3.8 3.8 0 0 0 0-7.6Z" />
              </svg>
            </button>
          </div>
        </div>
      </Field>

      {error ? <p className="text-xs text-red-500">{error}</p> : null}

      <button
        type="submit"
        disabled={submitting}
        className="mt-2 h-10 w-full rounded-md bg-[var(--electric-blue)] text-sm font-semibold text-white transition hover:brightness-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--insight-gold)]"
      >
        {submitting ? "Creating account..." : "Sign Up"}
      </button>

      <p className="pt-0.5 text-center text-xs text-[var(--muted)]">
        Already a User?{" "}
        <Link href="/login" className="font-medium text-[var(--electric-blue)] hover:underline">
          Sign In
        </Link>
      </p>
    </form>
  );
}

type FieldProps = {
  label: string;
  htmlFor: string;
  children: React.ReactNode;
};

function Field({ label, htmlFor, children }: FieldProps) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={htmlFor} className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
        {label}
      </label>
      {children}
    </div>
  );
}
