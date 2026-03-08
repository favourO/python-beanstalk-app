"use client";

import { billingApi, type BillingMe, type BillingPlan } from "@/shared/api/billing";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { getStripe } from "@/shared/billing/stripe";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { BillingShell } from "../components/billing-shell";

const formatBytes = (bytes: unknown): string => {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.floor(Math.log(value) / Math.log(k));
  return `${(value / Math.pow(k, index)).toFixed(index === 0 ? 0 : 1)} ${sizes[index]}`;
};

const clamp = (n: number, min: number, max: number) => Math.max(min, Math.min(max, n));
const formatDateLong = (value: unknown): string => {
  if (typeof value !== "string") return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
};

type PlanMeta = Record<"free" | "basic" | "premium", { name: string; price: string; features: string[] }>;

const PLAN_THEMES: Record<
  "free" | "basic" | "premium",
  { accentBg: string; accentText: string; border: string; chip: string }
> = {
  free: {
    accentBg: "bg-slate-100",
    accentText: "text-slate-600",
    border: "border-slate-200",
    chip: "bg-slate-100 text-slate-700",
  },
  basic: {
    accentBg: "bg-indigo-50",
    accentText: "text-indigo-600",
    border: "border-indigo-100",
    chip: "bg-indigo-50 text-indigo-600",
  },
  premium: {
    accentBg: "bg-purple-50",
    accentText: "text-purple-600",
    border: "border-purple-100",
    chip: "bg-purple-50 text-purple-600",
  },
};

