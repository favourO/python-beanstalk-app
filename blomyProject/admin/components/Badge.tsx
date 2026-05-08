const styles: Record<string, string> = {
  active:    "bg-emerald-50 text-emerald-700 border-emerald-200",
  premium:   "bg-[#FFF0E8] text-[#FF7A33] border-[#FFD9C2]",
  free:      "bg-gray-50 text-gray-500 border-gray-200",
  trialing:  "bg-sky-50 text-sky-600 border-sky-200",
  canceled:  "bg-red-50 text-red-600 border-red-200",
  past_due:  "bg-amber-50 text-amber-700 border-amber-200",
  stripe:    "bg-indigo-50 text-indigo-600 border-indigo-200",
  flutterwave: "bg-yellow-50 text-yellow-700 border-yellow-200",
  verified:  "bg-emerald-50 text-emerald-700 border-emerald-200",
  unverified:"bg-gray-50 text-gray-400 border-gray-200",
  registered:"bg-[#FFF0E8] text-[#A06A52] border-[#FFD9C2]",
  anonymous: "bg-gray-100 text-gray-500 border-gray-200",
  deleted:   "bg-red-50 text-red-400 border-red-100",
  paid:      "bg-emerald-50 text-emerald-700 border-emerald-200",
  draft:     "bg-gray-50 text-gray-400 border-gray-200",
  void:      "bg-gray-100 text-gray-400 border-gray-200",
  open:      "bg-amber-50 text-amber-600 border-amber-200",
};

export default function Badge({ label }: { label: string }) {
  const key = label.toLowerCase().replace(/\s+/g, "_");
  const cls = styles[key] ?? "bg-gray-50 text-gray-500 border-gray-200";
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-medium border ${cls}`}>
      {label}
    </span>
  );
}
