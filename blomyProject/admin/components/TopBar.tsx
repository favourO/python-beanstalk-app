export default function TopBar({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <div className="flex items-center justify-between mb-8">
      <div>
        <h1 className="text-2xl font-semibold text-[#1E0C16] tracking-tight">{title}</h1>
        {subtitle && <p className="text-sm text-[#A06A52] mt-0.5">{subtitle}</p>}
      </div>
      <div className="flex items-center gap-3">
        <div className="text-right">
          <p className="text-sm font-medium text-[#1E0C16]">Admin</p>
          <p className="text-xs text-[#A06A52]">DemyCorp Ltd</p>
        </div>
        <div className="w-9 h-9 rounded-full bg-[#FF7A33] flex items-center justify-center text-white text-sm font-semibold">
          A
        </div>
      </div>
    </div>
  );
}
