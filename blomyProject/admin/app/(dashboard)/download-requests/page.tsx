"use client";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type DownloadRequestListOut } from "@/lib/api";

function fmtDate(v: string) { return v.slice(0, 16).replace("T", " "); }

export default function DownloadRequestsPage() {
  const router = useRouter();
  const [data, setData] = useState<DownloadRequestListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "50" });
    try { setData(await api.get<DownloadRequestListOut>(`/admin/download-requests?${params}`, token)); }
    catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load download requests");
    } finally { setLoading(false); }
  }, [router, page]);

  useEffect(() => { load(); }, [load]);

  const items = data?.items ?? [];

  const todayCount = items.filter(r => r.created_at.startsWith(new Date().toISOString().slice(0, 10))).length;

  return (
    <>
      <TopBar
        title="Download Requests"
        subtitle={data ? `${data.total.toLocaleString()} people have requested the download link` : "Download link request trail"}
      />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-2 gap-4 mb-8">
        <StatCard label="Total requests" value={String(data?.total ?? 0)} sub="All time" accent />
        <StatCard label="Today" value={String(todayCount)} sub="Current page" />
      </div>
      <Table>
        <Thead><Th>Email</Th><Th>Requested at</Th></Thead>
        <Tbody>
          {loading ? <LoadingRows cols={2} /> : items.length === 0 ? <EmptyState label="No download requests yet" /> : items.map(r => (
            <Tr key={r.id}>
              <Td>{r.email}</Td>
              <Td muted>{fmtDate(r.created_at)}</Td>
            </Tr>
          ))}
        </Tbody>
      </Table>
      {data && data.total > 50 && <Pager page={page} total={data.total} onPage={setPage} />}
    </>
  );
}

function Pager({ page, total, onPage }: { page: number; total: number; onPage: (n: number) => void }) {
  return (
    <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]">
      <span>Page {page} · {total.toLocaleString()} total</span>
      <div className="flex gap-2">
        <button onClick={() => onPage(Math.max(1, page - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Prev</button>
        <button onClick={() => onPage(page + 1)} disabled={page * 50 >= total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Next</button>
      </div>
    </div>
  );
}
