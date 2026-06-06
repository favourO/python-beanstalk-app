"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useRouter } from "next/navigation";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { ApiError, getToken, wearableAdminApi, type WearableAnalyticsOut, type WearableOrder, type WearableOrderListOut } from "@/lib/api";
import DispatchModal from "@/components/wearable/DispatchModal";
import ShipmentStatusBadge from "@/components/wearable/ShipmentStatusBadge";
import OrderStatusTimeline from "@/components/wearable/OrderStatusTimeline";
import { formatDate, labelStatus } from "@/components/wearable/status";

const pageSize = 10;

export default function WearableOrdersPage() {
  const router = useRouter();
  const [data, setData] = useState<WearableOrderListOut | null>(null);
  const [analytics, setAnalytics] = useState<WearableAnalyticsOut | null>(null);
  const [statuses, setStatuses] = useState<string[]>([]);
  const [paymentStatuses, setPaymentStatuses] = useState<string[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [paymentFilter, setPaymentFilter] = useState("");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<WearableOrder | null>(null);
  const [editing, setEditing] = useState<WearableOrder | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [modalError, setModalError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) {
      router.push("/login");
      return;
    }
    setLoading(true);
    setError(null);
    const params = new URLSearchParams({
      limit: String(pageSize),
      offset: String((page - 1) * pageSize),
    });
    if (statusFilter) params.set("fulfillment_status", statusFilter);
    try {
      const [orders, options, metrics] = await Promise.all([
        wearableAdminApi.getOrders(token, params),
        wearableAdminApi.getStatusOptions(token),
        wearableAdminApi.getAnalytics(token),
      ]);
      setData(orders);
      setStatuses(options.fulfillment_statuses);
      setPaymentStatuses(options.payment_statuses);
      setAnalytics(metrics);
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        router.push("/login");
      } else {
        setError(e instanceof Error ? e.message : "Failed to load wearable orders");
      }
    } finally {
      setLoading(false);
    }
  }, [page, router, statusFilter]);

  useEffect(() => {
    load();
  }, [load]);

  const orders = data?.orders ?? [];
  const visibleOrders = useMemo(() => {
    const term = query.trim().toLowerCase();
    return orders.filter((order) => {
      const matchesPayment = !paymentFilter || order.payment_status === paymentFilter;
      if (!matchesPayment) return false;
      if (!term) return true;
      const haystack = [
        order.order_number,
        order.wearable_name,
        order.wearable_sku,
        order.payment_status,
        order.fulfillment_status,
        order.tracking_number,
        order.courier,
        order.shipping_address.full_name,
        order.shipping_address.phone,
        order.shipping_address.postcode,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(term);
    });
  }, [orders, paymentFilter, query]);

  const metrics = useMemo(() => {
    const counts = analytics?.fulfillment_counts ?? {};
    return {
      total: analytics?.total_orders ?? data?.total ?? 0,
      pending: counts.pending ?? analytics?.pending_orders ?? 0,
      processing: counts.processing ?? 0,
      dispatched: (counts.dispatched ?? 0) + (counts.out_for_delivery ?? 0),
      delivered: counts.delivered ?? analytics?.delivered_orders ?? 0,
    };
  }, [analytics, data?.total]);

  async function saveDispatch(payload: Parameters<typeof wearableAdminApi.updateStatus>[2]) {
    if (!editing) return;
    const token = getToken();
    if (!token) {
      router.push("/login");
      return;
    }
    setSaving(true);
    setModalError(null);
    try {
      const updated = await wearableAdminApi.updateStatus(token, editing.id, payload);
      setData((current) => current ? {
        ...current,
        orders: current.orders.map((order) => order.id === updated.id ? updated : order),
      } : current);
      setEditing(null);
      setSelected((current) => current?.id === updated.id || editing.id === updated.id ? updated : current);
      router.refresh();
      await load();
    } catch (e) {
      setModalError(e instanceof Error ? e.message : "Failed to update order");
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="font-serif text-4xl font-semibold tracking-tight text-[#10232B]">Wearable Orders</h1>
          <p className="mt-3 text-base text-[#6E5750]">Manage and fulfil Vyla Wearable orders</p>
        </div>
        <div className="flex items-center gap-3">
          <button className="grid h-12 w-12 place-items-center rounded-xl border border-[#FFD9C2] bg-white text-[#6D4A3C] shadow-sm">
            <SearchIcon />
          </button>
          <button className="relative inline-flex h-12 items-center gap-2 rounded-xl border border-[#FFD9C2] bg-white px-5 text-sm font-semibold text-[#6D4A3C] shadow-sm">
            <span className="absolute -top-2 right-3 grid h-6 min-w-6 place-items-center rounded-full bg-[#FF6B2F] px-1 text-xs text-white">
              {metrics.pending}
            </span>
            <ExportIcon />
            Export
          </button>
          <button
            onClick={() => setError("Manual order creation is not available yet. Wearable orders are created after a successful user checkout.")}
            className="inline-flex h-12 items-center gap-2 rounded-xl bg-[#FF6B2F] px-5 text-sm font-semibold text-white shadow-[0_10px_24px_rgba(255,107,47,0.18)]"
          >
            <PlusIcon />
            Create Order
          </button>
        </div>
      </div>

      {error && <ErrorBanner message={error} />}

      <div className="mb-7 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
        <MetricCard label="Total Orders" value={metrics.total} tone="green" icon={<PackageIcon />} sub="Live total" />
        <MetricCard label="Pending" value={metrics.pending} tone="orange" icon={<ClockIcon />} sub="Awaiting fulfilment" />
        <MetricCard label="Processing" value={metrics.processing} tone="orange" icon={<PackageIcon />} sub="Being prepared" />
        <MetricCard label="Dispatched" value={metrics.dispatched} tone="green" icon={<TruckIcon />} sub="In transit" />
        <MetricCard label="Delivered" value={metrics.delivered} tone="green" icon={<CheckCircleIcon />} sub="Completed" />
      </div>

      <div className="overflow-hidden rounded-2xl border border-[#FFD9C2] bg-white shadow-[0_16px_45px_rgba(255,107,47,0.04)]">
        <div className="grid gap-4 border-b border-[#FFE2D7] p-5 xl:grid-cols-[1.3fr_220px_220px_220px_120px]">
          <label className="relative block">
            <span className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#8B7066]">
              <SearchIcon />
            </span>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search by order number, customer or tracking..."
              className="h-12 w-full rounded-xl border border-[#FFD9C2] bg-white pl-12 pr-4 text-sm text-[#2D170F] outline-none transition focus:border-[#FF9D72] focus:ring-4 focus:ring-[#FF6B2F]/10"
            />
          </label>
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(1);
            }}
            className="h-12 rounded-xl border border-[#FFD9C2] bg-white px-4 text-sm font-medium text-[#6D4A3C] outline-none"
          >
            <option value="">Status: All</option>
            {statuses.map((item) => (
              <option key={item} value={item}>{labelStatus(item)}</option>
            ))}
          </select>
          <select
            value={paymentFilter}
            onChange={(e) => setPaymentFilter(e.target.value)}
            className="h-12 rounded-xl border border-[#FFD9C2] bg-white px-4 text-sm font-medium text-[#6D4A3C] outline-none"
          >
            <option value="">Payment: All</option>
            {paymentStatuses.map((item) => (
              <option key={item} value={item}>{labelStatus(item)}</option>
            ))}
          </select>
          <button className="inline-flex h-12 items-center justify-between rounded-xl border border-[#FFD9C2] bg-white px-4 text-sm font-medium text-[#6D4A3C]">
            Date range
            <CalendarIcon />
          </button>
          <button className="inline-flex h-12 items-center justify-center gap-2 rounded-xl border border-[#FFD9C2] bg-white px-4 text-sm font-semibold text-[#6D4A3C]">
            <FilterIcon />
            Filters
          </button>
        </div>

        <Table>
          <Thead>
            <Th>Order #</Th>
            <Th>Customer</Th>
            <Th>Plan</Th>
            <Th>Payment</Th>
            <Th>Amount</Th>
            <Th>Status</Th>
            <Th>Tracking</Th>
            <Th>Order Date</Th>
            <Th>Actions</Th>
          </Thead>
          <Tbody>
            {loading ? (
              <LoadingRows cols={9} />
            ) : visibleOrders.length === 0 ? (
              <EmptyState label="No wearable orders found" />
            ) : (
              visibleOrders.map((order) => (
                <Tr key={order.id} onClick={() => setSelected(order)} className="cursor-pointer">
                  <Td>
                    <span className="font-semibold">{order.order_number}</span>
                  </Td>
                  <Td>
                    <div className="font-semibold">{customerName(order)}</div>
                    <div className="mt-1 text-xs text-[#8B7066]">{customerDetail(order)}</div>
                  </Td>
                  <Td>
                    <div className="inline-flex items-center gap-2">
                      <span className="grid h-8 w-8 place-items-center rounded-full bg-[#FFF1EA] text-[#FF6B2F]">
                        <PackageIcon small />
                      </span>
                      <div>
                        <div className="font-semibold">Wearable purchase</div>
                        <div className="mt-1 text-xs text-[#8B7066]">{order.wearable_sku}</div>
                      </div>
                    </div>
                  </Td>
                  <Td><ShipmentStatusBadge status={order.payment_status} /></Td>
                  <Td><span className="font-semibold">{order.display_price}</span></Td>
                  <Td><ShipmentStatusBadge status={order.fulfillment_status} /></Td>
                  <Td>
                    {order.tracking_url ? (
                      <a
                        href={order.tracking_url}
                        target="_blank"
                        rel="noreferrer"
                        onClick={(e) => e.stopPropagation()}
                        className="font-semibold text-[#2F6FBD] underline decoration-[#2F6FBD]/30 underline-offset-2"
                      >
                        {order.tracking_number || "Open tracking"}
                      </a>
                    ) : (
                      <span className="text-[#8B7066]">—</span>
                    )}
                  </Td>
                  <Td>
                    <div>{formatDate(order.created_at).split(" ")[0]}</div>
                    <div className="mt-1 text-xs text-[#8B7066]">{formatDate(order.created_at).split(" ")[1] ?? ""}</div>
                  </Td>
                  <Td>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setEditing(order);
                      }}
                      className="grid h-9 w-9 place-items-center rounded-full border border-[#FFD9C2] text-[#8B7066] hover:text-[#FF6B2F]"
                      aria-label={`Update ${order.order_number}`}
                    >
                      <MoreIcon />
                    </button>
                  </Td>
                </Tr>
              ))
            )}
          </Tbody>
        </Table>

        {data && data.total > 0 && (
          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-[#FFE2D7] px-5 py-4 text-sm text-[#8B7066]">
            <span>
              Showing {(data.offset + 1).toLocaleString()} to {Math.min(data.offset + data.limit, data.total).toLocaleString()} of {data.total.toLocaleString()} orders
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
                className="grid h-9 w-9 place-items-center rounded-lg border border-[#FFD9C2] disabled:opacity-40"
              >
                ‹
              </button>
              <span className="grid h-9 min-w-9 place-items-center rounded-lg bg-[#FFEFE6] px-3 font-semibold text-[#FF6B2F]">{page}</span>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={page * pageSize >= data.total}
                className="grid h-9 w-9 place-items-center rounded-lg border border-[#FFD9C2] disabled:opacity-40"
              >
                ›
              </button>
              <span className="ml-4">Rows per page: {pageSize}</span>
            </div>
          </div>
        )}
      </div>

      {selected && (
        <div className="mt-5 rounded-2xl border border-[#FFD9C2] bg-white p-5">
          <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
            <div>
              <p className="font-serif text-2xl font-semibold text-[#10232B]">{selected.order_number}</p>
              <p className="mt-1 text-sm text-[#8B7066]">{customerName(selected)} · {customerAddress(selected)}</p>
            </div>
            <div className="flex items-center gap-2">
              <ShipmentStatusBadge status={selected.payment_status} />
              <ShipmentStatusBadge status={selected.fulfillment_status} />
            </div>
          </div>
          <div className="grid gap-5 lg:grid-cols-[1fr_1.2fr]">
            <div className="rounded-xl bg-[#FFF8F3] p-4 text-sm text-[#2D170F]">
              <p><span className="text-[#8B7066]">Wearable:</span> {selected.wearable_name}</p>
              <p className="mt-2"><span className="text-[#8B7066]">Amount:</span> {selected.display_price}</p>
              <p className="mt-2"><span className="text-[#8B7066]">Courier:</span> {selected.courier ?? "Not assigned"}</p>
              <p className="mt-2"><span className="text-[#8B7066]">Tracking:</span> {selected.tracking_number ?? "Not added"}</p>
              <button onClick={() => setEditing(selected)} className="mt-4 rounded-lg bg-[#FF6B2F] px-4 py-2 text-sm font-semibold text-white">
                Update dispatch
              </button>
            </div>
            <OrderStatusTimeline entries={selected.timeline} />
          </div>
        </div>
      )}

      <DispatchModal order={editing} statuses={statuses} saving={saving} error={modalError} onClose={() => setEditing(null)} onSave={saveDispatch} />
    </>
  );
}

