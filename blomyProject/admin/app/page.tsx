"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api, getToken, ApiError, type OverviewData, type UserItem, type SubItem } from "@/lib/api";
import TopBar from "@/components/TopBar";
import StatCard from "@/components/StatCard";
import Badge from "@/components/Badge";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner } from "@/components/PageShell";

export default function DashboardPage() {
  const router = useRouter();
  const [overview, setOverview] = useState<OverviewData | null>(null);
  const [users, setUsers] = useState<UserItem[]>([]);
  const [subs, setSubs] = useState<SubItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    Promise.all([
      api.get<OverviewData>("/admin/overview", token),
      api.get<{ items: UserItem[] }>("/admin/users?page=1&page_size=6", token),
      api.get<{ items: SubItem[] }>("/admin/subscriptions?page=1&page_size=5", token),
    ])
      .then(([ov, ul, sl]) => {
        setOverview(ov);
        setUsers(ul.items);
        setSubs(sl.items);
      })
      .catch(e => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
        else setError(e instanceof Error ? e.message : "Failed to load dashboard");
      })
      .finally(() => setLoading(false));
  }, [router]);

  return (
    <>
      <TopBar title="Dashboard" subtitle="Vyla Health operations overview — DemyCorp Ltd" />
      {error && <ErrorBanner message={error} />}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Total Users"      value={loading ? "—" : overview!.total_users.toLocaleString()}   sub={`+${overview?.signups_today ?? 0} today`} />
        <StatCard label="Premium Users"    value={loading ? "—" : overview!.premium_users.toLocaleString()} sub={`${overview && overview.total_users ? ((overview.premium_users / overview.total_users) * 100).toFixed(1) : 0}% conversion`} accent />
        <StatCard label="Total Invoiced"   value={loading ? "—" : `£${(overview?.total_invoiced_gbp ?? 0).toLocaleString("en-GB", { minimumFractionDigits: 2 })}`} sub="Paid invoices" />
        <StatCard label="Active Grants"    value={loading ? "—" : String(overview?.active_premium_grants ?? 0)} sub="Manual premium grants" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        {/* Platform stats */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-[#FFD9C2] p-6">
          <p className="text-xs font-semibold uppercase tracking-wider text-[#A06A52] mb-5">Platform at a glance</p>
          <div className="grid grid-cols-2 gap-4">
            {loading ? (
              <div className="col-span-2 h-24 bg-[#FFD9C2] rounded-lg animate-pulse" />
            ) : overview && (
              [
                { label: "Active accounts", value: overview.active_users.toLocaleString() },
                { label: "Wearable connected", value: overview.wearable_connected_users.toLocaleString() },
                { label: "Onboarding done", value: overview.onboarding_completed_users.toLocaleString() },
                { label: "AI threads total", value: overview.ai_threads_total.toLocaleString() },
                { label: "Daily logs today", value: overview.daily_logs_today.toLocaleString() },
                { label: "Predictions today", value: overview.predictions_today.toLocaleString() },
                { label: "Signups this week", value: overview.signups_this_week.toLocaleString() },
                { label: "Anonymous users", value: overview.anonymous_users.toLocaleString() },
              ].map(({ label, value }) => (
                <div key={label} className="bg-[#FFF6F0] rounded-xl px-4 py-3">
                  <p className="text-[11px] text-[#A06A52] mb-0.5">{label}</p>
                  <p className="text-xl font-semibold text-[#1E0C16]">{value}</p>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Webhook errors */}
        <div className="bg-white rounded-2xl border border-[#FFD9C2] p-6">
          <p className="text-xs font-semibold uppercase tracking-wider text-[#A06A52] mb-5">Webhook errors (30d)</p>
          <div className="space-y-4">
            {[
              { label: "Stripe errors",       value: overview?.stripe_errors_30d ?? 0,       color: "bg-indigo-400" },
              { label: "Flutterwave errors",  value: overview?.flutterwave_errors_30d ?? 0,  color: "bg-yellow-400" },
              { label: "Referrals total",     value: overview?.referrals_total ?? 0,          color: "bg-[#FF7A33]" },
              { label: "Referrals qualified", value: overview?.referrals_qualified ?? 0,      color: "bg-emerald-400" },
            ].map(({ label, value, color }) => (
              <div key={label} className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className={`w-2 h-2 rounded-full ${color}`} />
                  <span className="text-[13px] text-[#3D1F2E]">{label}</span>
                </div>
                <span className="text-[13px] font-semibold text-[#1E0C16]">{loading ? "—" : value.toLocaleString()}</span>
              </div>
            ))}
          </div>
          <div className="mt-6 pt-4 border-t border-[#FFD9C2]">
            <a href="/webhook-errors" className="text-xs text-[#FF7A33] hover:text-[#e86a22]">View all webhook errors →</a>
          </div>
        </div>
      </div>

      {/* Recent Users */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-3">
          <p className="text-sm font-semibold text-[#1E0C16]">Recent registrations</p>
          <a href="/users" className="text-xs text-[#FF7A33] hover:text-[#e86a22]">View all →</a>
        </div>
        <Table>
          <Thead><Th>ID</Th><Th>Email</Th><Th>Mode</Th><Th>Verified</Th><Th>Plan</Th><Th>Joined</Th></Thead>
          <Tbody>
            {loading ? <LoadingRows cols={6} /> : users.length === 0 ? (
              <tr><td colSpan={6} className="px-6 py-8 text-center text-sm text-[#A06A52]">No users found</td></tr>
            ) : users.map(u => (
              <Tr key={u.id}>
                <Td muted>{u.id.slice(0, 12)}…</Td>
                <Td>{u.email ?? "—"}</Td>
                <Td><Badge label={u.account_mode} /></Td>
                <Td><Badge label={u.email_verified ? "verified" : "unverified"} /></Td>
                <Td><Badge label={u.subscription_tier ?? "free"} /></Td>
                <Td muted>{u.created_at.slice(0, 10)}</Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
      </div>

      {/* Recent Subscriptions */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <p className="text-sm font-semibold text-[#1E0C16]">Recent subscriptions</p>
          <a href="/subscriptions" className="text-xs text-[#FF7A33] hover:text-[#e86a22]">View all →</a>
        </div>
        <Table>
          <Thead><Th>User</Th><Th>Tier</Th><Th>Provider</Th><Th>Status</Th><Th>Amount</Th><Th>Date</Th></Thead>
          <Tbody>
            {loading ? <LoadingRows cols={6} /> : subs.length === 0 ? (
              <tr><td colSpan={6} className="px-6 py-8 text-center text-sm text-[#A06A52]">No subscriptions found</td></tr>
            ) : subs.map(s => (
              <Tr key={s.id}>
                <Td>{s.user_email ?? s.user_id.slice(0, 10)}</Td>
                <Td><Badge label={s.tier} /></Td>
                <Td>{s.provider ? <Badge label={s.provider} /> : <span className="text-[#A06A52] text-[12px]">—</span>}</Td>
                <Td><Badge label={s.status} /></Td>
                <Td>{s.amount ? `${s.currency} ${s.amount.toFixed(2)}` : <span className="text-[#A06A52]">—</span>}</Td>
                <Td muted>{s.created_at.slice(0, 10)}</Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
      </div>
    </>
  );
}
