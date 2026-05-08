"use client";
import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { api, getToken, ApiError, type SubListOut } from "@/lib/api";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";

export default function SubscriptionsPage() {
  const router = useRouter();
  const [data, setData] = useState<SubListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [tierFilter, setTierFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [providerFilter, setProviderFilter] = useState("");
  const [page, setPage] = useState(1);
  const [grantUserId, setGrantUserId] = useState("");
  const [grantMsg, setGrantMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "25" });
    if (tierFilter) params.set("tier", tierFilter);
    if (statusFilter) params.set("status", statusFilter);
    if (providerFilter) params.set("provider", providerFilter);
    try {
      setData(await api.get<SubListOut>(`/admin/subscriptions?${params}`, token));
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, [router, page, tierFilter, statusFilter, providerFilter]);

  useEffect(() => { load(); }, [load]);

  async function grantPremium(e: React.FormEvent) {
    e.preventDefault();
    const token = getToken();
    if (!token || !grantUserId) return;
    try {
      await api.post(`/admin/subscriptions/${grantUserId}/grant-premium`, token, { days: 30, reason: "admin_manual_grant" });
      setGrantMsg(`Premium granted to ${grantUserId}`);
      setGrantUserId("");
      load();
    } catch (err) {
      setGrantMsg(err instanceof Error ? err.message : "Grant failed");
    }
  }

  const items = data?.items ?? [];
  const premium = items.filter(s => s.tier !== "free" && s.status === "active").length;
  const stripeCount = items.filter(s => s.provider === "stripe" || s.provider === "Stripe").length;
  const flwCount = items.filter(s => s.provider === "flutterwave" || s.provider === "Flutterwave").length;
  const mrr = items.filter(s => s.status === "active" && s.amount && s.amount > 0)
    .reduce((acc, s) => acc + (s.billing_interval === "annual" ? (s.amount ?? 0) / 12 : (s.amount ?? 0)), 0);

  return (
    <>
      <TopBar title="Subscriptions" subtitle={data ? `${data.total.toLocaleString()} records` : "Loading…"} />
      {error && <ErrorBanner message={error} />}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Active Premium"  value={String(premium)}              sub="Current page" accent />
        <StatCard label="Est. MRR (page)" value={`£${mrr.toFixed(2)}`}        sub="Active only" />
        <StatCard label="Stripe"          value={String(stripeCount)}          sub="On this page" />
        <StatCard label="Flutterwave"     value={String(flwCount)}             sub="On this page" />
      </div>

      {/* Grant premium */}
      <form onSubmit={grantPremium} className="bg-white border border-[#FFD9C2] rounded-2xl p-5 mb-6 flex flex-wrap gap-3 items-end">
        <div>
          <p className="text-xs font-medium text-[#A06A52] mb-1.5">Grant 30-day premium</p>
          <input
            value={grantUserId}
            onChange={e => setGrantUserId(e.target.value)}
            placeholder="User ID…"
            className="border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16] focus:outline-none focus:border-[#FF7A33]/60 w-64"
          />
        </div>
        <button type="submit" className="bg-[#FF7A33] text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-[#e86a22]">
          Grant Premium
        </button>
        {grantMsg && <span className="text-sm text-emerald-600 self-center">{grantMsg}</span>}
      </form>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-5">
        {[
          { label: "All tiers", val: "", setter: setTierFilter, options: [["All tiers",""],["premium_plus","premium_plus"],["free","free"]] },
          { label: "All statuses", val: "", setter: setStatusFilter, options: [["All statuses",""],["active","active"],["trialing","trialing"],["canceled","canceled"],["past_due","past_due"]] },
          { label: "All providers", val: "", setter: setProviderFilter, options: [["All providers",""],["stripe","stripe"],["flutterwave","flutterwave"]] },
        ].map(({ options, setter }) => (
          <select key={options[0][0]} onChange={e => { setter(e.target.value); setPage(1); }}
            className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] focus:outline-none">
            {options.map(([label, value]) => <option key={value} value={value}>{label}</option>)}
          </select>
        ))}
      </div>

      <Table>
        <Thead>
          <Th>Sub ID</Th><Th>User</Th><Th>Tier</Th><Th>Status</Th>
          <Th>Provider</Th><Th>Interval</Th><Th>Amount</Th><Th>Period end</Th><Th>Created</Th>
        </Thead>
        <Tbody>
          {loading ? <LoadingRows cols={9} /> :
           items.length === 0 ? <EmptyState label="No subscriptions found" /> :
           items.map(s => (
            <Tr key={s.id}>
              <Td muted>{s.id.slice(0, 14)}…</Td>
              <Td>{s.user_email ?? s.user_id.slice(0, 12)}</Td>
              <Td><Badge label={s.tier} /></Td>
              <Td><Badge label={s.status} /></Td>
              <Td>{s.provider ? <Badge label={s.provider} /> : <span className="text-[#A06A52] text-[12px]">—</span>}</Td>
              <Td muted>{s.billing_interval ?? "—"}</Td>
              <Td>{s.amount && s.amount > 0 ? `${s.currency} ${s.amount.toFixed(2)}` : <span className="text-[#A06A52]">—</span>}</Td>
              <Td muted>{s.current_period_end ? s.current_period_end.slice(0, 10) : "—"}</Td>
              <Td muted>{s.created_at.slice(0, 10)}</Td>
            </Tr>
          ))}
        </Tbody>
      </Table>

      {data && data.total > 25 && (
        <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]">
          <span>Page {page} · {data.total.toLocaleString()} total</span>
          <div className="flex gap-2">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">← Prev</button>
            <button onClick={() => setPage(p => p + 1)} disabled={page * 25 >= data.total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Next →</button>
          </div>
        </div>
      )}
    </>
  );
}