function MetricCard({ label, value, sub, icon, tone }: { label: string; value: number; sub: string; icon: ReactNode; tone: "green" | "orange" }) {
  return (
    <div className="rounded-2xl border border-[#FFD9C2] bg-white p-5 shadow-[0_14px_35px_rgba(255,107,47,0.04)]">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-semibold text-[#5F4B45]">{label}</p>
          <p className="mt-4 text-3xl font-semibold tracking-tight text-[#10232B]">{value.toLocaleString()}</p>
        </div>
        <span className="grid h-14 w-14 place-items-center rounded-2xl bg-[#FFF1EA] text-[#FF6B2F]">{icon}</span>
      </div>
      <p className={`mt-4 text-sm font-semibold ${tone === "green" ? "text-[#2E9D46]" : "text-[#FF6B2F]"}`}>
        ↗ {sub}
      </p>
    </div>
  );
}

function customerName(order: WearableOrder) {
  return order.shipping_address.full_name || "Customer";
}

function customerDetail(order: WearableOrder) {
  return order.shipping_address.phone || order.shipping_address.postcode || "No contact on order";
}

function customerAddress(order: WearableOrder) {
  return [
    order.shipping_address.line1,
    order.shipping_address.city,
    order.shipping_address.postcode,
    order.shipping_address.country,
  ].filter(Boolean).join(", ") || "No shipping address";
}

function SvgIcon({ children, small = false }: { children: ReactNode; small?: boolean }) {
  return (
    <svg
      width={small ? 16 : 20}
      height={small ? 16 : 20}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

function SearchIcon() {
  return (
    <SvgIcon>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </SvgIcon>
  );
}

function ExportIcon() {
  return (
    <SvgIcon>
      <path d="M12 3v11" />
      <path d="m8 10 4 4 4-4" />
      <path d="M5 19h14" />
    </SvgIcon>
  );
}

function PlusIcon() {
  return (
    <SvgIcon>
      <path d="M12 5v14" />
      <path d="M5 12h14" />
    </SvgIcon>
  );
}

function PackageIcon({ small = false }: { small?: boolean }) {
  return (
    <SvgIcon small={small}>
      <path d="m12 3 8 4.5v9L12 21l-8-4.5v-9L12 3Z" />
      <path d="m4 7.5 8 4.5 8-4.5" />
      <path d="M12 12v9" />
    </SvgIcon>
  );
}

function ClockIcon() {
  return (
    <SvgIcon>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </SvgIcon>
  );
}

function TruckIcon() {
  return (
    <SvgIcon>
      <path d="M3 7h11v9H3z" />
      <path d="M14 10h4l3 3v3h-7z" />
      <circle cx="7" cy="18" r="2" />
      <circle cx="17" cy="18" r="2" />
    </SvgIcon>
  );
}

function CheckCircleIcon() {
  return (
    <SvgIcon>
      <circle cx="12" cy="12" r="9" />
      <path d="m8 12 3 3 5-6" />
    </SvgIcon>
  );
}

function CalendarIcon() {
  return (
    <SvgIcon>
      <path d="M7 3v4" />
      <path d="M17 3v4" />
      <path d="M4 8h16" />
      <path d="M5 5h14v16H5z" />
    </SvgIcon>
  );
}

function FilterIcon() {
  return (
    <SvgIcon>
      <path d="M4 6h16" />
      <path d="M7 12h10" />
      <path d="M10 18h4" />
    </SvgIcon>
  );
}

function MoreIcon() {
  return (
    <SvgIcon>
      <circle cx="12" cy="5" r="1" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="1" fill="currentColor" stroke="none" />
      <circle cx="12" cy="19" r="1" fill="currentColor" stroke="none" />
    </SvgIcon>
  );
}
