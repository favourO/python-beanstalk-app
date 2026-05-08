"use client";

export function LoadingRows({ cols }: { cols: number }) {
  return (
    <>
      {[...Array(5)].map((_, i) => (
        <tr key={i} className="border-b border-[#FFD9C2]/60">
          {[...Array(cols)].map((_, j) => (
            <td key={j} className="px-4 py-3.5">
              <div className="h-3 bg-[#FFD9C2] rounded animate-pulse" style={{ width: `${50 + (j * 17) % 40}%` }} />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="rounded-xl border border-red-200 bg-red-50 px-5 py-4 text-sm text-red-700 mb-6">
      <span className="font-semibold">Error: </span>{message}
    </div>
  );
}

export function EmptyState({ label }: { label: string }) {
  return (
    <tr>
      <td colSpan={99} className="px-6 py-12 text-center text-sm text-[#A06A52]">{label}</td>
    </tr>
  );
}
