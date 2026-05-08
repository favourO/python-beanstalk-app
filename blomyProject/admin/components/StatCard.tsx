export default function StatCard({
  label,
  value,
  sub,
  accent,
}: {
  label: string;
  value: string;
  sub?: string;
  accent?: boolean;
}) {
  return (
    <div className={`rounded-2xl p-5 border ${accent ? "bg-[#FF7A33] border-[#e86a22]" : "bg-white border-[#FFD9C2]"}`}>
      <p className={`text-xs font-medium uppercase tracking-wider mb-3 ${accent ? "text-white/70" : "text-[#A06A52]"}`}>
        {label}
      </p>
      <p className={`text-3xl font-semibold tracking-tight ${accent ? "text-white" : "text-[#1E0C16]"}`}>{value}</p>
      {sub && (
        <p className={`text-xs mt-1.5 ${accent ? "text-white/60" : "text-[#A06A52]"}`}>{sub}</p>
      )}
    </div>
  );
}
