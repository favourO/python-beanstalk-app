"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend,
} from "recharts";
import { api, getToken, ApiError, type OverviewData } from "@/lib/api";
import TopBar from "@/components/TopBar";

// ── Colour palette ────────────────────────────────────────────────────────────
const ORANGE = "#FF7A33";
const ORANGE_LIGHT = "#FFD9C2";
const PIE_COLORS = ["#FF7A33", "#1E0C16", "#A06A52", "#FFB38A"];

// ── Static demo data for charts (replaced with real data when API has it) ─────
const userGrowthData = [
  { date: "May 12", users: 238 }, { date: "May 13", users: 265 },
  { date: "May 14", users: 252 }, { date: "May 15", users: 289 },
  { date: "May 16", users: 310 }, { date: "May 17", users: 297 },
  { date: "May 18", users: 345 },
];

const wearableData = [
  { name: "Vyla Band",    value: 32600, pct: 60, color: "#FF7A33" },
  { name: "Apple Watch",  value: 10275, pct: 19, color: "#1E0C16" },
  { name: "Fitbit",       value: 7100,  pct: 13, color: "#A06A52" },
  { name: "Other",        value: 4634,  pct: 8,  color: "#FFD9C2" },
];

const referralData = [
  { campaign: "Tech Mom",          users: 12830, conv: "38.2%" },
  { campaign: "Vyla Month Launch", users: 4930,  conv: "29.8%" },
  { campaign: "Better Health",     users: 3,     conv: "37.2%" },
  { campaign: "Student Special",   users: 4501,  conv: "23.4%" },
];

const systemAlerts = [
  { msg: "Wearable sync issues detected",      time: "2 min ago",  type: "warn" },
  { msg: "AI insight generation paused",        time: "15 min ago", type: "info" },
  { msg: "High volume of failed payments",      time: "1 hr ago",   type: "error" },
  { msg: "Scheduled maintenance — May 23",      time: "3 hr ago",   type: "info" },
];

// ── Helpers ───────────────────────────────────────────────────────────────────
function fmt(n: number) { return n.toLocaleString(); }
function fmtGbp(n: number) { return "£" + n.toLocaleString("en-GB", { minimumFractionDigits: 0 }); }

// ── Sub-components ────────────────────────────────────────────────────────────
function KpiCard({
  label, value, sub, trend, trendUp, icon,
}: {
  label: string; value: string; sub?: string; trend?: string; trendUp?: boolean; icon: React.ReactNode;
}) {
  return (
    <div className="bg-white rounded-2xl border border-[#F0E8E4] p-4 flex flex-col gap-2">
      <div className="flex items-start justify-between">
        <span className="text-[11px] font-medium text-[#9E7B6E] uppercase tracking-wide">{label}</span>
        <span className="w-8 h-8 rounded-xl bg-[#FFF0E8] flex items-center justify-center text-[#FF7A33]">{icon}</span>
      </div>
      <p className="text-[24px] font-bold text-[#1E0C16] leading-none">{value}</p>
      <div className="flex items-center gap-1.5">
        {trend && (
          <span className={`flex items-center gap-0.5 text-[11px] font-semibold ${trendUp ? "text-emerald-500" : "text-red-400"}`}>
            {trendUp ? <ArrowUp /> : <ArrowDown />}
            {trend}
          </span>
        )}
        {sub && <span className="text-[11px] text-[#B0938A]">{sub}</span>}
      </div>
    </div>
  );
}

