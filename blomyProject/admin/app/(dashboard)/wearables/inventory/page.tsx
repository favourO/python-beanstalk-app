"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import StatCard from "@/components/StatCard";
import Badge from "@/components/Badge";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { ApiError, getToken, wearableAdminApi, type WearableInventoryItem } from "@/lib/api";
import { formatDate } from "@/components/wearable/status";

const ISO2_RE = /^[A-Z]{2}$/;

function CountryAvailabilityEditor({
  sku,
  initial,
  token,
  onSaved,
}: {
  sku: string;
  initial: string[];
  token: string;
  onSaved: (codes: string[]) => void;
}) {
  const [codes, setCodes] = useState<string[]>(initial);
  const [input, setInput] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  function addCode() {
    const code = input.trim().toUpperCase();
    if (!ISO2_RE.test(code)) { setError("Enter a valid ISO-3166 alpha-2 code (e.g. GB, US)."); return; }
    if (codes.includes(code)) { setError(`${code} is already in the list.`); return; }
    setCodes(prev => [...prev, code]);
    setInput("");
    setError(null);
    inputRef.current?.focus();
  }

  function removeCode(code: string) {
    setCodes(prev => prev.filter(c => c !== code));
  }

  async function save() {
    setSaving(true); setError(null);
    try {
      const result = await wearableAdminApi.updateCountryAvailability(token, sku, codes);
      const updated = result.items.find(i => i.sku === sku);
      onSaved(updated?.allowed_country_codes ?? codes);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save country availability.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mt-5 border-t border-[#FFD9C2] pt-5">
      <p className="text-xs font-semibold text-[#A06A52] mb-2">Country availability</p>
      <p className="text-[11px] text-[#A06A52] mb-3">Wearable purchase is only available in listed countries. UK (GB) is enabled by default.</p>
      <div className="flex flex-wrap gap-2 mb-3 min-h-[28px]">
        {codes.length === 0 && <span className="text-[11px] text-[#C9A090]">No countries configured — wearable will be unavailable everywhere.</span>}
        {codes.map(code => (
          <span key={code} className="inline-flex items-center gap-1 rounded-full bg-[#FFF0E8] border border-[#FFD9C2] px-2.5 py-1 text-[11px] font-semibold text-[#A06A52]">
            {code}
            <button type="button" onClick={() => removeCode(code)} className="ml-0.5 text-[#C9A090] hover:text-[#FF7A33] leading-none">&times;</button>
          </span>
        ))}
      </div>
      <div className="flex gap-2 items-center">
        <input
          ref={inputRef}
          value={input}
          onChange={e => { setInput(e.target.value.toUpperCase()); setError(null); }}
          onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); addCode(); } }}
          placeholder="e.g. US"
          maxLength={2}
          className="w-20 border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16] uppercase font-mono tracking-widest"
        />
        <button type="button" onClick={addCode} className="px-3 py-2 rounded-lg border border-[#FFD9C2] text-xs text-[#A06A52] hover:text-[#FF7A33]">Add</button>
        <button type="button" onClick={save} disabled={saving} className="px-3 py-2 rounded-lg bg-[#FF7A33] text-white text-xs font-semibold disabled:opacity-50">
          {saving ? "Saving…" : "Save countries"}
        </button>
      </div>
      {error && <p className="text-xs text-red-600 mt-2">{error}</p>}
    </div>
  );
}