export function ManageSubscriptionScreen() {
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [plans, setPlans] = useState<BillingPlan[]>([]);
  const [me, setMe] = useState<BillingMe | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [cancelResult, setCancelResult] = useState<Record<string, unknown> | null>(null);

  const currentPlan = String(me?.plan ?? "free").toLowerCase();

  const load = useCallback(async () => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }
    setLoading(true);
    setError("");
    try {
      const [plansRes, meRes] = await Promise.all([
        billingApi.getPlans(token).catch(() => [] as BillingPlan[]),
        billingApi.getMe(token),
      ]);
      setPlans(Array.isArray(plansRes) ? plansRes : []);
      setMe(meRes);
      try {
        const existing = JSON.parse(window.localStorage.getItem("user") || "{}") as Record<string, unknown>;
        window.localStorage.setItem("user", JSON.stringify({ ...existing, ...meRes }));
      } catch {
        // ignore malformed local state
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Failed to load subscription.");
    } finally {
      setLoading(false);
    }
  }, [router]);

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
      return;
    }
    void load();
  }, [load, router]);

  const planMeta = useMemo<PlanMeta>(() => {
    const byName: Record<string, BillingPlan> = {};
    plans.forEach((plan) => {
      const key = String(plan.name ?? "").toLowerCase();
      if (key) byName[key] = plan;
    });
    return {
      free: {
        name: "free",
        price: String(byName.free?.price ?? "£0/mo"),
        features: Array.isArray(byName.free?.features)
          ? (byName.free?.features as string[])
          : ["5 uploads total", "Up to 50 MB total", "20 queries total"],
      },
      basic: {
        name: "basic",
        price: String(byName.basic?.price ?? "£9.99/mo"),
        features: Array.isArray(byName.basic?.features)
          ? (byName.basic?.features as string[])
          : ["Up to 2 GB of data", "500 uploads included", "5,000 queries each month"],
      },
      premium: {
        name: "premium",
        price: String(byName.premium?.price ?? "£25/mo"),
        features: Array.isArray(byName.premium?.features)
          ? (byName.premium?.features as string[])
          : ["Up to 20 GB of data", "5,000 uploads included", "50,000 queries each month"],
      },
    };
  }, [plans]);

  const currentPath = typeof window !== "undefined" ? `${window.location.pathname}${window.location.search || ""}` : "";
  const suffix = currentPath ? `?return_to=${encodeURIComponent(currentPath)}` : "";
  const successUrl = typeof window !== "undefined" ? `${window.location.origin}/billing/success${suffix}` : undefined;
  const cancelUrl = typeof window !== "undefined" ? `${window.location.origin}/billing/cancel${suffix}` : undefined;

  const startCheckout = async (plan: "basic" | "premium") => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const res = await billingApi.createCheckout(token, {
        plan,
        success_url: successUrl,
        cancel_url: cancelUrl,
      });
      const sessionId = res.session_id;
      if (!sessionId) throw new Error("No session id");
      const stripe = await getStripe();
      if (!stripe) throw new Error("Stripe failed to initialize.");
      const result = await stripe.redirectToCheckout({ sessionId });
      if (result.error?.message) setError(result.error.message);
    } catch (checkoutError) {
      setError(checkoutError instanceof Error ? checkoutError.message : "Checkout failed");
    } finally {
      setBusy(false);
    }
  };

  const cancelSubscription = async () => {
    const confirmation = window.prompt('Type "cancel" to confirm immediate cancellation of your subscription.');
    if ((confirmation || "").trim().toLowerCase() !== "cancel") {
      setError('Cancellation not confirmed. Type "cancel" to proceed.');
      return;
    }
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }
    setBusy(true);
    setError("");
    setCancelResult(null);
    try {
      const response = await billingApi.cancelSubscription(token, { at_period_end: false });
      setCancelResult(response);
      await load();
    } catch (cancelError) {
      setError(cancelError instanceof Error ? cancelError.message : "Cancellation failed");
    } finally {
      setBusy(false);
    }
  };

  const usageQueriesUsed = Number(
    (me?.usage as Record<string, unknown> | undefined)?.queries_used ??
      (me?.usage as Record<string, unknown> | undefined)?.queries_month ??
      0,
  );
  const usageQueriesLimit = Number(
    (me?.limits as Record<string, unknown> | undefined)?.queries_limit ??
      (me?.limits as Record<string, unknown> | undefined)?.queries_month ??
      0,
  );
  const usageUploadsUsed = Number((me?.usage as Record<string, unknown> | undefined)?.uploads_count ?? 0);
  const usageUploadsLimit = Number((me?.limits as Record<string, unknown> | undefined)?.uploads_count ?? 0);
  const usageBytesUsed = Number(
    (me?.usage as Record<string, unknown> | undefined)?.upload_bytes_used ??
      (me?.usage as Record<string, unknown> | undefined)?.upload_bytes_month ??
      0,
  );
  const usageBytesLimit = Number(
    (me?.limits as Record<string, unknown> | undefined)?.upload_bytes_limit ??
      (me?.limits as Record<string, unknown> | undefined)?.upload_bytes_month ??
      0,
  );
  const nextRenewal =
    (me?.period_end as string | undefined)
      ? formatDateLong(me?.period_end)
      : (me?.current_period_end as string | undefined)
        ? formatDateLong(me?.current_period_end)
        : "";
  const currentPlanMeta = planMeta[(currentPlan as keyof PlanMeta) || "free"] || planMeta.free;
  const planTheme = PLAN_THEMES[(currentPlan as "free" | "basic" | "premium") || "free"] || PLAN_THEMES.basic;
  const resetAt = formatDateLong(
    (me?.usage as Record<string, unknown> | undefined)?.queries_reset_at ?? "",
  );

  return (
    <BillingShell drawerOpen={drawerOpen} setDrawerOpen={setDrawerOpen}>
      <div className="space-y-6 pt-1">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)] md:text-3xl">
              Manage Subscription
            </h1>
            <p className="mt-1 text-sm text-[var(--muted)]">
              View your current plan, usage, upgrade, or cancel your subscription.
            </p>
          </div>
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading}
            className="rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-medium text-[var(--muted)] hover:bg-[var(--surface-subtle)] disabled:opacity-60"
          >
            {loading ? "Refreshing..." : "Refresh"}
          </button>
        </div>

        {error ? (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>
        ) : null}

        <div className={`rounded-2xl border ${planTheme.border} bg-[var(--surface)] p-6 shadow-sm`}>
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="space-y-2">
              <PlanBadge name={currentPlan} tone={currentPlan as "free" | "basic" | "premium"} />
              {(me?.status as string | undefined) ? (
                <span className="ml-2 rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-emerald-700">
                  {String(me?.status)}
                </span>
              ) : null}
              <div className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                {planMeta[currentPlan as keyof PlanMeta]?.price ?? "£0/mo"}
              </div>
              <div className="text-sm text-[var(--muted)]">
                {nextRenewal ? (
                  <>
                    Next renewal <span className="font-medium">{nextRenewal}</span>
                  </>
                ) : (
                  <>No renewal date for free plan</>
                )}
              </div>
              <div className={`rounded-xl ${planTheme.accentBg} px-4 py-3`}>
                <p className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">
                  Plan includes
                </p>
                <ul className="mt-2 grid gap-1.5 text-sm text-slate-700 sm:grid-cols-2">
                  {(currentPlanMeta.features || []).map((feature) => (
                    <li key={`included-${feature}`} className="flex items-start gap-2">
                      <span className={`mt-[2px] ${planTheme.accentText}`}>•</span>
                      <span>{feature}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <ul className="space-y-1 text-sm text-[var(--muted)]">
                {(planMeta[currentPlan as keyof PlanMeta]?.features ?? planMeta.free.features).map((feature) => (
                  <li key={`current-feature-${feature}`}>• {feature}</li>
                ))}
              </ul>
            </div>

            <div className="flex flex-col gap-2 sm:flex-row">
              {currentPlan !== "premium" ? (
                <button
                  type="button"
                  onClick={() => void startCheckout("premium")}
                  disabled={busy}
                  className="rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white hover:brightness-95 disabled:opacity-60"
                >
                  Upgrade to Premium
                </button>
              ) : null}
              {currentPlan === "free" ? (
                <button
                  type="button"
                  onClick={() => void startCheckout("basic")}
                  disabled={busy}
                  className="rounded-lg border border-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-[var(--electric-blue)] hover:bg-[color-mix(in_oklab,var(--electric-blue)_8%,white)] disabled:opacity-60"
                >
                  Upgrade to Basic
                </button>
              ) : (
                <button
                  type="button"
                  onClick={() => void cancelSubscription()}
                  disabled={busy}
                  className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-60"
                >
                  {busy ? "Cancelling..." : "Cancel now"}
                </button>
              )}
            </div>
          </div>

          {cancelResult ? (
            <div className="mt-4 rounded-md bg-[var(--surface-subtle)] px-3 py-2 text-sm text-[var(--muted)]">
              {String(cancelResult.status ?? "") === "scheduled_cancellation"
                ? `Cancellation scheduled for ${String(cancelResult.cancel_at ?? "")}.`
                : String(cancelResult.status ?? "") === "canceled"
                  ? "Subscription cancelled. You are now on Free plan."
                  : "No active subscription to cancel."}
            </div>
          ) : null}
        </div>

        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          <UsageCard
            title="Query Usage"
            label="Engine queries (this period)"
            used={usageQueriesUsed}
            limit={usageQueriesLimit}
          />
          <div className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-sm">
            <h3 className="mb-3 text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
              Uploads & Storage
            </h3>
            <ProgressBar label="Uploads (count)" used={usageUploadsUsed} limit={usageUploadsLimit} />
            <div className="mt-3" />
            <ProgressBar
              label="Data uploaded (this period)"
              used={usageBytesUsed}
              limit={usageBytesLimit}
              formatter={formatBytes}
            />
          </div>
        </div>
        {resetAt ? (
          <div className="text-xs text-[var(--muted)]">Query usage resets on {resetAt}</div>
        ) : null}

        <div className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">Plans</h3>
            <span className="text-xs text-[var(--muted)]">Change or cancel anytime.</span>
          </div>
          <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
            {(["free", "basic", "premium"] as const).map((plan) => {
              const meta = planMeta[plan];
              const isCurrent = currentPlan === plan;
              const isPaid = plan !== "free";
              return (
                <div
                  key={plan}
                  className={`rounded-2xl border bg-white p-5 shadow-sm ${isCurrent ? "border-[var(--electric-blue)] ring-2 ring-[color-mix(in_oklab,var(--electric-blue)_22%,transparent)]" : "border-slate-200"}`}
                >
                  <div className="flex items-center justify-between">
                    <div className="text-lg font-semibold capitalize text-slate-900">{plan}</div>
                    {isCurrent ? (
                      <span className="rounded-full bg-[color-mix(in_oklab,var(--electric-blue)_12%,white)] px-2 py-0.5 text-[11px] font-semibold uppercase text-[var(--electric-blue)]">
                        Current
                      </span>
                    ) : null}
                  </div>
                  <div className="mt-2 text-2xl font-semibold text-slate-900">{meta.price}</div>
                  <ul className="mt-4 space-y-1.5 text-sm text-slate-700">
                    {meta.features.map((feature) => (
                      <li key={`${plan}-${feature}`}>• {feature}</li>
                    ))}
                  </ul>
                  <div className="mt-4">
                    {!isPaid ? (
                      <button disabled className="w-full rounded-lg border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-medium text-slate-500">
                        Included
                      </button>
                    ) : isCurrent ? (
                      <button
                        type="button"
                        onClick={() => void cancelSubscription()}
                        disabled={busy}
                        className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-60"
                      >
                        {busy ? "Cancelling..." : "Cancel now"}
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={() => void startCheckout(plan)}
                        disabled={busy}
                        className="w-full rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white hover:brightness-95 disabled:opacity-60"
                      >
                        Choose {plan.charAt(0).toUpperCase() + plan.slice(1)}
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </BillingShell>
  );
}

function PlanBadge({
  name,
  tone = "basic",
}: {
  name: string;
  tone?: "free" | "basic" | "premium";
}) {
  const theme = PLAN_THEMES[tone] || PLAN_THEMES.basic;
  return (
    <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide ${theme.chip}`}>
      {name}
    </span>
  );
}

function ProgressBar({
  label,
  used,
  limit,
  formatter = (value: number) => value.toLocaleString(),
}: {
  label: string;
  used: number;
  limit: number;
  formatter?: (value: number) => string;
}) {
  if (!Number.isFinite(limit) || limit <= 0) {
    return (
      <div className="text-sm text-[var(--muted)]">
        {label}: <span className="font-medium">Unlimited</span>
      </div>
    );
  }
  const pct = clamp(Math.round((100 * (used || 0)) / limit), 0, 100);
  return (
    <div>
      <div className="flex items-center justify-between text-xs text-[var(--muted)]">
        <span>{label}</span>
        <span className="font-medium">
          {formatter(used || 0)} / {formatter(limit)} ({pct}%)
        </span>
      </div>
      <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-[color-mix(in_oklab,var(--charcoal)_12%,white)]">
        <div
          className={`${pct >= 90 ? "bg-red-500" : pct >= 70 ? "bg-amber-500" : "bg-[var(--electric-blue)]"} h-2 rounded-full`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

function UsageCard({
  title,
  label,
  used,
  limit,
}: {
  title: string;
  label: string;
  used: number;
  limit: number;
}) {
  return (
    <div className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-sm">
      <h3 className="mb-3 text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">{title}</h3>
      <ProgressBar label={label} used={used} limit={limit} />
    </div>
  );
}
