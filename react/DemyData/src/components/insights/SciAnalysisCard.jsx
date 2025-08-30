// src/components/insights/SciAnalysisCard.jsx
import React, { useMemo, useState } from "react";
import { LuChevronDown, LuChevronRight } from "react-icons/lu";

const Row = ({ title, content }) => (
  <div className="rounded-md border border-gray-200 bg-white px-3 py-2">
    <div className="text-xs font-semibold text-gray-700 mb-1">{title}</div>
    {content ? (
      <div className="text-sm text-gray-800 whitespace-pre-wrap">{content}</div>
    ) : (
      <div className="text-sm text-gray-400">No content.</div>
    )}
  </div>
);

export default function SciAnalysisCard({ item }) {
  const [open, setOpen] = useState(false);
  const createdAt = useMemo(() => {
    try {
      return new Date(item?.created_at || 0).toLocaleString();
    } catch {
      return String(item?.created_at || "");
    }
  }, [item]);

  // The backend stores the output under result_json; keep it flexible.
  const payload = item?.result_json || item?.analysis || item || {};
  const title = item?.title || payload?.title || "Scientific Analysis";
  const topic = item?.topic || payload?.topic || "";
  const status = item?.status || "completed";

  // Steps – handle both array (steps[]) and keyed object
  const steps = useMemo(() => {
    const s = payload?.steps;
    if (Array.isArray(s)) return s;
    // try to map known keys into a displayable array
    const ordered = [
      ["Problem Definition & Planning", payload?.problem_definition],
      ["Data Cleaning & Preprocessing", payload?.data_cleaning],
      ["Exploratory Data Analysis (EDA)", payload?.eda],
      ["In-Depth Analysis & Modeling", payload?.modeling],
      ["Interpretation & Communication of Results", payload?.interpretation_comm],
      ["Deployment & Maintenance", payload?.deployment],
    ].filter(Boolean);
    if (ordered.length) {
      return ordered.map(([name, block]) => ({
        name,
        content:
          (block && (block.summary || block.result || block.details || block.text)) ||
          (typeof block === "string" ? block : ""),
      }));
    }
    return [];
  }, [payload]);

  return (
    <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center gap-2 text-left"
      >
        {open ? <LuChevronDown /> : <LuChevronRight />}
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-medium text-gray-900" title={title}>
            {title}
          </div>
          <div className="text-xs text-gray-500">
            {createdAt} • {topic ? `${topic} • ` : ""}{status}
          </div>
        </div>
      </button>

      {open && (
        <div className="mt-3 space-y-2">
          {steps.length === 0 ? (
            <div className="text-sm text-gray-500">No step details found.</div>
          ) : (
            steps.map((s, idx) => (
              <Row key={idx} title={s?.name || `Step ${idx + 1}`} content={s?.content} />
            ))
          )}
        </div>
      )}
    </div>
  );
}