function SectionCard({ title, action, children }: { title: string; action?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-[#F0E8E4] p-5 flex flex-col">
      <div className="flex items-center justify-between mb-4">
        <p className="text-[13px] font-bold text-[#1E0C16]">{title}</p>
        {action}
      </div>
      {children}
    </div>
  );
}

function ViewAll({ href }: { href: string }) {
  return (
    <a href={href} className="text-[11px] text-[#FF7A33] hover:text-[#e86a22] font-medium">
      View all
    </a>
  );
}

function AlertDot({ type }: { type: string }) {
  const color = type === "error" ? "bg-red-400" : type === "warn" ? "bg-amber-400" : "bg-blue-400";
  return <span className={`w-2 h-2 rounded-full shrink-0 mt-1 ${color}`} />;
}

// ── Main page ─────────────────────────────────────────────────────────────────
export default function DashboardPage() {
  const router = useRouter();
  const [overview, setOverview] = useState<OverviewData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    api.get<OverviewData>("/admin/overview", token)
      .then(setOverview)
      .catch(e => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      })
      .finally(() => setLoading(false));
  }, [router]);

  const ov = overview;

  // Build distribution data from real values when available
  const distData = ov ? [
    { name: "Free Users",    value: ov.free_users },
    { name: "Premium",       value: ov.premium_users },
    { name: "Trialing",      value: ov.trialing_users },
    { name: "Anonymous",     value: ov.anonymous_users },
  ] : [
    { name: "Free Users",    value: 180000 },
    { name: "Premium",       value: 52000 },
    { name: "Trialing",      value: 18000 },
    { name: "Anonymous",     value: 6890 },
  ];

  return (
    <div className="space-y-5">
      <TopBar
        title="Overview"
        subtitle="Welcome back. Here's what's happening with Vyla today."
      />

      {/* ── KPI Row 1 ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        <KpiCard
          label="Active Users"
          value={loading || !ov ? "—" : fmt(ov.active_users)}
          trend="+4.5%"
          trendUp
          sub="vs last week"
          icon={<UsersIcon />}
        />
        <KpiCard
          label="New Signups"
          value={loading || !ov ? "—" : fmt(ov.signups_this_week)}
          trend="+2.1%"
          trendUp
          sub="vs last week"
          icon={<SignupIcon />}
        />
        <KpiCard
          label="Revenue"
          value={loading || !ov ? "—" : fmtGbp(ov.total_invoiced_gbp)}
          trend="+8%"
          trendUp
          sub="vs last week"
          icon={<RevenueIcon />}
        />
        <KpiCard
          label="Total Payments"
          value={loading ? "—" : "1,243"}
          sub="this week"
          icon={<PaymentIcon />}
        />
      </div>

      {/* ── KPI Row 2 ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        <KpiCard
          label="Wearable Connected"
          value={loading || !ov ? "—" : fmt(ov.wearable_connected_users)}
          trend="+1.2%"
          trendUp
          sub="vs last week"
          icon={<WearableIcon />}
        />
        <KpiCard
          label="Daily Logs Submitted"
          value={loading || !ov ? "—" : fmt(ov.daily_logs_today)}
          trend="+3.8%"
          trendUp
          sub="vs last week"
          icon={<LogIcon />}
        />
        <KpiCard
          label="Cycle Predictions"
          value={loading || !ov ? "—" : fmt(ov.predictions_today)}
          trend="+5.2%"
          trendUp
          sub="vs last week"
          icon={<CycleIcon />}
        />
        <KpiCard
          label="AI Insights Generated"
          value={loading || !ov ? "—" : fmt(ov.ai_threads_total)}
          trend="+7.4%"
          trendUp
          sub="vs last week"
          icon={<AIIcon />}
        />
      </div>

      {/* ── Middle row ─────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        {/* User Growth chart */}
        <SectionCard title="User Growth" action={<ViewAll href="/users" />}>
          <ResponsiveContainer width="100%" height={180}>
            <AreaChart data={userGrowthData} margin={{ top: 4, right: 4, bottom: 0, left: -20 }}>
              <defs>
                <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={ORANGE} stopOpacity={0.2} />
                  <stop offset="95%" stopColor={ORANGE} stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="date" tick={{ fontSize: 10, fill: "#B0938A" }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 10, fill: "#B0938A" }} axisLine={false} tickLine={false} />
              <Tooltip
                contentStyle={{ background: "#fff", border: "1px solid #F0E8E4", borderRadius: 8, fontSize: 11 }}
                labelStyle={{ color: "#1E0C16", fontWeight: 600 }}
              />
              <Area type="monotone" dataKey="users" stroke={ORANGE} strokeWidth={2} fill="url(#areaGrad)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </SectionCard>

        {/* User Distribution donut */}
        <SectionCard title="User Distribution" action={<ViewAll href="/users" />}>
          <div className="flex items-center gap-2">
            <ResponsiveContainer width="55%" height={180}>
              <PieChart>
                <Pie
                  data={distData}
                  cx="50%"
                  cy="50%"
                  innerRadius={52}
                  outerRadius={78}
                  paddingAngle={2}
                  dataKey="value"
                  startAngle={90}
                  endAngle={-270}
                >
                  {distData.map((_, i) => (
                    <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                  ))}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
            <div className="flex-1 space-y-2">
              {distData.map((d, i) => (
                <div key={d.name} className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: PIE_COLORS[i] }} />
                  <div className="min-w-0">
                    <p className="text-[10px] text-[#9E7B6E] truncate">{d.name}</p>
                    <p className="text-[12px] font-semibold text-[#1E0C16]">{d.value.toLocaleString()}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </SectionCard>

        {/* Wearable Connections */}
        <SectionCard title="Wearable Connections" action={<ViewAll href="/wearables" />}>
          <div className="space-y-4">
            {wearableData.map(w => (
              <div key={w.name}>
                <div className="flex items-center justify-between mb-1">
                  <span className="text-[12px] text-[#3D1F2E] font-medium">{w.name}</span>
                  <span className="text-[12px] text-[#9E7B6E]">{w.value.toLocaleString()}</span>
                </div>
                <div className="h-1.5 bg-[#F5EDE8] rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all"
                    style={{ width: `${w.pct}%`, background: w.color }}
                  />
                </div>
                <p className="text-[10px] text-[#B0938A] mt-0.5">{w.pct}%</p>
              </div>
            ))}
          </div>
        </SectionCard>
      </div>

      {/* ── Bottom row ─────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        {/* Top Referral Campaigns */}
        <SectionCard title="Top Referral Campaigns" action={<ViewAll href="/referrals" />}>
          <table className="w-full text-left">
            <thead>
              <tr>
                {["Campaign", "Users", "Conversion"].map(h => (
                  <th key={h} className="pb-2 text-[10px] font-semibold uppercase tracking-wider text-[#B0938A]">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-[#F5EDE8]">
              {referralData.map(r => (
                <tr key={r.campaign}>
                  <td className="py-2 text-[12px] text-[#1E0C16] font-medium">{r.campaign}</td>
                  <td className="py-2 text-[12px] text-[#3D1F2E]">{r.users.toLocaleString()}</td>
                  <td className="py-2">
                    <span className="inline-block px-2 py-0.5 rounded-full text-[11px] font-semibold bg-[#FFF0E8] text-[#FF7A33]">
                      {r.conv}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </SectionCard>

        {/* Support Tickets */}
        <SectionCard title="Support Tickets" action={<ViewAll href="/support" />}>
          <div className="space-y-3">
            {[
              { label: "In Progress",     value: 128, color: "bg-amber-400" },
              { label: "Pending",         value: 48,  color: "bg-blue-400" },
              { label: "Resolved Today",  value: 6,   color: "bg-emerald-400" },
              { label: "AI Breakdown",    value: 24,  color: "bg-[#FF7A33]" },
            ].map(t => (
              <div key={t.label} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className={`w-2.5 h-2.5 rounded-full ${t.color}`} />
                  <span className="text-[12px] text-[#3D1F2E]">{t.label}</span>
                </div>
                <span className="text-[13px] font-bold text-[#1E0C16]">{t.value}</span>
              </div>
            ))}
          </div>
          <div className="mt-4 pt-3 border-t border-[#F5EDE8]">
            <div className="flex items-center justify-between text-[11px] text-[#9E7B6E]">
              <span>Avg. resolution time</span>
              <span className="font-semibold text-[#1E0C16]">4.2 hrs</span>
            </div>
          </div>
        </SectionCard>

        {/* Recent System Alerts */}
        <SectionCard title="Recent System Alerts" action={<ViewAll href="/audit-log" />}>
          <div className="space-y-3">
            {systemAlerts.map((a, i) => (
              <div key={i} className="flex items-start gap-2.5">
                <AlertDot type={a.type} />
                <div className="min-w-0">
                  <p className="text-[12px] text-[#1E0C16] leading-snug">{a.msg}</p>
                  <p className="text-[10px] text-[#B0938A] mt-0.5">{a.time}</p>
                </div>
              </div>
            ))}
          </div>
          <div className="mt-4 pt-3 border-t border-[#F5EDE8]">
            <a href="/audit-log" className="text-[11px] text-[#FF7A33] hover:text-[#e86a22] font-medium">
              View audit log →
            </a>
          </div>
        </SectionCard>
      </div>
    </div>
  );
}

// ── Arrow helpers ─────────────────────────────────────────────────────────────
function ArrowUp() {
  return <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor"><path d="M5 2l4 4H1z"/></svg>;
}
function ArrowDown() {
  return <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor"><path d="M5 8l4-4H1z"/></svg>;
}

// ── KPI Icons ─────────────────────────────────────────────────────────────────
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
