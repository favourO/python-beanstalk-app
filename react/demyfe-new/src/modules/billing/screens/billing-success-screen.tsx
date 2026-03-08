"use client";

import { billingApi } from "@/shared/api/billing";
import { getValidAccessToken } from "@/shared/auth/session";
import { PLAN_SELECTED_KEY_PREFIX, PREMIUM_FIRST_VISIT_KEY } from "@/shared/billing/storage";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { BillingShell } from "../components/billing-shell";

const dismissPremiumScreen = async () => {
  const token = getValidAccessToken();
  if (!token) return;
  try {
    await billingApi.dismissPremiumScreen(token);
  } catch {
    // ignore
  }
};

export function BillingSuccessScreen() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const returnTo = searchParams.get("return_to") || "/dashboard";

  useEffect(() => {
    const run = async () => {
      try {
        const token = getValidAccessToken();
        if (token) {
          const me = await billingApi.getMe(token);
          try {
            const existing = JSON.parse(window.localStorage.getItem("user") || "{}") as Record<string, unknown>;
            window.localStorage.setItem("user", JSON.stringify({ ...existing, ...me }));
          } catch {
            // ignore local sync errors
          }
        }
      } catch {
        // non-fatal
      }

      try {
        const existing = JSON.parse(window.localStorage.getItem("user") || "{}") as Record<string, unknown>;
        const identifier = String(existing.id ?? existing.user_id ?? existing.email ?? "");
        window.localStorage.setItem(PREMIUM_FIRST_VISIT_KEY, "complete");
        if (identifier) {
          window.localStorage.setItem(`${PLAN_SELECTED_KEY_PREFIX}${identifier}`, "true");
        }
      } catch {
        // ignore storage errors
      }

      await dismissPremiumScreen();
      setTimeout(() => {
        router.replace(returnTo);
      }, 800);
    };
    void run();
  }, [returnTo, router]);

  return (
    <BillingShell drawerOpen={drawerOpen} setDrawerOpen={setDrawerOpen}>
      <div className="mx-auto max-w-xl rounded-lg border border-green-200 bg-green-50 p-4 text-green-800">
        <div className="text-lg font-semibold">Payment successful</div>
        <p className="mt-1 text-sm">Your subscription is active. Redirecting to your dashboard...</p>
      </div>
    </BillingShell>
  );
}
