"use client";
import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type WearableListOut } from "@/lib/api";

function fmtDate(value: string | null | undefined) { return value ? value.slice(0, 16).replace("T", " ") : "-"; }
function shortId(value: string) { return value.length > 14 ? `${value.slice(0, 14)}...` : value; }

export default function WearablesPage() {
  const router = useRouter();
  const [data, setData] = useState<WearableListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [limit, setLimit] = useState(50);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    try { setData(await api.get<WearableListOut>(`/admin/wearables?limit=${limit}`, token)); }
    catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load wearables");
    } finally { setLoading(false); }
  }, [router, limit]);

  useEffect(() => { load(); }, [load]);
  const items = data?.items ?? [];
  const stale = items.filter(w => !w.latest_sync).length;
  const metrics = items.reduce((a, w) => a + w.metrics_count, 0);
  const types = new Set(items.map(w => w.wearable_type)).size;

  return (
    <>
      <TopBar title="Wearables" subtitle={data ? `${data.total.toLocaleString()} connected wearable profiles` : "Connected-device operations"} />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        {[
          { title: "Wearable orders", body: "Manage paid Vyla Wearable orders, dispatch, and tracking.", href: "/wearables/orders" },
          { title: "Inventory", body: "Update stock, checkout availability, price, and low-stock thresholds.", href: "/wearables/inventory" },
          { title: "Analytics", body: "Review wearable revenue, shipment status, and stock warnings.", href: "/wearables/analytics" },
        ].map(item => (
          <Link key={item.href} href={item.href} className="rounded-2xl border border-[#FFD9C2] bg-white p-5 hover:border-[#FF7A33]/60 transition-colors">
            <p className="text-[15px] font-semibold text-[#1E0C16]">{item.title}</p>
            <p className="text-[12px] text-[#A06A52] mt-1.5">{item.body}</p>
          </Link>
        ))}
      </div>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Connected users" value={String(data?.total ?? 0)} sub="Backend total" accent />
        <StatCard label="Metric records" value={metrics.toLocaleString()} sub="Current page" />
        <StatCard label="No sync yet" value={String(stale)} sub="Current page" />
        <StatCard label="Device types" value={String(types)} sub="Current page" />
      </div>
      <div className="flex gap-3 mb-5">
        <select value={limit} onChange={e => setLimit(Number(e.target.value))} className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] focus:outline-none">
          <option value={25}>25 users</option><option value={50}>50 users</option><option value={100}>100 users</option><option value={200}>200 users</option>
        </select>
      </div>
      <Table>
        <Thead><Th>User</Th><Th>User ID</Th><Th>Wearable</Th><Th>Latest sync</Th><Th>Metrics</Th><Th>Status</Th></Thead>
        <Tbody>{loading ? <LoadingRows cols={6} /> : items.length === 0 ? <EmptyState label="No connected wearables found" /> : items.map(w => (
          <Tr key={w.user_id}>
            <Td>{w.user_email ?? "-"}</Td><Td muted>{shortId(w.user_id)}</Td><Td><Badge label={w.wearable_type} /></Td>
            <Td muted>{fmtDate(w.latest_sync)}</Td><Td>{w.metrics_count.toLocaleString()}</Td><Td>{w.latest_sync ? <Badge label="syncing" /> : <Badge label="stale" />}</Td>
          </Tr>
        ))}</Tbody>
      </Table>
    </>
  );
}
