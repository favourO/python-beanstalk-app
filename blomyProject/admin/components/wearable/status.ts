export const fulfillmentTone: Record<string, string> = {
  pending: "bg-amber-50 text-amber-700 border-amber-200",
  processing: "bg-yellow-50 text-yellow-700 border-yellow-200",
  dispatched: "bg-sky-50 text-sky-700 border-sky-200",
  out_for_delivery: "bg-indigo-50 text-indigo-700 border-indigo-200",
  delivered: "bg-emerald-50 text-emerald-700 border-emerald-200",
  cancelled: "bg-red-50 text-red-700 border-red-200",
  paid: "bg-emerald-50 text-emerald-700 border-emerald-200",
  refunded: "bg-gray-50 text-gray-600 border-gray-200",
  failed: "bg-red-50 text-red-700 border-red-200",
};

export function labelStatus(value: string | null | undefined) {
  if (!value) return "Unknown";
  return value.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
}

export function formatDate(value: string | null | undefined) {
  return value ? value.slice(0, 16).replace("T", " ") : "—";
}

export function formatMoneyMinor(amount: number, currency = "GBP") {
  const symbol = currency.toUpperCase() === "GBP" ? "£" : `${currency.toUpperCase()} `;
  return `${symbol}${(amount / 100).toFixed(2)}`;
}