export default function WearableInventoryPage() {
  const router = useRouter();
  const [items, setItems] = useState<WearableInventoryItem[]>([]);
  const [editing, setEditing] = useState<WearableInventoryItem | null>(null);
  const [editingCountryCodes, setEditingCountryCodes] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    try {
      setItems((await wearableAdminApi.getInventory(token)).items);
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load inventory");
    } finally {
      setLoading(false);
    }
  }, [router]);

  useEffect(() => { load(); }, [load]);

  const totalStock = items.reduce((sum, item) => sum + item.total_stock, 0);
  const available = items.reduce((sum, item) => sum + item.available_stock, 0);
  const reserved = items.reduce((sum, item) => sum + item.reserved_stock, 0);
  const lowStock = items.filter(item => item.low_stock).length;

  async function saveInventory(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!editing) return;
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    const form = new FormData(e.currentTarget);
    setSaving(true); setError(null); setMessage(null);
    try {
      await wearableAdminApi.updateInventory(token, {
        sku: editing.sku,
        total_stock: Number(form.get("total_stock")),
        available_stock: Number(form.get("available_stock")),
        price_minor: Math.round(Number(form.get("price")) * 100),
        low_stock_threshold: Number(form.get("low_stock_threshold")),
        is_active: form.get("is_active") === "on",
      });
      setMessage(`Inventory updated for ${editing.sku}`);
      setEditing(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to update inventory");
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <TopBar title="Wearable inventory" subtitle="Stock, pricing, and availability controls" />
      {error && <ErrorBanner message={error} />}
      {message && <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-5 py-4 text-sm text-emerald-700 mb-6">{message}</div>}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Total stock" value={String(totalStock)} sub="All products" accent />
        <StatCard label="Available" value={String(available)} sub="Ready to sell" />
        <StatCard label="Reserved" value={String(reserved)} sub="Paid, not delivered" />
        <StatCard label="Low stock" value={String(lowStock)} sub="Active warnings" />
      </div>

      {lowStock > 0 && (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-800 mb-6">
          {lowStock} wearable inventory item{lowStock === 1 ? "" : "s"} at or below the configured low stock threshold.
        </div>
      )}

      <div className="flex gap-3 mb-5">
        <Link href="/wearables/orders" className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#A06A52] hover:text-[#FF7A33]">View orders</Link>
        <Link href="/wearables/analytics" className="border border-[#FFD9C2] bg-white rounded-lg px-3 py-2 text-sm text-[#A06A52] hover:text-[#FF7A33]">View analytics</Link>
      </div>

      <Table>
        <Thead><Th>Product</Th><Th>SKU</Th><Th>Price</Th><Th>Total</Th><Th>Available</Th><Th>Reserved</Th><Th>Threshold</Th><Th>Countries</Th><Th>Status</Th><Th>Updated</Th><Th>Action</Th></Thead>
        <Tbody>
          {loading ? <LoadingRows cols={10} /> :
           items.length === 0 ? <EmptyState label="No wearable inventory configured" /> :
           items.map(item => (
            <Tr key={item.id}>
              <Td>{item.product_name}</Td>
              <Td muted>{item.sku}</Td>
              <Td>{item.display_price}</Td>
              <Td>{item.total_stock}</Td>
              <Td>{item.available_stock}</Td>
              <Td>{item.reserved_stock}</Td>
              <Td>{item.low_stock_threshold}</Td>
              <Td><Badge label={item.is_active ? (item.low_stock ? "open" : "active") : "draft"} /></Td>
              <Td muted>{formatDate(item.updated_at)}</Td>
              <Td>
                <div className="flex flex-col gap-0.5">
                  {(item.allowed_country_codes ?? []).length === 0
                    ? <span className="text-[10px] text-red-500 font-semibold">No countries</span>
                    : (item.allowed_country_codes ?? []).map(c => (
                        <span key={c} className="text-[10px] font-mono text-[#A06A52]">{c}</span>
                      ))}
                </div>
              </Td>
              <Td><button onClick={() => { setEditing(item); setEditingCountryCodes(item.allowed_country_codes ?? ["GB"]); }} className="text-[#FF7A33] text-[12px] font-semibold">Edit</button></Td>
            </Tr>
          ))}
        </Tbody>
      </Table>

      {editing && (
        <div className="fixed inset-0 z-40 bg-black/30 flex items-center justify-center p-6">
          <div className="w-full max-w-lg rounded-2xl border border-[#FFD9C2] bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between gap-4 mb-5">
              <div>
                <p className="text-xl font-semibold text-[#1E0C16]">Edit inventory</p>
                <p className="text-sm text-[#A06A52]">{editing.sku}</p>
              </div>
              <button type="button" onClick={() => setEditing(null)} className="text-[#A06A52] hover:text-[#1E0C16]">✕</button>
            </div>
            <form onSubmit={saveInventory}>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <label className="text-xs font-medium text-[#A06A52]">Total stock<input name="total_stock" type="number" min={0} defaultValue={editing.total_stock} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" /></label>
                <label className="text-xs font-medium text-[#A06A52]">Available stock<input name="available_stock" type="number" min={0} defaultValue={editing.available_stock} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" /></label>
                <label className="text-xs font-medium text-[#A06A52]">Price<input name="price" type="number" min={0} step="0.01" defaultValue={(editing.price_minor / 100).toFixed(2)} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" /></label>
                <label className="text-xs font-medium text-[#A06A52]">Low stock threshold<input name="low_stock_threshold" type="number" min={0} defaultValue={editing.low_stock_threshold} className="mt-1 w-full border border-[#FFD9C2] rounded-lg px-3 py-2 text-sm text-[#1E0C16]" /></label>
                <label className="sm:col-span-2 flex items-center gap-2 text-sm text-[#1E0C16]"><input name="is_active" type="checkbox" defaultChecked={editing.is_active} /> Active for checkout</label>
              </div>
              <div className="mt-6 flex justify-end gap-3">
                <button type="button" onClick={() => setEditing(null)} className="px-4 py-2 rounded-lg border border-[#FFD9C2] text-sm text-[#A06A52]">Cancel</button>
                <button disabled={saving} className="px-4 py-2 rounded-lg bg-[#FF7A33] text-white text-sm font-semibold disabled:opacity-50">{saving ? "Saving…" : "Save inventory"}</button>
              </div>
            </form>
            {(() => {
              const token = getToken();
              if (!token) return null;
              return (
                <CountryAvailabilityEditor
                  sku={editing.sku}
                  initial={editingCountryCodes}
                  token={token}
                  onSaved={(codes) => {
                    setEditingCountryCodes(codes);
                    setItems(prev => prev.map(i => i.sku === editing.sku ? { ...i, allowed_country_codes: codes } : i));
                    setMessage(`Country availability updated for ${editing.sku}`);
                  }}
                />
              );
            })()}
          </div>
        </div>
      )}
    </>
  );
}
