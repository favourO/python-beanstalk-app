"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import StatCard from "@/components/StatCard";
import { ErrorBanner } from "@/components/PageShell";
import { ApiError, getToken, wearableAdminApi, type WearableAnalyticsOut } from "@/lib/api";
import ShipmentStatusBadge from "@/components/wearable/ShipmentStatusBadge";
import { formatMoneyMinor, labelStatus } from "@/components/wearable/status";

export default function WearableAnalyticsPage() {
  const router = useRouter();
  const [data, setData] = useState<WearableAnalyticsOut | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    try {
      setData(await wearableAdminApi.getAnalytics(token));
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load wearable analytics");
    } finally {
      setLoading(false);
    }
  }, [router]);

  useEffect(() => { load(); }, [load]);

  return (
    <>
      <TopBar title="Wearable analytics" subtitle="Commerce, shipment, and inventory metrics" />
      {error && <ErrorBanner message={error} />}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Orders" value={loading ? "…" : String(data?.total_orders ?? 0)} sub="All time" accent />
        <StatCard label="Paid orders" value={loading ? "…" : String(data?.paid_orders ?? 0)} sub="Payment confirmed" />
        <StatCard label="Revenue" value={loading ? "…" : formatMoneyMinor(data?.revenue_minor ?? 0, data?.currency ?? "GBP")} sub="Wearable sales" />
        <StatCard label="Low stock" value={loading ? "…" : String(data?.low_stock_items ?? 0)} sub="Active inventory" />
      </div>

      <div className="flex gap-3 mb-5">
        <Link href="/wearables/orders" className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#A06A52] hover:text-[#FF7A33]">View orders</Link>
        <Link href="/wearables/inventory" className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#A06A52] hover:text-[#FF7A33]">Manage inventory</Link>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <section className="rounded-2xl border border-[#FFD9C2] bg-white p-5">
          <h2 className="text-lg font-semibold text-[#1E0C16] mb-4">Fulfillment breakdown</h2>
          <div className="space-y-3">
            {Object.entries(data?.fulfillment_counts ?? {}).length === 0 ? (
              <p className="text-sm text-[#A06A52]">No fulfillment data yet.</p>
            ) : Object.entries(data?.fulfillment_counts ?? {}).map(([status, count]) => (
              <div key={status} className="flex items-center justify-between border-b border-[#FFD9C2]/60 pb-3 last:border-0">
                <ShipmentStatusBadge status={status} />
                <span className="text-sm font-semibold text-[#1E0C16]">{count}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-2xl border border-[#FFD9C2] bg-white p-5">
          <h2 className="text-lg font-semibold text-[#1E0C16] mb-4">Payment breakdown</h2>
          <div className="space-y-3">
            {Object.entries(data?.payment_counts ?? {}).length === 0 ? (
              <p className="text-sm text-[#A06A52]">No payment data yet.</p>
            ) : Object.entries(data?.payment_counts ?? {}).map(([status, count]) => (
              <div key={status} className="flex items-center justify-between border-b border-[#FFD9C2]/60 pb-3 last:border-0">
                <span className="inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-medium border bg-gray-50 text-gray-600 border-gray-200">
                  {labelStatus(status)}
                </span>
                <span className="text-sm font-semibold text-[#1E0C16]">{count}</span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </>
  );
}
