"use client";

import { AuthApiError, authApi, type OnboardingPayload } from "@/shared/api/auth";
import { getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { Container } from "@/shared/ui/container";
import { useRouter } from "next/navigation";
import { type FormEvent, useEffect, useMemo, useState } from "react";

const ROLE_OPTIONS = [
  "Founder / Executive",
  "Operations",
  "Data Analyst",
  "Product Manager",
  "Engineer",
  "Marketing",
  "Finance",
  "Other",
];

const INTENDED_USE_OPTIONS = [
  "Reporting and dashboarding",
  "Ad-hoc analysis",
  "Client deliverables",
  "Internal tooling",
  "Academic / research",
  "Other",
];

const BUSINESS_TYPES = [
  "SaaS",
  "Agency / Consultancy",
  "Marketplace",
  "E-commerce",
  "Media",
  "Manufacturing",
  "Government / Public",
  "Non-profit",
  "Other",
];

const INDIVIDUAL_PROFILES = [
  { value: "student", label: "Student" },
  { value: "data_scientist", label: "Data Scientist" },
  { value: "data_engineer", label: "Data Engineer" },
  { value: "hobbyist", label: "Hobbyist" },
  { value: "backend_engineer", label: "Backend Engineer" },
  { value: "devops", label: "DevOps / Infrastructure" },
  { value: "business_person", label: "Business / Operations" },
];

const INDUSTRY_TYPES = [
  "Technology",
  "Healthcare",
  "Finance",
  "Education",
  "Retail",
  "Energy",
  "Logistics",
  "Hospitality",
  "Other",
];

type OnboardingForm = {
  user_type: "" | "company" | "individual";
  company_name: string;
  role: string;
  intended_use: string;
  individual_profile: string;
  business_type: string;
  industry_type: string;
};

const DEFAULT_FORM: OnboardingForm = {
  user_type: "",
  company_name: "",
  role: "",
  intended_use: "",
  individual_profile: "",
  business_type: "",
  industry_type: "",
};

export function OnboardingScreen() {
  const router = useRouter();
  const [form, setForm] = useState<OnboardingForm>(DEFAULT_FORM);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
      return;
    }

    const token = getValidAccessToken();
    if (!token) {
      router.replace("/login");
      return;
    }

    let active = true;
    const load = async () => {
      try {
        const data = await authApi.getOnboarding(token);
        if (!active || !data || typeof data !== "object") return;
        const mapped: OnboardingForm = {
          user_type:
            data.user_type === "company" || data.user_type === "individual"
              ? data.user_type
              : "",
          company_name: String(data.company_name ?? ""),
          role: String(data.role ?? ""),
          intended_use: String(data.intended_use ?? ""),
          individual_profile: String(data.individual_profile ?? ""),
          business_type: String(data.business_type ?? ""),
          industry_type: String(data.industry_type ?? ""),
        };
        setForm(mapped);
      } catch (loadError) {
        if (loadError instanceof AuthApiError && loadError.status === 401) {
          router.replace("/login");
          return;
        }
      } finally {
        if (active) setLoading(false);
      }
    };

    void load();
    return () => {
      active = false;
    };
  }, [router]);

  const isSubmitDisabled = useMemo(() => {
    if (saving) return true;
    if (!form.user_type || !form.role || !form.intended_use || !form.industry_type) return true;
    if (form.user_type === "company") return !form.company_name || !form.business_type;
    return !form.individual_profile;
  }, [form, saving]);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (isSubmitDisabled) return;

    const token = getValidAccessToken();
    if (!token) {
      router.replace("/login");
      return;
    }

    setSaving(true);
    setError("");
    try {
      if (form.user_type !== "company" && form.user_type !== "individual") {
        setError("Please select account type.");
        setSaving(false);
        return;
      }

      const payload: OnboardingPayload = {
        user_type: form.user_type,
        role: form.role,
        intended_use: form.intended_use,
        industry_type: form.industry_type,
        ...(form.user_type === "company"
          ? {
              company_name: form.company_name,
              business_type: form.business_type,
            }
          : {
              individual_profile: form.individual_profile,
            }),
      };

      await authApi.saveOnboarding(token, payload);
      router.replace("/premium");
    } catch (submitError) {
      if (submitError instanceof AuthApiError) {
        setError(submitError.detail);
      } else {
        setError(submitError instanceof Error ? submitError.message : "Unable to save onboarding.");
      }
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <main className="relative min-h-screen overflow-hidden bg-[#f8faf8] text-[var(--charcoal)]">
        <Container className="relative z-10 flex min-h-screen items-center justify-center">
          <p className="text-sm text-[var(--muted)]">Preparing your onboarding experience...</p>
        </Container>
      </main>
    );
  }

  return (
    <main className="relative min-h-screen overflow-hidden bg-[#f8faf8] text-[var(--charcoal)]">
      <div className="absolute inset-0 bg-[linear-gradient(180deg,color-mix(in_oklab,var(--accent-teal)_30%,white)_0%,#f9fbfb_40%,color-mix(in_oklab,var(--insight-gold)_14%,white)_100%)]" />
      <Container className="relative z-10 flex min-h-screen items-center justify-center py-8 md:py-12">
        <section className="w-full max-w-[760px] rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-[0_28px_60px_-48px_rgba(11,19,43,0.75)] dark:border-[var(--border-strong)] dark:bg-[var(--charcoal)] md:p-6">
          <header className="mb-5">
            <h1 className="text-3xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
              Let&apos;s get to know you
            </h1>
            <p className="mt-1 text-sm text-[var(--muted)]">
              We&apos;ll use this information to tailor your workspace.
            </p>
          </header>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid gap-3 md:grid-cols-2">
              <button
                type="button"
                onClick={() =>
                  setForm((prev) => ({
                    ...prev,
                    user_type: "company",
                    individual_profile: "",
                  }))
                }
                className={`rounded-lg border px-4 py-3 text-left text-sm font-medium transition ${
                  form.user_type === "company"
                    ? "border-[var(--electric-blue)] bg-[color-mix(in_oklab,var(--electric-blue)_14%,white)] text-[var(--deep-navy)]"
                    : "border-[var(--border)] bg-[var(--surface)] text-[var(--muted)]"
                }`}
              >
                Company / Team
              </button>
              <button
                type="button"
                onClick={() =>
                  setForm((prev) => ({
                    ...prev,
                    user_type: "individual",
                    company_name: "",
                    business_type: "",
                  }))
                }
                className={`rounded-lg border px-4 py-3 text-left text-sm font-medium transition ${
                  form.user_type === "individual"
                    ? "border-[var(--electric-blue)] bg-[color-mix(in_oklab,var(--electric-blue)_14%,white)] text-[var(--deep-navy)]"
                    : "border-[var(--border)] bg-[var(--surface)] text-[var(--muted)]"
                }`}
              >
                Individual
              </button>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              {form.user_type === "company" ? (
                <>
                  <Field label="Company name">
                    <input
                      value={form.company_name}
                      onChange={(event) =>
                        setForm((prev) => ({ ...prev, company_name: event.target.value }))
                      }
                      placeholder="Acme Inc."
                      className="onboarding-input"
                    />
                  </Field>
                  <Field label="Business type">
                    <select
                      value={form.business_type}
                      onChange={(event) =>
                        setForm((prev) => ({ ...prev, business_type: event.target.value }))
                      }
                      className="onboarding-input"
                    >
                      <option value="">Select business type</option>
                      {BUSINESS_TYPES.map((item) => (
                        <option key={item} value={item}>
                          {item}
                        </option>
                      ))}
                    </select>
                  </Field>
                </>
              ) : null}

              {form.user_type === "individual" ? (
                <Field label="Profile" className="md:col-span-2">
                  <select
                    value={form.individual_profile}
                    onChange={(event) =>
                      setForm((prev) => ({ ...prev, individual_profile: event.target.value }))
                    }
                    className="onboarding-input"
                  >
                    <option value="">Select your profile</option>
                    {INDIVIDUAL_PROFILES.map((item) => (
                      <option key={item.value} value={item.value}>
                        {item.label}
                      </option>
                    ))}
                  </select>
                </Field>
              ) : null}

              <Field label="Your role" className="md:col-span-2">
                <select
                  value={form.role}
                  onChange={(event) => setForm((prev) => ({ ...prev, role: event.target.value }))}
                  className="onboarding-input"
                >
                  <option value="">Select your role</option>
                  {ROLE_OPTIONS.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </Field>

              <Field label="Primary use case">
                <select
                  value={form.intended_use}
                  onChange={(event) =>
                    setForm((prev) => ({ ...prev, intended_use: event.target.value }))
                  }
                  className="onboarding-input"
                >
                  <option value="">Select intended use</option>
                  {INTENDED_USE_OPTIONS.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </Field>

              <Field label="Industry">
                <select
                  value={form.industry_type}
                  onChange={(event) =>
                    setForm((prev) => ({ ...prev, industry_type: event.target.value }))
                  }
                  className="onboarding-input"
                >
                  <option value="">Select industry</option>
                  {INDUSTRY_TYPES.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                </select>
              </Field>
            </div>

            {error ? <p className="text-xs text-red-500">{error}</p> : null}

            <button
              type="submit"
              disabled={isSubmitDisabled}
              className="h-10 w-full rounded-md bg-[var(--electric-blue)] text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {saving ? "Saving..." : "Save & continue"}
            </button>
          </form>
        </section>
      </Container>
    </main>
  );
}

type FieldProps = {
  label: string;
  className?: string;
  children: React.ReactNode;
};

function Field({ label, className, children }: FieldProps) {
  return (
    <label className={`block space-y-1.5 ${className ?? ""}`}>
      <span className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
        {label}
      </span>
      {children}
    </label>
  );
}
