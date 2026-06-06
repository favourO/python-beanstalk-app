"use client";

import { useEffect, useState } from "react";
import type { WearableOrder } from "@/lib/api";
import { labelStatus } from "./status";

type Props = {
  order: WearableOrder | null;
  statuses: string[];
  saving: boolean;
  error: string | null;
  onClose: () => void;
  onSave: (payload: {
    fulfillment_status: string;
    courier?: string;
    tracking_number?: string;
    tracking_url?: string;
    estimated_delivery_date?: string;
  }) => void;
};

export default function DispatchModal({ order, statuses, saving, error, onClose, onSave }: Props) {
  const [status, setStatus] = useState("");
  const [courier, setCourier] = useState("");
  const [trackingNumber, setTrackingNumber] = useState("");
  const [trackingUrl, setTrackingUrl] = useState("");
  const [estimatedDelivery, setEstimatedDelivery] = useState("");

  useEffect(() => {
    if (!order) return;
    setStatus(order.fulfillment_status);
    setCourier(order.courier ?? "");
    setTrackingNumber(order.tracking_number ?? "");
    setTrackingUrl(order.tracking_url ?? "");
    setEstimatedDelivery(order.estimated_delivery_date?.slice(0, 10) ?? "");
  }, [order]);

  if (!order) return null;

  return (
    <div className="fixed inset-0 z-40 bg-black/30 flex items-center justify-center p-6">
      <form
        onSubmit={e => {
          e.preventDefault();
          onSave({
            fulfillment_status: status,
            courier: courier || undefined,
            tracking_number: trackingNumber || undefined,
            tracking_url: trackingUrl || undefined,
            estimated_delivery_date: estimatedDelivery || undefined,
          });
        }}
        className="w-full max-w-xl rounded-2xl border border-[#FFD9C2] bg-white p-6 shadow-xl"
      >
        <div className="flex items-start justify-between gap-4 mb-5">
          <div>
            <p className="text-xl font-semibold text-[#1E0C16]">Fulfilment management</p>
            <p className="text-sm text-[#A06A52]">{order.order_number} · {order.wearable_name}</p>
          </div>
          <button type="button" onClick={onClose} className="text-[#A06A52] hover:text-[#1E0C16]">✕</button>
        </div>

        {error && <div className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <label className="text-xs font-medium text-[#A06A52]">
            Fulfillment status
            <select value={status} onChange={e => setStatus(e.target.value)} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]">
              {statuses.map(item => <option key={item} value={item}>{labelStatus(item)}</option>)}
            </select>
          </label>
          <label className="text-xs font-medium text-[#A06A52]">
            Courier
            <input value={courier} onChange={e => setCourier(e.target.value)} placeholder="Royal Mail" className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" />
          </label>
          <label className="text-xs font-medium text-[#A06A52]">
            Tracking number
            <input value={trackingNumber} onChange={e => setTrackingNumber(e.target.value)} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" />
          </label>
          <label className="text-xs font-medium text-[#A06A52]">
            Estimated delivery
            <input type="date" value={estimatedDelivery} onChange={e => setEstimatedDelivery(e.target.value)} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" />
          </label>
          <label className="sm:col-span-2 text-xs font-medium text-[#A06A52]">
            Tracking URL
            <input value={trackingUrl} onChange={e => setTrackingUrl(e.target.value)} placeholder="https://..." className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" />
          </label>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button type="button" onClick={onClose} className="px-4 py-2 rounded-lg border border-[#FFD9C2] text-sm text-[#A06A52]">Cancel</button>
          <button disabled={saving} className="px-4 py-2 rounded-lg bg-[#FF7A33] text-white text-sm font-semibold disabled:opacity-50">
            {saving ? "Saving…" : "Save status update"}
          </button>
        </div>
      </form>
    </div>
  );
}
