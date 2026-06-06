"use client";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type AiThreadListOut } from "@/lib/api";

function fmtDate(value: string | null | undefined) { return value ? value.slice(0, 16).replace("T", " ") : "-"; }
function shortId(value: string) { return value.length > 14 ? `${value.slice(0, 14)}...` : value; }

export default function AiThreadsPage() {
  const router = useRouter();
  const [data, setData] = useState<AiThreadListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [userId, setUserId] = useState("");

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "25" });
    if (userId.trim()) params.set("user_id", userId.trim());
    try { setData(await api.get<AiThreadListOut>(`/admin/ai/threads?${params}`, token)); }
    catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load AI threads");
    } finally { setLoading(false); }
  }, [router, page, userId]);

  useEffect(() => { load(); }, [load]);
  const items = data?.items ?? [];
  const messages = items.reduce((a, t) => a + t.message_count, 0);
  const activeUsers = new Set(items.map(t => t.user_id)).size;

  return (
    <>
      <TopBar title="AI Threads" subtitle={data ? `${data.total.toLocaleString()} Vyla AI conversations` : "Vyla AI operations"} />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Threads" value={String(data?.total ?? 0)} sub="Total" accent />
        <StatCard label="Messages" value={messages.toLocaleString()} sub="Current page" />
        <StatCard label="Users" value={String(activeUsers)} sub="Current page" />
        <StatCard label="Avg messages" value={items.length ? (messages / items.length).toFixed(1) : "-"} sub="Per thread" />
      </div>
      <div className="flex gap-3 mb-5">
        <input value={userId} onChange={e => { setUserId(e.target.value); setPage(1); }} placeholder="Filter by user ID..." className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] placeholder-[#A06A52] focus:outline-none focus:border-[#FF7A33]/60 w-80" />
      </div>
      <Table>
        <Thead><Th>Thread</Th><Th>User</Th><Th>Title</Th><Th>Messages</Th><Th>Created</Th><Th>Updated</Th></Thead>
        <Tbody>{loading ? <LoadingRows cols={6} /> : items.length === 0 ? <EmptyState label="No AI threads found" /> : items.map(t => (
          <Tr key={t.id}>
            <Td muted>{shortId(t.id)}</Td><Td>{t.user_email ?? shortId(t.user_id)}</Td><Td>{t.title ?? "Untitled conversation"}</Td><Td>{t.message_count}</Td><Td muted>{fmtDate(t.created_at)}</Td><Td muted>{fmtDate(t.updated_at)}</Td>
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
