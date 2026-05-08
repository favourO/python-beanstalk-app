"use client";
import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { api, getToken, ApiError, type InvoiceListOut } from "@/lib/api";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";

export default function BillingPage() {
  const router = useRouter();
  const [data, setData] = useState<InvoiceListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("");
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "25" });
    if (statusFilter) params.set("status", statusFilter);
    try {
      setData(await api.get<InvoiceListOut>(`/admin/billing/invoices?${params}`, token));
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, [router, page, statusFilter]);

  useEffect(() => { load(); }, [load]);

  const items = data?.items ?? [];
  const collected = items.filter(i => i.status === "paid").reduce((a, i) => a + i.total, 0);
  const stripeTotal = items.filter(i => i.provider === "stripe" || i.provider === "Stripe").reduce((a, i) => a + i.total, 0);
  const flwTotal = items.filter(i => i.provider === "flutterwave" || i.provider === "Flutterwave").reduce((a, i) => a + i.total, 0);

  return (
    <>
      <TopBar title="Billing" subtitle="Invoices across Stripe and Flutterwave" />
      {error && <ErrorBanner message={error} />}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Collected (page)"  value={`£${collected.toFixed(2)}`}   sub="Paid invoices" accent />
        <StatCard label="Open invoices"     value={String(items.filter(i => i.status === "open").length)} sub="Awaiting payment" />
        <StatCard label="Stripe (page)"     value={`£${stripeTotal.toFixed(2)}`} sub="Stripe invoices" />
        <StatCard label="Flutterwave (pg)"  value={`£${flwTotal.toFixed(2)}`}    sub="FLW invoices" />
      </div>

      <div className="flex gap-3 mb-5">
        <select onChange={e => { setStatusFilter(e.target.value); setPage(1); }}
          className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#1E0C16] focus:outline-none">
          <option value="">All statuses</option>
          <option value="paid">Paid</option>
          <option value="open">Open</option>
          <option value="draft">Draft</option>
          <option value="void">Void</option>
        </select>
      </div>

      <Table>
        <Thead>
          <Th>Invoice ID</Th><Th>User</Th><Th>Provider Invoice</Th>
          <Th>Provider</Th><Th>Amount</Th><Th>Currency</Th><Th>Status</Th><Th>Date</Th>
        </Thead>
        <Tbody>
          {loading ? <LoadingRows cols={8} /> :
           items.length === 0 ? <EmptyState label="No invoices found" /> :
           items.map(inv => (
            <Tr key={inv.id}>
              <Td muted>{inv.id.slice(0, 14)}…</Td>
              <Td>{inv.user_email ?? "—"}</Td>
              <Td muted>{inv.provider_invoice_id ?? "—"}</Td>
              <Td>{inv.provider ? <Badge label={inv.provider} /> : <span className="text-[#A06A52] text-[12px]">—</span>}</Td>
              <Td>{inv.total > 0 ? <span className="font-medium">{`£${inv.total.toFixed(2)}`}</span> : <span className="text-[#A06A52]">—</span>}</Td>
              <Td muted>{inv.currency}</Td>
              <Td><Badge label={inv.status} /></Td>
              <Td muted>{inv.created_at.slice(0, 10)}</Td>
            </Tr>
          ))}
        </Tbody>
      </Table>

      {data && data.total > 25 && (
        <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]">
          <span>Page {page} · {data.total.toLocaleString()} total</span>
          <div className="flex gap-2">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">← Prev</button>
            <button onClick={() => setPage(p => p + 1)} disabled={page * 25 >= data.total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Next →</button>
          </div>
        </div>
      )}
    </>
  );
}
