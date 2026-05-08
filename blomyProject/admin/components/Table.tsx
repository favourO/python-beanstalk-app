export function Table({ children }: { children: React.ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-2xl border border-[#FFD9C2] bg-white">
      <table className="w-full text-left">{children}</table>
    </div>
  );
}

export function Thead({ children }: { children: React.ReactNode }) {
  return (
    <thead>
      <tr className="border-b border-[#FFD9C2] bg-[#FFF6F0]">{children}</tr>
    </thead>
  );
}

export function Th({ children }: { children: React.ReactNode }) {
  return (
    <th className="px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-[#A06A52]">
      {children}
    </th>
  );
}

export function Tbody({ children }: { children: React.ReactNode }) {
  return <tbody>{children}</tbody>;
}

export function Tr({ children }: { children: React.ReactNode }) {
  return (
    <tr className="border-b border-[#FFD9C2]/60 last:border-0 hover:bg-[#FFF6F0]/60 transition-colors">
      {children}
    </tr>
  );
}

export function Td({ children, muted }: { children: React.ReactNode; muted?: boolean }) {
  return (
    <td className={`px-4 py-3.5 text-[13px] ${muted ? "text-[#A06A52]" : "text-[#1E0C16]"}`}>
      {children}
    </td>
  );
}
