"use client";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type NotificationListOut } from "@/lib/api";

function fmtDate(value: string | null | undefined) { return value ? value.slice(0, 16).replace("T", " ") : "-"; }
function shortId(value: string) { return value.length > 12 ? `${value.slice(0, 12)}...` : value; }

export default function NotificationsPage() {
  const router = useRouter();
  const [data, setData] = useState<NotificationListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [category, setCategory] = useState("");
  const [status, setStatus] = useState("");

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "25" });
    if (category) params.set("category", category);
    if (status) params.set("notification_status", status);
    try { setData(await api.get<NotificationListOut>(`/admin/notifications?${params}`, token)); }
    catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load notifications");
    } finally { setLoading(false); }
  }, [router, page, category, status]);

  useEffect(() => { load(); }, [load]);
  const items = data?.items ?? [];
  const delivered = items.filter(n => n.delivered_at || n.status === "delivered" || n.status === "sent").length;
  const pending = items.filter(n => !n.delivered_at && n.status !== "failed").length;
  const failed = items.filter(n => n.status === "failed").length;

  return (
    <>
      <TopBar title="Notifications" subtitle={data ? `${data.total.toLocaleString()} notification records` : "Reminder delivery operations"} />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Records" value={String(data?.total ?? 0)} sub="Total" accent />
        <StatCard label="Delivered" value={String(delivered)} sub="Current page" />
        <StatCard label="Pending" value={String(pending)} sub="Current page" />
        <StatCard label="Failed" value={String(failed)} sub="Current page" />
      </div>
      <div className="flex flex-wrap gap-3 mb-5">
        <input value={category} onChange={e => { setCategory(e.target.value); setPage(1); }} placeholder="Category..." className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] placeholder-[#A06A52] focus:outline-none w-56" />
        <select value={status} onChange={e => { setStatus(e.target.value); setPage(1); }} className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] focus:outline-none">
          <option value="">All statuses</option><option value="pending">Pending</option><option value="sent">Sent</option><option value="delivered">Delivered</option><option value="failed">Failed</option>
        </select>
      </div>
      <Table>
        <Thead><Th>Type</Th><Th>Category</Th><Th>Title</Th><Th>Status</Th><Th>Channel</Th><Th>Priority</Th><Th>Attempts</Th><Th>Scheduled</Th><Th>Delivered</Th><Th>User</Th></Thead>
        <Tbody>{loading ? <LoadingRows cols={10} /> : items.length === 0 ? <EmptyState label="No notification records found" /> : items.map(n => (
          <Tr key={n.id}>
            <Td>{n.notification_type}</Td><Td><Badge label={n.category} /></Td><Td>{n.title}</Td><Td><Badge label={n.status} /></Td><Td muted>{n.channel}</Td><Td muted>{n.priority}</Td><Td>{n.delivery_attempts}</Td><Td muted>{fmtDate(n.scheduled_for)}</Td><Td muted>{fmtDate(n.delivered_at)}</Td><Td muted>{shortId(n.user_id)}</Td>
          </Tr>
        ))}</Tbody>
      </Table>
      {data && data.total > 25 && <Pager page={page} total={data.total} onPage={setPage} />}
    </>
  );
}

function Pager({ page, total, onPage }: { page: number; total: number; onPage: (next: number) => void }) {
  return <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]"><span>Page {page} · {total.toLocaleString()} total</span><div className="flex gap-2"><button onClick={() => onPage(Math.max(1, page - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Prev</button><button onClick={() => onPage(page + 1)} disabled={page * 25 >= total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Next</button></div></div>;
}
