"use client";
import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { api, getToken, ApiError, type UserItem, type UserListOut } from "@/lib/api";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";

export default function UsersPage() {
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
      const res = await api.get<UserListOut>(`/admin/users?${params}`, token);
      setData(res);
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
    if (!confirm("Suspend this user? They will lose access immediately.")) return;
    try {
      await api.post(`/admin/users/${userId}/suspend?reason=admin_action`, token);
      setActionMsg("User suspended.");
      load();
    } catch (e) {
      setActionMsg(e instanceof Error ? e.message : "Action failed");
    }
  }

  async function reactivate(userId: string) {
    const token = getToken();
    if (!token) return;
    try {
      await api.post(`/admin/users/${userId}/reactivate?reason=admin_action`, token);
      setActionMsg("User reactivated.");
      load();
    } catch (e) {
      setActionMsg(e instanceof Error ? e.message : "Action failed");
    }
  }

  return (
    <>
      <TopBar title="Users" subtitle={data ? `${data.total.toLocaleString()} total accounts` : "Loading…"} />
      {error && <ErrorBanner message={error} />}
      {actionMsg && (
        <div className="mb-4 px-4 py-3 bg-emerald-50 border border-emerald-200 text-emerald-700 text-sm rounded-xl flex justify-between">
          {actionMsg}
          <button onClick={() => setActionMsg(null)} className="text-emerald-500 hover:text-emerald-700">✕</button>
        </div>
      )}

      {/* Filters */}
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
            <Tr key={u.id}>
              <Td muted>{u.id.slice(0, 12)}…</Td>
              <Td>{u.email ?? "—"}</Td>
              <Td>{u.full_name ?? "—"}</Td>
              <Td><Badge label={u.account_mode} /></Td>
              <Td><Badge label={u.email_verified ? "verified" : "unverified"} /></Td>
              <Td><Badge label={u.subscription_tier ?? "free"} /></Td>
              <Td muted>{u.wearable_type ?? "none"}</Td>
              <Td muted>{u.created_at.slice(0, 10)}</Td>
              <Td>{u.deleted_at ? <Badge label="deleted" /> : <Badge label="active" />}</Td>
              <Td>
                {u.deleted_at ? (
                  <button onClick={() => reactivate(u.id)} className="text-xs text-emerald-600 hover:text-emerald-800 font-medium">Reactivate</button>
                ) : (
                  <button onClick={() => suspend(u.id)} className="text-xs text-red-500 hover:text-red-700 font-medium">Suspend</button>
                )}
              </Td>
            </Tr>
          ))}
        </Tbody>
      </Table>

      {/* Pagination */}
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
