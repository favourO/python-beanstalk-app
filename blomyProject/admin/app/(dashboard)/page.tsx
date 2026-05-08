"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { PieChart, Pie, Cell, ResponsiveContainer } from "recharts";
import { api, getToken, ApiError, type OverviewData, type ContactListOut, type ContactMessageItem } from "@/lib/api";
import TopBar from "@/components/TopBar";

const PIE_COLORS = ["#FF7A33", "#1E0C16", "#A06A52", "#FFB38A"];

function fmt(n: number) {
  return n.toLocaleString("en-GB");
}

function fmtGbp(n: number) {
  return "£" + n.toLocaleString("en-GB", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function KpiCard({ label, value, sub, icon }: { label: string; value: string; sub?: string; icon: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-2 rounded-2xl border border-[#F0E8E4] bg-white p-4">
      <div className="flex items-start justify-between">
        <span className="text-[11px] font-medium uppercase tracking-wide text-[#9E7B6E]">{label}</span>
        <span className="flex h-8 w-8 items-center justify-center rounded-xl bg-[#FFF0E8] text-[#FF7A33]">{icon}</span>
      </div>
      <p className="text-[24px] font-bold leading-none text-[#1E0C16]">{value}</p>
      {sub && <span className="text-[11px] text-[#B0938A]">{sub}</span>}
    </div>
  );
}

function SectionCard({ title, action, children }: { title: string; action?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="flex flex-col rounded-2xl border border-[#F0E8E4] bg-white p-5">
      <div className="mb-4 flex items-center justify-between">
        <p className="text-[13px] font-bold text-[#1E0C16]">{title}</p>
        {action}
      </div>
      {children}
    </div>
  );
}

function ViewAll({ href }: { href: string }) {
  return <a href={href} className="text-[11px] font-medium text-[#FF7A33] hover:text-[#e86a22]">View all</a>;
}

function DataNotice({ children }: { children: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-[#FFD9C2] bg-[#FFF6F0] px-4 py-3 text-[12px] leading-5 text-[#7C4E3B]">
      {children}
    </div>
  );
}

function ContactMessagesPanel({ token }: { token: string }) {
  const [data, setData] = useState<ContactListOut | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);

  useEffect(() => {
    api.get<ContactListOut>("/admin/contacts", token).then(setData).catch(() => {});
  }, [token]);

  const markRead = async (msg: ContactMessageItem) => {
    if (msg.read) return;
    await api.post(`/admin/contacts/${msg.id}/read`, token).catch(() => {});
    setData(d => d ? {
      ...d,
      unread: Math.max(0, d.unread - 1),
      items: d.items.map(m => m.id === msg.id ? { ...m, read: true } : m),
    } : d);
  };

  return (
    <SectionCard
      title={`Contact Messages${data && data.unread > 0 ? ` (${data.unread} unread)` : ""}`}
      action={<span className="text-[11px] text-[#B0938A]">{data ? `${data.total} total` : ""}</span>}
    >
      {!data ? (
        <p className="text-[12px] text-[#B0938A]">Loading…</p>
      ) : data.items.length === 0 ? (
        <p className="text-[12px] text-[#B0938A]">No messages yet.</p>
      ) : (
        <div className="space-y-2">
          {data.items.slice(0, 8).map(msg => (
            <div
              key={msg.id}
              className={`cursor-pointer rounded-xl border p-3 transition-colors ${msg.read ? "border-[#F0E8E4] bg-white" : "border-[#FFD9C2] bg-[#FFF6F0]"}`}
              onClick={() => { setExpanded(expanded === msg.id ? null : msg.id); markRead(msg); }}
            >
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    {!msg.read && <span className="h-2 w-2 shrink-0 rounded-full bg-[#FF7A33]" />}
                    <p className="truncate text-[12px] font-semibold text-[#1E0C16]">{msg.name}</p>
                    <span className="truncate text-[11px] text-[#B0938A]">{msg.email}</span>
                  </div>
                  <p className="mt-0.5 truncate text-[11px] text-[#7A4A32]">{msg.subject}</p>
                </div>
                <span className="shrink-0 text-[10px] text-[#B0938A]">{new Date(msg.created_at).toLocaleDateString()}</span>
              </div>
              {expanded === msg.id && (
                <p className="mt-2 whitespace-pre-wrap border-t border-[#FFD9C2] pt-2 text-[12px] leading-relaxed text-[#3D1F2E]">{msg.message}</p>
              )}
            </div>
          ))}
        </div>
      )}
    </SectionCard>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const [overview, setOverview] = useState<OverviewData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    const token = getToken();
    if (!token) {
      router.push("/login");
      return;
    }
    setToken(token);
    api.get<OverviewData>("/admin/overview", token)
      .then(setOverview)
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
        setError(e instanceof Error ? e.message : "Failed to load overview");
      })
      .finally(() => setLoading(false));
  }, [router]);

  const ov = overview;
  const userDistribution = useMemo(() => ov ? [
    { name: "Free", value: ov.free_users },
    { name: "Premium", value: ov.premium_users },
    { name: "Trialing", value: ov.trialing_users },
    { name: "Anonymous", value: ov.anonymous_users },
  ] : [], [ov]);

  const totalPaymentErrors = ov ? ov.flutterwave_errors_30d + ov.stripe_errors_30d : 0;

  return (
    <div className="space-y-5">
      <TopBar title="Overview" subtitle="Live Vyla admin metrics from the backend overview endpoint." />

      {error && (
        <div className="rounded-xl border border-red-200 bg-red-50 px-5 py-4 text-sm text-red-700">
          <span className="font-semibold">Error: </span>{error}
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <KpiCard label="Total Users" value={loading || !ov ? "-" : fmt(ov.total_users)} sub="All accounts" icon={<UsersIcon />} />
        <KpiCard label="Active Users" value={loading || !ov ? "-" : fmt(ov.active_users)} sub="Backend total" icon={<UsersIcon />} />
        <KpiCard label="Signups Today" value={loading || !ov ? "-" : fmt(ov.signups_today)} sub="Created today" icon={<SignupIcon />} />
        <KpiCard label="Signups This Week" value={loading || !ov ? "-" : fmt(ov.signups_this_week)} sub="Backend total" icon={<SignupIcon />} />
      </div>

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <KpiCard label="Premium Users" value={loading || !ov ? "-" : fmt(ov.premium_users)} sub="Current entitlement" icon={<RevenueIcon />} />
        <KpiCard label="Total Invoiced" value={loading || !ov ? "-" : fmtGbp(ov.total_invoiced_gbp)} sub="Backend invoice sum" icon={<PaymentIcon />} />
        <KpiCard label="Payment Errors" value={loading || !ov ? "-" : fmt(totalPaymentErrors)} sub="Last 30 days" icon={<PaymentIcon />} />
        <KpiCard label="Deleted Users" value={loading || !ov ? "-" : fmt(ov.deleted_users)} sub="Soft-deleted accounts" icon={<UsersIcon />} />
      </div>

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <KpiCard label="Wearable Connected" value={loading || !ov ? "-" : fmt(ov.wearable_connected_users)} sub="Connected profiles" icon={<WearableIcon />} />
        <KpiCard label="Daily Logs Today" value={loading || !ov ? "-" : fmt(ov.daily_logs_today)} sub="Submitted today" icon={<LogIcon />} />
        <KpiCard label="Predictions Today" value={loading || !ov ? "-" : fmt(ov.predictions_today)} sub="Generated today" icon={<CycleIcon />} />
        <KpiCard label="AI Threads" value={loading || !ov ? "-" : fmt(ov.ai_threads_total)} sub="All conversations" icon={<AIIcon />} />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <SectionCard title="User Distribution" action={<ViewAll href="/users" />}>
          {ov ? (
            <div className="flex items-center gap-2">
              <ResponsiveContainer width="55%" height={180}>
                <PieChart>
                  <Pie data={userDistribution} cx="50%" cy="50%" innerRadius={52} outerRadius={78} paddingAngle={2} dataKey="value" startAngle={90} endAngle={-270}>
                    {userDistribution.map((_, i) => <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />)}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
              <div className="flex-1 space-y-2">
                {userDistribution.map((item, i) => (
                  <div key={item.name} className="flex items-center gap-2">
                    <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: PIE_COLORS[i] }} />
                    <div className="min-w-0">
                      <p className="truncate text-[10px] text-[#9E7B6E]">{item.name}</p>
                      <p className="text-[12px] font-semibold text-[#1E0C16]">{fmt(item.value)}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : <DataNotice>Waiting for live overview data.</DataNotice>}
        </SectionCard>

        <SectionCard title="Activity Today" action={<ViewAll href="/notifications" />}>
          <div className="space-y-3">
            {[
              ["Daily logs", ov?.daily_logs_today],
              ["Predictions", ov?.predictions_today],
              ["New signups", ov?.signups_today],
              ["Onboarding completed", ov?.onboarding_completed_users],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between border-b border-[#F5EDE8] pb-2 last:border-0">
                <span className="text-[12px] text-[#3D1F2E]">{label}</span>
                <span className="text-[13px] font-bold text-[#1E0C16]">{loading || value == null ? "-" : fmt(Number(value))}</span>
              </div>
            ))}
          </div>
        </SectionCard>

        <SectionCard title="Billing And Errors" action={<ViewAll href="/webhook-errors" />}>
          <div className="space-y-3">
            {[
              ["Total invoiced", ov ? fmtGbp(ov.total_invoiced_gbp) : "-"],
              ["Stripe webhook errors", ov ? fmt(ov.stripe_errors_30d) : "-"],
              ["Flutterwave webhook errors", ov ? fmt(ov.flutterwave_errors_30d) : "-"],
              ["Active premium grants", ov ? fmt(ov.active_premium_grants) : "-"],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between border-b border-[#F5EDE8] pb-2 last:border-0">
                <span className="text-[12px] text-[#3D1F2E]">{label}</span>
                <span className="text-[13px] font-bold text-[#1E0C16]">{loading ? "-" : value}</span>
              </div>
            ))}
          </div>
        </SectionCard>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <SectionCard title="Referrals" action={<ViewAll href="/referrals" />}>
          <div className="space-y-3">
            <div className="flex items-center justify-between border-b border-[#F5EDE8] pb-2">
              <span className="text-[12px] text-[#3D1F2E]">Total referrals</span>
              <span className="text-[13px] font-bold text-[#1E0C16]">{loading || !ov ? "-" : fmt(ov.referrals_total)}</span>
            </div>
            <div className="flex items-center justify-between border-b border-[#F5EDE8] pb-2">
              <span className="text-[12px] text-[#3D1F2E]">Qualified referrals</span>
              <span className="text-[13px] font-bold text-[#1E0C16]">{loading || !ov ? "-" : fmt(ov.referrals_qualified)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-[12px] text-[#3D1F2E]">Active premium grants</span>
              <span className="text-[13px] font-bold text-[#1E0C16]">{loading || !ov ? "-" : fmt(ov.active_premium_grants)}</span>
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Data Coverage" action={<ViewAll href="/health-data" />}>
          <div className="space-y-3">
            <div className="flex items-center justify-between border-b border-[#F5EDE8] pb-2">
              <span className="text-[12px] text-[#3D1F2E]">Wearable connected users</span>
              <span className="text-[13px] font-bold text-[#1E0C16]">{loading || !ov ? "-" : fmt(ov.wearable_connected_users)}</span>
            </div>
            <div className="flex items-center justify-between border-b border-[#F5EDE8] pb-2">
              <span className="text-[12px] text-[#3D1F2E]">Onboarding completed</span>
              <span className="text-[13px] font-bold text-[#1E0C16]">{loading || !ov ? "-" : fmt(ov.onboarding_completed_users)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-[12px] text-[#3D1F2E]">Anonymous users</span>
              <span className="text-[13px] font-bold text-[#1E0C16]">{loading || !ov ? "-" : fmt(ov.anonymous_users)}</span>
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Unavailable Metrics">
          <DataNotice>
            Growth charts, support ticket counts, campaign conversion rates, live system alerts, and payment counts are not shown because the backend does not currently expose those datasets.
          </DataNotice>
        </SectionCard>
      </div>

      {token && <ContactMessagesPanel token={token} />}
    </div>
  );
}

function UsersIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="6" cy="5" r="2.5"/><path d="M1 14c0-3 2-4.5 5-4.5s5 1.5 5 4.5"/><circle cx="12" cy="5" r="2"/><path d="M12 9c1.5.3 3 1.2 3 3.5"/></svg>;
}
function SignupIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="6" cy="5" r="2.5"/><path d="M1 14c0-3 2-4.5 5-4.5"/><path d="M11 9v6M8 12h6"/></svg>;
}
function RevenueIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><rect x="1" y="3" width="14" height="10" rx="1.5"/><path d="M1 6h14M5 9h2M10 9h1"/></svg>;
}
function PaymentIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M8 1v14M5 4h4.5a2.5 2.5 0 010 5H5m0 0h4a2.5 2.5 0 010 5H5"/></svg>;
}
function WearableIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><rect x="4" y="4" width="8" height="8" rx="2"/><path d="M6 2h4M6 14h4"/></svg>;
}
function LogIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M4 2h8a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z"/><path d="M5 6h6M5 9h4"/></svg>;
}
function CycleIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="6"/><path d="M8 5v3l2 2"/></svg>;
}
function AIIcon() {
  return <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="6"/><path d="M5.5 8.5l2 2 3-4"/></svg>;
}
