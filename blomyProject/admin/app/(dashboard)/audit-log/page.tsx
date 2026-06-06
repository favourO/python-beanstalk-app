"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { api, ApiError, getToken, type AuditEventListOut } from "@/lib/api";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { EmptyState, ErrorBanner, LoadingRows } from "@/components/PageShell";
import { Table, Tbody, Td, Th, Thead, Tr } from "@/components/Table";

function fmtDate(value: string) {
  return new Date(value).toLocaleString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function payloadSummary(payload: Record<string, unknown>) {
  const entries = Object.entries(payload ?? {});
  if (entries.length === 0) return "No payload";
  return entries
    .slice(0, 4)
    .map(([key, value]) => `${key}: ${typeof value === "object" ? JSON.stringify(value) : String(value)}`)
    .join(" | ");
}

function Pager({ page, total, pageSize, onPage }: { page: number; total: number; pageSize: number; onPage: (page: number) => void }) {
  const max = Math.max(1, Math.ceil(total / pageSize));
  return (
    <div className="flex items-center justify-between text-[12px] text-[#9E7B6E]">
      <span>Page {page} of {max}</span>
      <div className="flex gap-2">
        <button
          onClick={() => onPage(page - 1)}
          disabled={page <= 1}
          className="rounded-lg border border-[#FFD9C2] px-3 py-1.5 font-semibold text-[#1E0C16] disabled:cursor-not-allowed disabled:opacity-40"
        >
          Previous
        </button>
        <button
          onClick={() => onPage(page + 1)}
          disabled={page >= max}
          className="rounded-lg border border-[#FFD9C2] px-3 py-1.5 font-semibold text-[#1E0C16] disabled:cursor-not-allowed disabled:opacity-40"
        >
          Next
        </button>
      </div>
    </div>
  );
}

export default function AuditLogPage() {
  const router = useRouter();
  const [data, setData] = useState<AuditEventListOut | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [actorId, setActorId] = useState("");
  const [actionPrefix, setActionPrefix] = useState("admin.");

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) {
      router.push("/login");
      return;
    }
    const params = new URLSearchParams({ page: String(page), page_size: "50" });
    if (actorId.trim()) params.set("actor_id", actorId.trim());
    if (actionPrefix.trim()) params.set("action_prefix", actionPrefix.trim());

    setLoading(true);
    setError(null);
    try {
      const res = await api.get<AuditEventListOut>(`/admin/audit-events?${params.toString()}`, token);
      setData(res);
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      setError(e instanceof Error ? e.message : "Failed to load audit events");
    } finally {
      setLoading(false);
    }
  }, [actionPrefix, actorId, page, router]);

  useEffect(() => { load(); }, [load]);

  const stats = useMemo(() => {
    const items = data?.items ?? [];
    const actors = new Set(items.map((item) => item.actor_user_id).filter(Boolean));
    const adminActions = items.filter((item) => item.action.startsWith("admin.")).length;
    const sensitiveReads = items.filter((item) => /health|user|billing|invoice|prediction/i.test(item.action)).length;
    return { actors: actors.size, adminActions, sensitiveReads };
  }, [data]);

  return (
    <main className="space-y-6">
      <TopBar title="Audit Log" subtitle="Trace admin activity, sensitive reads, and operational changes." />

      {error && <ErrorBanner message={error} />}

      <section className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <StatCard label="Events" value={String(data?.total ?? 0)} sub="matching filters" accent />
        <StatCard label="Admin Actions" value={String(stats.adminActions)} sub="loaded page" />
        <StatCard label="Unique Actors" value={String(stats.actors)} sub="loaded page" />
        <StatCard label="Sensitive Events" value={String(stats.sensitiveReads)} sub="loaded page" />
      </section>

      <section className="rounded-2xl border border-[#FFD9C2] bg-white p-4">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-[1fr_1fr_auto]">
          <label className="text-[12px] font-semibold text-[#1E0C16]">
            Actor user ID
            <input
              value={actorId}
              onChange={(event) => { setActorId(event.target.value); setPage(1); }}
              placeholder="Filter by admin/user UUID"
              className="mt-1 w-full rounded-lg border border-[#FFD9C2] px-3 py-2 text-[13px] font-normal outline-none focus:border-[#FF7A33]"
            />
          </label>
          <label className="text-[12px] font-semibold text-[#1E0C16]">
            Action prefix
            <input
              value={actionPrefix}
              onChange={(event) => { setActionPrefix(event.target.value); setPage(1); }}
              placeholder="admin."
              className="mt-1 w-full rounded-lg border border-[#FFD9C2] px-3 py-2 text-[13px] font-normal outline-none focus:border-[#FF7A33]"
            />
          </label>
          <button onClick={load} className="self-end rounded-lg bg-[#FF7A33] px-4 py-2 text-[13px] font-semibold text-white">
            Refresh
          </button>
        </div>
      </section>

      <Table>
        <Thead>
          <Th>Created</Th>
          <Th>Action</Th>
          <Th>Actor</Th>
          <Th>Payload</Th>
          <Th>Event ID</Th>
        </Thead>
        <Tbody>
          {loading ? <LoadingRows cols={5} /> : data?.items.length ? data.items.map((event) => (
            <Tr key={event.id}>
              <Td>{fmtDate(event.created_at)}</Td>
              <Td><Badge label={event.action} /></Td>
              <Td>{event.actor_user_id ? <span className="font-mono text-[11px]">{event.actor_user_id}</span> : "System"}</Td>
              <Td muted><span className="line-clamp-2 max-w-xl break-words">{payloadSummary(event.payload)}</span></Td>
              <Td muted><span className="font-mono text-[11px]">{event.id}</span></Td>
            </Tr>
          )) : <EmptyState label="No audit events match these filters." />}
        </Tbody>
      </Table>

      <Pager page={page} total={data?.total ?? 0} pageSize={data?.page_size ?? 50} onPage={setPage} />
    </main>
  );
}
