"use client";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type ReferralListOut, type GrantListOut } from "@/lib/api";

function fmtDate(value: string | null | undefined) { return value ? value.slice(0, 10) : "-"; }
function shortId(value: string | null | undefined) { if (!value) return "-"; return value.length > 12 ? `${value.slice(0, 12)}...` : value; }

export default function ReferralsPage() {
  const router = useRouter();
  const [referrals, setReferrals] = useState<ReferralListOut | null>(null);
  const [grants, setGrants] = useState<GrantListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState("");
  const [activeOnly, setActiveOnly] = useState(true);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const referralParams = new URLSearchParams({ page: String(page), page_size: "25" });
    if (status) referralParams.set("status", status);
    const grantParams = new URLSearchParams({ page: "1", page_size: "10" });
    if (activeOnly) grantParams.set("active_only", "true");
    try {
      const [refData, grantData] = await Promise.all([
        api.get<ReferralListOut>(`/admin/growth/referrals?${referralParams}`, token),
        api.get<GrantListOut>(`/admin/growth/grants?${grantParams}`, token),
      ]);
      setReferrals(refData); setGrants(grantData);
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load growth data");
    } finally { setLoading(false); }
  }, [router, page, status, activeOnly]);

  useEffect(() => { load(); }, [load]);
  const referralItems = referrals?.items ?? [];
  const grantItems = grants?.items ?? [];
  const qualified = referralItems.filter(r => r.qualified_at || r.status === "qualified").length;

  return (
    <>
      <TopBar title="Referrals" subtitle={referrals ? `${referrals.total.toLocaleString()} referral records` : "Growth and premium grants"} />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Referrals" value={String(referrals?.total ?? 0)} sub="Total" accent />
        <StatCard label="Qualified" value={String(qualified)} sub="Current page" />
        <StatCard label="Premium grants" value={String(grants?.total ?? 0)} sub={activeOnly ? "Active" : "All"} />
        <StatCard label="Grant days" value={String(grantItems.reduce((a, g) => a + g.days_granted, 0))} sub="Shown grants" />
      </div>
      <div className="flex flex-wrap gap-3 mb-5">
        <select value={status} onChange={e => { setStatus(e.target.value); setPage(1); }} className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] focus:outline-none">
          <option value="">All referral statuses</option><option value="pending">Pending</option><option value="qualified">Qualified</option><option value="rewarded">Rewarded</option>
        </select>
        <label className="flex items-center gap-2 text-sm text-[#A06A52] cursor-pointer"><input type="checkbox" checked={activeOnly} onChange={e => setActiveOnly(e.target.checked)} /> Active grants only</label>
      </div>
      <div className="grid grid-cols-1 2xl:grid-cols-3 gap-5">
        <div className="2xl:col-span-2">
          <Table><Thead><Th>Code</Th><Th>Inviter</Th><Th>Invited user</Th><Th>Source</Th><Th>Status</Th><Th>Created</Th><Th>Qualified</Th></Thead>
            <Tbody>{loading ? <LoadingRows cols={7} /> : referralItems.length === 0 ? <EmptyState label="No referral records found" /> : referralItems.map(r => (
              <Tr key={r.id}><Td>{r.referral_code}</Td><Td>{r.inviter_email ?? shortId(r.inviter_user_id)}</Td><Td muted>{shortId(r.invited_user_id)}</Td><Td muted>{r.source ?? "-"}</Td><Td><Badge label={r.status} /></Td><Td muted>{fmtDate(r.created_at)}</Td><Td muted>{fmtDate(r.qualified_at)}</Td></Tr>
            ))}</Tbody>
          </Table>
          {referrals && referrals.total > 25 && <Pager page={page} total={referrals.total} onPage={setPage} />}
        </div>
        <div className="bg-white rounded-2xl border border-[#FFD9C2] p-5">
          <p className="text-[13px] font-bold text-[#1E0C16] mb-4">Premium Grants</p>
          <div className="space-y-3">
            {grantItems.length === 0 ? <p className="text-sm text-[#A06A52]">No grants found.</p> : grantItems.map(g => (
              <div key={g.id} className="border border-[#F5EDE8] rounded-xl p-3">
                <div className="flex justify-between gap-3"><p className="text-[12px] font-semibold text-[#1E0C16] truncate">{g.user_email ?? shortId(g.user_id)}</p><Badge label={g.active ? "active" : "inactive"} /></div>
                <p className="text-[11px] text-[#A06A52] mt-1">{g.days_granted} days · {g.source_type}</p>
                <p className="text-[11px] text-[#A06A52]">{fmtDate(g.starts_at)} to {fmtDate(g.ends_at)}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}

function Pager({ page, total, onPage }: { page: number; total: number; onPage: (next: number) => void }) {
  return <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]"><span>Page {page} · {total.toLocaleString()} total</span><div className="flex gap-2"><button onClick={() => onPage(Math.max(1, page - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Prev</button><button onClick={() => onPage(page + 1)} disabled={page * 25 >= total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Next</button></div></div>;
}
