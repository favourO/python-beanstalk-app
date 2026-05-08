"use client";
import { useState } from "react";

interface TopBarProps {
  title: string;
  subtitle?: string;
  onExport?: () => void;
}

export default function TopBar({ title, subtitle, onExport }: TopBarProps) {
  const [dateRange] = useState("May 12 – May 18, 2024");

  return (
    <div className="flex items-start justify-between mb-6">
      <div>
        <h1 className="text-[22px] font-bold text-[#1E0C16] tracking-tight leading-tight">{title}</h1>
        {subtitle && <p className="text-[13px] text-[#9E7B6E] mt-0.5">{subtitle}</p>}
      </div>
      <div className="flex items-center gap-2 shrink-0">
        {/* Date range */}
        <button className="flex items-center gap-2 px-3 py-2 bg-white border border-[#E8DDD9] rounded-lg text-[12px] text-[#5C3D30] hover:border-[#FF7A33] transition-colors">
          <CalendarIcon />
          {dateRange}
        </button>
        {/* Filters */}
        <button className="flex items-center gap-1.5 px-3 py-2 bg-white border border-[#E8DDD9] rounded-lg text-[12px] text-[#5C3D30] hover:border-[#FF7A33] transition-colors">
          <FilterIcon />
          Filters
        </button>
        {/* Export */}
        <button
          onClick={onExport}
          className="flex items-center gap-1.5 px-4 py-2 bg-[#FF7A33] hover:bg-[#e86a22] text-white text-[12px] font-semibold rounded-lg transition-colors shadow-sm shadow-[#FF7A33]/30"
        >
          <ExportIcon />
          Export Report
        </button>
      </div>
    </div>
  );
}

function CalendarIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
      <rect x="1" y="2" width="14" height="13" rx="1.5" />
      <path d="M1 6h14M5 1v2M11 1v2" />
    </svg>
  );
}

function FilterIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
      <path d="M1 3h14M4 8h8M7 13h2" />
    </svg>
  );
}

function ExportIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
      <path d="M8 1v9M5 7l3 3 3-3M2 11v2a1 1 0 001 1h10a1 1 0 001-1v-2" />
    </svg>
  );
}
