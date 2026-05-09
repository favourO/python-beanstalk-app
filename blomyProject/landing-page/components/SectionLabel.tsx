interface SectionLabelProps {
  children: React.ReactNode;
  light?: boolean;
}

export default function SectionLabel({ children, light }: SectionLabelProps) {
  return (
    <div className="flex items-center gap-3 mb-4">
      <span className={`w-6 h-px ${light ? "bg-[#FF7A33]/40" : "bg-[#FF7A33]"}`} />
      <span className={`text-[11px] font-medium tracking-[0.12em] uppercase ${light ? "text-[#FF7A33]/70" : "text-[#FF7A33]"}`}>
        {children}
      </span>
    </div>
  );
}
