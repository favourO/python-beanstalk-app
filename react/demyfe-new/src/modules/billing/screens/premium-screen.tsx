"use client";

import { billingApi, type BillingMe, type BillingPlan } from "@/shared/api/billing";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { PLAN_SELECTED_KEY_PREFIX, PREMIUM_FIRST_VISIT_KEY } from "@/shared/billing/storage";
import { getStripe } from "@/shared/billing/stripe";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { BillingShell } from "../components/billing-shell";

const ensureRequiredBenefits = (list: unknown, required: string[]) => {
  const base = Array.isArray(list) ? list.map((item) => String(item)) : [];
  const normalized = base.map((item) => item.replace(/\s+/g, "").toLowerCase());
  required.forEach((item) => {
    const key = item.replace(/\s+/g, "").toLowerCase();
    if (!normalized.includes(key)) base.push(item);
  });
  return base;
};

const dismissPremiumScreen = async () => {
  const token = getValidAccessToken();
  if (!token) return;
  try {
    await billingApi.dismissPremiumScreen(token);
  } catch {
    // ignore non-fatal endpoint failure
  }
};

export function PremiumScreen() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [plans, setPlans] = useState<BillingPlan[]>([]);
  const [me, setMe] = useState<BillingMe | null>(null);
  const [checkoutPlan, setCheckoutPlan] = useState<"basic" | "premium" | null>(null);
  const [portalLoading, setPortalLoading] = useState(false);
  const [error, setError] = useState("");

  const returnTo = searchParams.get("return_to") || "/dashboard";
  const currentPlan = String(me?.plan ?? "free").toLowerCase();

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
      return;
    }

    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    let active = true;
    const load = async () => {
      try {
        const [plansRes, meRes] = await Promise.allSettled([
          billingApi.getPlans(token),
          billingApi.getMe(token),
        ]);

        if (!active) return;
        if (plansRes.status === "fulfilled") setPlans(plansRes.value);
        if (meRes.status === "fulfilled") {
          setMe(meRes.value);
          try {
            const existing = JSON.parse(window.localStorage.getItem("user") || "{}") as Record<string, unknown>;
            window.localStorage.setItem("user", JSON.stringify({ ...existing, ...meRes.value }));
          } catch {
            // ignore malformed cached user
          }
        }
      } catch {
        // no-op
      }
    };
    void load();

    try {
      if (!window.localStorage.getItem(PREMIUM_FIRST_VISIT_KEY)) {
        window.localStorage.setItem(PREMIUM_FIRST_VISIT_KEY, "true");
      }
    } catch {
      // ignore storage failures
    }

    return () => {
      active = false;
    };
  }, [router]);

  const markPlanSelectionComplete = useCallback(
    async (destination: string) => {
      try {
        const identifier = String(me?.user_id ?? me?.id ?? me?.email ?? "");
        window.localStorage.setItem(PREMIUM_FIRST_VISIT_KEY, "complete");
        if (identifier) {
          window.localStorage.setItem(`${PLAN_SELECTED_KEY_PREFIX}${identifier}`, "true");
        }
      } catch {
        // ignore storage failures
      }
      await dismissPremiumScreen();
      router.replace(destination || returnTo);
    },
    [me?.email, me?.id, me?.user_id, returnTo, router],
  );

  const planFree = {
    name: "Free",
    price: "£0/mo",
    features: ["5 uploads total", "Up to 50 MB total", "20 queries total", "No collaboration features"],
  };

  const planBasic = plans.find((plan) => String(plan.name).toLowerCase() === "basic") || {
    name: "Basic",
    price: "£9.99/mo",
    features: ["Up to 2GB of data", "500 uploads", "5000 queries"],
  };

  const planPremium = plans.find((plan) => String(plan.name).toLowerCase() === "premium") || {
    name: "Premium",
    price: "£25/mo",
    features: ["Up to 20GB of data", "5000 uploads", "50000 queries"],
  };

  const basicFeatures = useMemo(
    () =>
      ensureRequiredBenefits(planBasic.features, [
        "Up to 2GB of data",
        "500 uploads",
        "5000 queries",
        "Up to 5 Collaborator",
      ]),
    [planBasic.features],
  );
  const premiumFeatures = useMemo(
    () =>
      ensureRequiredBenefits(planPremium.features, [
        "Up to 20GB of data",
        "5000 uploads",
        "50000 queries",
        "Up to 10 Collaborator",
      ]),
    [planPremium.features],
  );

  const isProcessing = Boolean(checkoutPlan);

  const startCheckout = async (plan: "basic" | "premium") => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    setCheckoutPlan(plan);
    setError("");
    await dismissPremiumScreen();
    try {
      const origin = window.location.origin;
      const suffix = returnTo ? `?return_to=${encodeURIComponent(returnTo)}` : "";
      const success_url = `${origin}/billing/success${suffix}`;
      const cancel_url = `${origin}/billing/cancel${suffix}`;
      const response = await billingApi.createCheckout(token, { plan, success_url, cancel_url });
      const sessionId = response.session_id;
      if (!sessionId) throw new Error("No Stripe session id returned.");
      const stripe = await getStripe();
      if (!stripe) throw new Error("Stripe failed to initialize.");
      const { error: stripeError } = await stripe.redirectToCheckout({ sessionId });
      if (stripeError?.message) setError(stripeError.message);
    } catch (checkoutError) {
      setError(checkoutError instanceof Error ? checkoutError.message : "Checkout failed");
    } finally {
      setCheckoutPlan(null);
    }
  };

  const openCustomerPortal = async () => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }
    setPortalLoading(true);
    setError("");
    try {
      const response = await billingApi.openCustomerPortal(token, {
        return_url: window.location.href,
      });
      if (!response.url) throw new Error("No billing portal URL returned.");
      window.location.assign(response.url);
    } catch (portalError) {
      setError(portalError instanceof Error ? portalError.message : "Failed to open customer portal");
    } finally {
      setPortalLoading(false);
    }
  };

  return (
    <BillingShell drawerOpen={drawerOpen} setDrawerOpen={setDrawerOpen}>
      <div className="space-y-6 pt-1">
        <div className="text-center">
          <h1 className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)] md:text-3xl">
            Upgrade
          </h1>
          <p className="mt-2 text-sm text-[var(--muted)]">
            Choose a plan that fits your workload. You can manage or cancel anytime.
          </p>
          {error ? (
            <div className="mx-auto mt-3 max-w-xl rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </div>
          ) : null}
          {me ? (
            <div className="mx-auto mt-3 max-w-xl rounded-md border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-blue-800">
              Current plan: <span className="font-medium uppercase">{currentPlan}</span>
              {me.status ? ` • ${String(me.status)}` : ""}
            </div>
          ) : null}
        </div>

        <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
          <PlanCard name={planFree.name} price="£0/mo" features={planFree.features}>
            <button
              type="button"
              onClick={() => void markPlanSelectionComplete("/dashboard")}
              className="mt-8 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-100"
            >
              Continue Free
            </button>
          </PlanCard>

          <PlanCard name="Basic" price={String(planBasic.price ?? "£9.99/mo")} features={basicFeatures}>
            <button
              type="button"
              onClick={() => void startCheckout("basic")}
              disabled={isProcessing}
              className="mt-8 w-full rounded-xl bg-[var(--electric-blue)] px-4 py-2.5 text-sm font-semibold text-white hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {checkoutPlan === "basic" ? "Processing..." : "Upgrade to Basic"}
            </button>
          </PlanCard>

          <PlanCard
            name="Premium"
            price={String(planPremium.price ?? "£25/mo")}
            features={premiumFeatures}
            featured
          >
            <div className="mt-8 flex flex-col gap-3">
              <button
                type="button"
                onClick={() => void startCheckout("premium")}
                disabled={isProcessing}
                className="w-full rounded-xl bg-[var(--electric-blue)] px-4 py-2.5 text-sm font-semibold text-white hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {checkoutPlan === "premium" ? "Processing..." : "Upgrade to Premium"}
              </button>
              {currentPlan !== "free" ? (
                <button
                  type="button"
                  onClick={() => void openCustomerPortal()}
                  disabled={portalLoading}
                  className="w-full rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {portalLoading ? "Opening..." : "Manage subscription"}
                </button>
              ) : null}
            </div>
          </PlanCard>
        </div>
      </div>
    </BillingShell>
  );
}

function PlanCard({
  name,
  price,
  features,
  children,
  featured = false,
}: {
  name: string;
  price: string;
  features: string[];
  children: React.ReactNode;
  featured?: boolean;
}) {
  return (
    <div
      className={`relative flex h-full flex-col rounded-3xl border bg-white/95 px-6 py-8 shadow-sm ${
        featured ? "border-[var(--electric-blue)]" : "border-slate-200/80"
      }`}
    >
      {featured ? (
        <div className="absolute -top-3 right-6 rounded-full bg-[var(--electric-blue)] px-3 py-1 text-xs font-semibold text-white">
          Most popular
        </div>
      ) : null}
      <div>
        <h3 className="text-lg font-semibold text-slate-900">{name}</h3>
        <p className="mt-2 text-3xl font-semibold text-slate-900">{price.replace("/month", "/mo")}</p>
        <ul className="mt-5 space-y-2.5">
          {features.map((feature) => (
            <li key={`${name}-${feature}`} className="text-sm text-slate-600">
              • {feature}
            </li>
          ))}
        </ul>
      </div>
      {children}
    </div>
  );
}
