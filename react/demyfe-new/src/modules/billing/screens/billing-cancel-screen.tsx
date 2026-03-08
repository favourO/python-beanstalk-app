"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { BillingShell } from "../components/billing-shell";

export function BillingCancelScreen() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const returnTo = searchParams.get("return_to") || "/dashboard";

  return (
    <BillingShell drawerOpen={drawerOpen} setDrawerOpen={setDrawerOpen}>
      <div className="mx-auto max-w-xl rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-yellow-800">
        <div className="text-lg font-semibold">Checkout canceled</div>
        <p className="mt-1 text-sm">No charges were made. You can try again anytime.</p>
        <div className="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => router.replace(`/premium?return_to=${encodeURIComponent(returnTo)}`)}
            className="inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white hover:brightness-95"
          >
            Back to plans
          </button>
          <button
            type="button"
            onClick={() => router.replace(returnTo)}
            className="inline-flex items-center gap-2 rounded-lg border border-[var(--border-strong)] px-4 py-2 text-sm font-medium text-[var(--electric-blue)] hover:bg-[color-mix(in_oklab,var(--electric-blue)_8%,white)]"
          >
            Return to app
          </button>
        </div>
      </div>
    </BillingShell>
  );
}
