"use client";
import { useEffect, useState, useCallback, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { api, getToken, ApiError, type UserItem, type UserListOut, type UserDetailOut, type SubItem, type InvoiceItem } from "@/lib/api";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";

// ── User Detail View ──────────────────────────────────────────────────────────

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-[#F0E8E4] p-5">
      <p className="text-[12px] font-bold text-[#1E0C16] uppercase tracking-wider mb-4">{title}</p>
      {children}
    </div>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between py-2 border-b border-[#F5EDE8] last:border-0">
      <span className="text-[12px] text-[#9E7B6E] shrink-0 w-44">{label}</span>
      <span className="text-[12px] text-[#1E0C16] font-medium text-right">{value ?? "—"}</span>
    </div>
  );
}

function StatBox({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-[#FFF6F0] rounded-xl p-4 text-center">
      <p className="text-[22px] font-bold text-[#1E0C16]">{value}</p>
      <p className="text-[11px] font-medium text-[#FF7A33] mt-0.5">{label}</p>
    </div>
  );
}

function UserDetailView({ userId, onBack }: { userId: string; onBack: () => void }) {
  const router = useRouter();
  const [user, setUser] = useState<UserDetailOut | null>(null);
  const [subs, setSubs] = useState<SubItem[]>([]);
  const [invoices, setInvoices] = useState<InvoiceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionMsg, setActionMsg] = useState<string | null>(null);
  const [actionErr, setActionErr] = useState<string | null>(null);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    Promise.all([
      api.get<UserDetailOut>(`/admin/users/${userId}`, token),
      api.get<{ items: SubItem[] }>(`/admin/subscriptions?user_id=${userId}&page_size=10`, token).catch(() => ({ items: [] })),
      api.get<{ items: InvoiceItem[] }>(`/admin/billing/invoices?user_id=${userId}&page_size=10`, token).catch(() => ({ items: [] })),
    ])
      .then(([u, s, inv]) => { setUser(u); setSubs(s.items); setInvoices(inv.items); })
      .catch(e => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      })
      .finally(() => setLoading(false));
  }, [userId, router]);

  async function doAction(action: "suspend" | "reactivate") {
    const token = getToken();
    if (!token) return;
    setActionMsg(null); setActionErr(null);
    try {
      await api.post(`/admin/users/${userId}/${action}?reason=admin_action`, token);
      setActionMsg(action === "suspend" ? "User suspended." : "User reactivated.");
      const updated = await api.get<UserDetailOut>(`/admin/users/${userId}`, getToken()!);
      setUser(updated);
    } catch (e) {
      setActionErr(e instanceof Error ? e.message : "Action failed");
    }
  }

  if (loading) {
    return (
      <div className="space-y-4 animate-pulse">
        <div className="h-8 w-48 bg-[#F5EDE8] rounded-xl" />
        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3].map(i => <div key={i} className="h-24 bg-[#F5EDE8] rounded-2xl" />)}
        </div>
        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3].map(i => <div key={i} className="h-48 bg-[#F5EDE8] rounded-2xl" />)}
        </div>
      </div>
    );
  }

  if (!user) return <ErrorBanner message="User not found." />;

  const initials = user.full_name
    ? user.full_name.split(" ").map((w: string) => w[0]).join("").slice(0, 2).toUpperCase()
    : (user.email ?? "?")[0].toUpperCase();

  const isActive = !user.deleted_at;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-start gap-4">
        <button
          onClick={onBack}
          className="mt-1 flex items-center gap-1.5 text-[12px] text-[#9E7B6E] hover:text-[#FF7A33] transition-colors shrink-0"
        >
          <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M10 3L5 8l5 5"/></svg>
          All Users
        </button>
        <div className="flex-1 flex items-center gap-4 flex-wrap">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#FF7A33] to-[#FFB38A] flex items-center justify-center text-white text-lg font-bold shrink-0">
            {initials}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-[20px] font-bold text-[#1E0C16]">{user.full_name ?? user.email ?? "Unknown User"}</h1>
              <Badge label={isActive ? "active" : "suspended"} />
              {user.is_admin && <Badge label="admin" />}
            </div>
            <p className="text-[12px] text-[#9E7B6E] mt-0.5 break-all">{user.email ?? "No email"} · <span className="font-mono">{user.id}</span></p>
          </div>
          <div className="flex gap-2 shrink-0">
            {isActive ? (
              <button
                onClick={() => { if (confirm("Suspend this user?")) doAction("suspend"); }}
                className="px-4 py-2 text-[12px] font-semibold text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition-colors"
              >
                Suspend
              </button>
            ) : (
              <button
                onClick={() => doAction("reactivate")}
                className="px-4 py-2 text-[12px] font-semibold text-emerald-600 border border-emerald-200 rounded-lg hover:bg-emerald-50 transition-colors"
              >
                Reactivate
              </button>
            )}
          </div>
        </div>
      </div>

      {actionMsg && (
        <div className="px-4 py-3 bg-emerald-50 border border-emerald-200 text-emerald-700 text-[13px] rounded-xl flex justify-between">
          {actionMsg}<button onClick={() => setActionMsg(null)}>✕</button>
        </div>
      )}
      {actionErr && (
        <div className="px-4 py-3 bg-red-50 border border-red-200 text-red-700 text-[13px] rounded-xl flex justify-between">
          {actionErr}<button onClick={() => setActionErr(null)}>✕</button>
        </div>
      )}

      {/* Stat boxes */}
      <div className="grid grid-cols-3 gap-4">
        <StatBox label="Cycle Records"  value={user.cycle_records_count} />
        <StatBox label="Daily Logs"     value={user.daily_logs_count} />
        <StatBox label="AI Threads"     value={user.ai_threads_count} />
      </div>

      {/* Detail grid */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <Section title="Account">
          <Row label="User ID"         value={<span className="font-mono text-[10px] break-all">{user.id}</span>} />
          <Row label="Email"           value={user.email} />
          <Row label="Account mode"    value={<Badge label={user.account_mode} />} />
          <Row label="Email verified"  value={<Badge label={user.email_verified ? "verified" : "unverified"} />} />
          <Row label="Admin"           value={user.is_admin ? "Yes" : "No"} />
          <Row label="Joined"          value={user.created_at.slice(0, 10)} />
          <Row label="Status"          value={<Badge label={isActive ? "active" : "suspended"} />} />
          {user.deleted_at && <Row label="Suspended at" value={user.deleted_at.slice(0, 10)} />}
        </Section>

        <Section title="Profile">
          <Row label="Full name"       value={user.full_name} />
          <Row label="Date of birth"   value={user.date_of_birth} />
          <Row label="Goal"            value={user.goal} />
          <Row label="Timezone"        value={user.timezone} />
          <Row label="Wearable"        value={user.wearable_type} />
          <Row label="Onboarding"      value={<Badge label={user.onboarding_completed ? "completed" : "pending"} />} />
          {!user.onboarding_completed && (
            <Row label="Onboarding step" value={user.onboarding_step != null ? `Step ${user.onboarding_step}` : null} />
          )}
        </Section>

        <Section title="Subscription">
          <Row label="Plan"            value={<Badge label={user.subscription_tier ?? "free"} />} />
          <Row label="Status"          value={user.subscription_status ? <Badge label={user.subscription_status} /> : null} />
          <Row label="Provider"        value={user.subscription_provider} />
          <Row label="Period ends"     value={user.subscription_period_end?.slice(0, 10)} />
        </Section>
      </div>

      {/* Subscription history */}
      {subs.length > 0 && (
        <Section title="Subscription History">
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-[#F5EDE8]">
                  {["Tier", "Status", "Provider", "Interval", "Amount", "Period End", "Created"].map(h => (
                    <th key={h} className="pb-2 pr-4 text-[10px] font-semibold uppercase tracking-wider text-[#B0938A]">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-[#F5EDE8]">
                {subs.map(s => (
                  <tr key={s.id}>
                    <td className="py-2 pr-4"><Badge label={s.tier} /></td>
                    <td className="py-2 pr-4"><Badge label={s.status} /></td>
                    <td className="py-2 pr-4 text-[12px] text-[#3D1F2E]">{s.provider ?? "—"}</td>
                    <td className="py-2 pr-4 text-[12px] text-[#3D1F2E]">{s.billing_interval ?? "—"}</td>
                    <td className="py-2 pr-4 text-[12px] font-semibold text-[#1E0C16]">
                      {s.amount ? `${s.currency} ${s.amount.toFixed(2)}` : "—"}
                    </td>
                    <td className="py-2 pr-4 text-[12px] text-[#9E7B6E]">{s.current_period_end?.slice(0, 10) ?? "—"}</td>
                    <td className="py-2 text-[12px] text-[#9E7B6E]">{s.created_at.slice(0, 10)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Section>
      )}

      {/* Invoice / payment history */}
      {invoices.length > 0 && (
        <Section title="Payment History">
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-[#F5EDE8]">
                  {["Invoice ID", "Provider", "Amount", "Currency", "Status", "Date"].map(h => (
                    <th key={h} className="pb-2 pr-4 text-[10px] font-semibold uppercase tracking-wider text-[#B0938A]">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-[#F5EDE8]">
                {invoices.map(inv => (
                  <tr key={inv.id}>
                    <td className="py-2 pr-4 text-[11px] font-mono text-[#9E7B6E]">
                      {(inv.provider_invoice_id ?? inv.id).slice(0, 18)}…
                    </td>
                    <td className="py-2 pr-4 text-[12px] text-[#3D1F2E]">{inv.provider ?? "—"}</td>
                    <td className="py-2 pr-4 text-[12px] font-semibold text-[#1E0C16]">{inv.total.toFixed(2)}</td>
                    <td className="py-2 pr-4 text-[12px] text-[#3D1F2E]">{inv.currency}</td>
                    <td className="py-2 pr-4"><Badge label={inv.status} /></td>
                    <td className="py-2 text-[12px] text-[#9E7B6E]">{inv.created_at.slice(0, 10)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Section>
      )}
    </div>
  );
}

// ── Users List View ───────────────────────────────────────────────────────────

function UsersListView({ onSelect }: { onSelect: (id: string) => void }) {
  const router = useRouter();
  const [data, setData] = useState<UserListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [includeDeleted, setIncludeDeleted] = useState(false);
  const [actionMsg, setActionMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true);
    setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "25" });
    if (search) params.set("search", search);
    if (includeDeleted) params.set("include_deleted", "true");
    try {
      setData(await api.get<UserListOut>(`/admin/users?${params}`, token));
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load users");
    } finally {
      setLoading(false);
    }
  }, [router, page, search, includeDeleted]);

  useEffect(() => { load(); }, [load]);

  async function suspend(userId: string) {
    const token = getToken();
    if (!token) return;
    if (!confirm("Suspend this user?")) return;
    try {
      await api.post(`/admin/users/${userId}/suspend?reason=admin_action`, token);
      setActionMsg("User suspended."); load();
    } catch (e) { setActionMsg(e instanceof Error ? e.message : "Action failed"); }
  }

  async function reactivate(userId: string) {
    const token = getToken();
    if (!token) return;
    try {
      await api.post(`/admin/users/${userId}/reactivate?reason=admin_action`, token);
      setActionMsg("User reactivated."); load();
    } catch (e) { setActionMsg(e instanceof Error ? e.message : "Action failed"); }
  }

  return (
    <>
      <TopBar title="Users" subtitle={data ? `${data.total.toLocaleString()} total accounts` : "Loading…"} />
      {error && <ErrorBanner message={error} />}
      {actionMsg && (
        <div className="mb-4 px-4 py-3 bg-emerald-50 border border-emerald-200 text-emerald-700 text-sm rounded-xl flex justify-between">
          {actionMsg}
          <button onClick={() => setActionMsg(null)}>✕</button>
        </div>
      )}

      <div className="flex flex-wrap gap-3 mb-6">
        <input
          type="text"
          placeholder="Search by email or ID…"
          value={search}
          onChange={e => { setSearch(e.target.value); setPage(1); }}
          className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] placeholder-[#A06A52] focus:outline-none focus:border-[#FF7A33]/60 w-72"
        />
        <label className="flex items-center gap-2 text-sm text-[#A06A52] cursor-pointer">
          <input type="checkbox" checked={includeDeleted} onChange={e => setIncludeDeleted(e.target.checked)} className="rounded" />
          Include suspended
        </label>
      </div>

      <Table>
        <Thead>
          <Th>User ID</Th><Th>Email</Th><Th>Name</Th><Th>Mode</Th><Th>Verified</Th>
          <Th>Plan</Th><Th>Wearable</Th><Th>Joined</Th><Th>Status</Th><Th>Actions</Th>
        </Thead>
        <Tbody>
          {loading ? <LoadingRows cols={10} /> :
           !data || data.items.length === 0 ? <EmptyState label="No users found" /> :
           data.items.map(u => (
            <Tr key={u.id} onClick={() => onSelect(u.id)} className="cursor-pointer">
              <Td muted>{u.id.slice(0, 12)}…</Td>
              <Td>{u.email ?? "—"}</Td>
              <Td>{u.full_name ?? "—"}</Td>
              <Td><Badge label={u.account_mode} /></Td>
              <Td><Badge label={u.email_verified ? "verified" : "unverified"} /></Td>
              <Td><Badge label={u.subscription_tier ?? "free"} /></Td>
              <Td muted>{u.wearable_type ?? "none"}</Td>
              <Td muted>{u.created_at.slice(0, 10)}</Td>
              <Td>{u.deleted_at ? <Badge label="suspended" /> : <Badge label="active" />}</Td>
              <Td>
                {u.deleted_at ? (
                  <button onClick={e => { e.stopPropagation(); reactivate(u.id); }} className="text-xs text-emerald-600 hover:text-emerald-800 font-medium">Reactivate</button>
                ) : (
                  <button onClick={e => { e.stopPropagation(); suspend(u.id); }} className="text-xs text-red-500 hover:text-red-700 font-medium">Suspend</button>
                )}
              </Td>
            </Tr>
          ))}
        </Tbody>
      </Table>

      {data && data.total > 25 && (
        <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]">
          <span>Showing {((page - 1) * 25) + 1}–{Math.min(page * 25, data.total)} of {data.total.toLocaleString()}</span>
          <div className="flex gap-2">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40 hover:bg-[#FFF6F0]">← Prev</button>
            <button onClick={() => setPage(p => p + 1)} disabled={page * 25 >= data.total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40 hover:bg-[#FFF6F0]">Next →</button>
          </div>
        </div>
      )}
    </>
  );
}

// ── Root page — switches between list and detail ──────────────────────────────

function UsersPageInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const selectedId = searchParams.get("id");

  function selectUser(id: string) {
    router.push(`/users?id=${id}`);
  }

  function clearUser() {
    router.push("/users");
  }

  if (selectedId) {
    return <UserDetailView userId={selectedId} onBack={clearUser} />;
  }
  return <UsersListView onSelect={selectUser} />;
}

export default function UsersPage() {
  return (
    <Suspense>
      <UsersPageInner />
    </Suspense>
  );
}
