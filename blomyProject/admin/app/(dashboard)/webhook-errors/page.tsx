"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api, getToken, ApiError, type FlwErrorListOut, type StripeErrorListOut } from "@/lib/api";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";

type Tab = "stripe" | "flutterwave";

export default function WebhookErrorsPage() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("stripe");
  const [flwData, setFlwData] = useState<FlwErrorListOut | null>(null);
  const [stripeData, setStripeData] = useState<StripeErrorListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    Promise.all([
      api.get<StripeErrorListOut>("/admin/billing/webhook-errors/stripe?limit=100", token),
      api.get<FlwErrorListOut>("/admin/billing/webhook-errors/flutterwave?limit=100", token),
    ])
      .then(([sd, fd]) => { setStripeData(sd); setFlwData(fd); })
      .catch(e => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
        else setError(e instanceof Error ? e.message : "Failed to load");
      })
      .finally(() => setLoading(false));
  }, [router]);

  const stripeSigMissing = (stripeData?.items ?? []).filter(e => !e.signature_present).length;
  const flwSigMissing = (flwData?.items ?? []).filter(e => !e.signature_present).length;
  const flwLegacyHash = (flwData?.items ?? []).filter(e => e.legacy_hash_present).length;

  return (
    <>
      <TopBar title="Webhook Errors" subtitle="Payment provider webhook delivery failures" />
      {error && <ErrorBanner message={error} />}

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
        <div className="bg-white rounded-xl border border-[#FFD9C2] px-4 py-3">
          <p className="text-[11px] uppercase tracking-wider text-[#A06A52] mb-1">Stripe errors</p>
          <p className="text-2xl font-semibold text-[#1E0C16]">{loading ? "—" : stripeData?.total ?? 0}</p>
        </div>
        <div className="bg-white rounded-xl border border-[#FFD9C2] px-4 py-3">
          <p className="text-[11px] uppercase tracking-wider text-[#A06A52] mb-1">Stripe sig missing</p>
          <p className="text-2xl font-semibold text-red-600">{loading ? "—" : stripeSigMissing}</p>
        </div>
        <div className="bg-white rounded-xl border border-[#FFD9C2] px-4 py-3">
          <p className="text-[11px] uppercase tracking-wider text-[#A06A52] mb-1">FLW errors</p>
          <p className="text-2xl font-semibold text-[#1E0C16]">{loading ? "—" : flwData?.total ?? 0}</p>
        </div>
        <div className="bg-white rounded-xl border border-[#FFD9C2] px-4 py-3">
          <p className="text-[11px] uppercase tracking-wider text-[#A06A52] mb-1">FLW legacy hash</p>
          <p className="text-2xl font-semibold text-amber-600">{loading ? "—" : flwLegacyHash}</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-5 bg-white border border-[#FFD9C2] rounded-xl p-1 w-fit">
        {(["stripe", "flutterwave"] as Tab[]).map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${tab === t ? "bg-[#FF7A33] text-white" : "text-[#A06A52] hover:text-[#1E0C16]"}`}
          >
            {t === "stripe" ? "Stripe" : "Flutterwave"}
            {!loading && (
              <span className={`ml-2 text-[11px] px-1.5 py-0.5 rounded-full ${tab === t ? "bg-white/20" : "bg-[#FFD9C2]"}`}>
                {t === "stripe" ? (stripeData?.total ?? 0) : (flwData?.total ?? 0)}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Stripe errors table */}
      {tab === "stripe" && (
        <Table>
          <Thead>
            <Th>ID</Th><Th>Event type</Th><Th>Stripe Event ID</Th>
            <Th>Category</Th><Th>Sig</Th><Th>Error</Th><Th>Timestamp</Th>
          </Thead>
          <Tbody>
            {loading ? <LoadingRows cols={7} /> :
             !stripeData || stripeData.items.length === 0 ? <EmptyState label="No Stripe webhook errors recorded" /> :
             stripeData.items.map(e => (
              <Tr key={e.id}>
                <Td muted>{e.id.slice(0, 10)}…</Td>
                <Td><code className="text-[12px] bg-indigo-50 text-indigo-600 px-1.5 py-0.5 rounded">{e.event_type ?? "—"}</code></Td>
                <Td muted>{e.stripe_event_id ?? "—"}</Td>
                <Td><Badge label={e.error_category} /></Td>
                <Td>{e.signature_present ? <Badge label="verified" /> : <Badge label="canceled" />}</Td>
                <Td><span className="text-[12px] text-[#3D1F2E] leading-relaxed line-clamp-2">{e.error_message}</span></Td>
                <Td muted>{e.created_at.slice(0, 19).replace("T", " ")}</Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
      )}

      {/* Flutterwave errors table */}
      {tab === "flutterwave" && (
        <Table>
          <Thead>
            <Th>ID</Th><Th>Event type</Th><Th>Transaction ID</Th>
            <Th>User ID</Th><Th>Sig</Th><Th>Legacy hash</Th><Th>Error</Th><Th>Timestamp</Th>
          </Thead>
          <Tbody>
            {loading ? <LoadingRows cols={8} /> :
             !flwData || flwData.items.length === 0 ? <EmptyState label="No Flutterwave webhook errors recorded" /> :
             flwData.items.map(e => (
              <Tr key={e.id}>
                <Td muted>{e.id.slice(0, 10)}…</Td>
                <Td><code className="text-[12px] bg-yellow-50 text-yellow-700 px-1.5 py-0.5 rounded">{e.event_type ?? "—"}</code></Td>
                <Td muted>{e.transaction_id ?? "—"}</Td>
                <Td muted>{e.user_id ?? "—"}</Td>
                <Td>{e.signature_present ? <Badge label="verified" /> : <Badge label="canceled" />}</Td>
                <Td>{e.legacy_hash_present ? <Badge label="open" /> : <span className="text-[#A06A52] text-[12px]">—</span>}</Td>
                <Td><span className="text-[12px] text-[#3D1F2E] leading-relaxed line-clamp-2">{e.error_message}</span></Td>
                <Td muted>{e.created_at.slice(0, 19).replace("T", " ")}</Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
      )}

      <div className="mt-6 p-4 bg-white rounded-2xl border border-[#FFD9C2]">
        <p className="text-[12px] font-semibold text-[#1E0C16] mb-1">Resolution guidance</p>
        <p className="text-[12px] font-light text-[#A06A52] leading-relaxed">
          <strong>Signature errors:</strong> investigate for potential spoofed deliveries. Rotate webhook secrets if suspicious.
          <span className="mx-2">·</span>
          <strong>Processing errors:</strong> usually a tx_ref/user_id mismatch — verify the billing catalog configuration.
          <span className="mx-2">·</span>
          <strong>Legacy hash (FLW):</strong> provider is using the old verification method — update the Flutterwave dashboard.
        </p>
      </div>
    </>
  );
}
