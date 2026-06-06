"use client";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type PredictionListOut } from "@/lib/api";

function fmtDate(value: string | null | undefined) {
  return value ? value.slice(0, 16).replace("T", " ") : "-";
}

function shortId(value: string) {
  return value.length > 14 ? `${value.slice(0, 14)}...` : value;
}

export default function PredictionsPage() {
  const router = useRouter();
  const [data, setData] = useState<PredictionListOut | null>(null);
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
    try {
      setData(await api.get<PredictionListOut>(`/admin/predictions?${params}`, token));
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load predictions");
    } finally { setLoading(false); }
  }, [router, page, userId]);

  useEffect(() => { load(); }, [load]);
  const items = data?.items ?? [];
  const avgConfidence = items.length ? items.reduce((a, p) => a + p.confidence, 0) / items.length : 0;
  const flagged = items.filter(p => p.warning_flags.length > 0).length;

  return (
    <>
      <TopBar title="Predictions" subtitle={data ? `${data.total.toLocaleString()} prediction snapshots` : "Cycle prediction operations"} />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Snapshots" value={String(data?.total ?? 0)} sub="Total records" accent />
        <StatCard label="Avg confidence" value={items.length ? `${Math.round(avgConfidence * 100)}%` : "-"} sub="Current page" />
        <StatCard label="Flagged" value={String(flagged)} sub="Warnings on page" />
        <StatCard label="Model versions" value={String(new Set(items.map(i => i.model_version ?? "unknown")).size)} sub="Current page" />
      </div>
      <div className="flex flex-wrap gap-3 mb-5">
        <input value={userId} onChange={e => { setUserId(e.target.value); setPage(1); }} placeholder="Filter by user ID..." className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] placeholder-[#A06A52] focus:outline-none focus:border-[#FF7A33]/60 w-80" />
      </div>
      <Table>
        <Thead><Th>ID</Th><Th>User</Th><Th>Phase</Th><Th>Confidence</Th><Th>Source</Th><Th>Models</Th><Th>Warnings</Th><Th>Generated</Th></Thead>
        <Tbody>{loading ? <LoadingRows cols={8} /> : items.length === 0 ? <EmptyState label="No prediction snapshots found" /> : items.map(p => (
          <Tr key={p.id}>
            <Td muted>{shortId(p.id)}</Td><Td>{p.user_email ?? shortId(p.user_id)}</Td><Td><Badge label={p.current_phase || "unknown"} /></Td>
            <Td>{Math.round(p.confidence * 100)}%</Td><Td muted>{p.source}</Td><Td muted>{p.models_used.join(", ") || "-"}</Td>
            <Td>{p.warning_flags.length ? <Badge label={`${p.warning_flags.length} warning${p.warning_flags.length === 1 ? "" : "s"}`} /> : <span className="text-[#A06A52]">-</span>}</Td>
            <Td muted>{fmtDate(p.generated_at)}</Td>
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
