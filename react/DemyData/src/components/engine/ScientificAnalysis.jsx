// src/components/engine/ScientificAnalysis.jsx
import React, { useState } from "react";

// Reuse compact table & chart logic (inline minimal versions)
const SectionTitle = ({ children, blue = false }) => (
  <div
    className={`mb-1 text-xs font-semibold uppercase tracking-wide ${
      blue ? "text-blue-900" : "text-gray-500"
    }`}
  >
    {children}
  </div>
);

const Card = ({ children }) => (
  <div className="rounded-lg border border-gray-200 bg-white p-4 text-sm text-gray-800 shadow-sm">
    {children}
  </div>
);

const Badge = ({ children }) => (
  <span className="inline-flex items-center rounded-full bg-blue-50 px-2 py-0.5 text-[10px] font-medium text-blue-700 ring-1 ring-inset ring-blue-200">
    {children}
  </span>
);

// Simple table with show-more
const SimpleTable = ({ rows, initial = 10 }) => {
  const [visible, setVisible] = useState(initial);
  const columns = rows?.length ? Array.from(new Set(rows.flatMap(r => Object.keys(r || {})))) : [];

  if (!rows?.length) return <div className="text-sm text-gray-500">No rows.</div>;

  const data = rows.slice(0, visible);
  const remaining = Math.max(0, rows.length - data.length);

  return (
    <div>
      <div className="overflow-auto rounded-md border border-gray-200">
        <table className="min-w-full text-xs">
          <thead className="bg-gray-50">
            <tr>
              {columns.map((c) => (
                <th key={c} className="px-3 py-2 text-left font-medium text-gray-700">{c}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.map((r, i) => (
              <tr key={i} className="odd:bg-white even:bg-gray-50">
                {columns.map((c) => (
                  <td key={c} className="px-3 py-2 align-top">{String(r?.[c] ?? "—")}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {remaining > 0 && (
        <div className="mt-2 flex gap-2">
          <button
            onClick={() => setVisible((v) => v + 10)}
            className="rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
          >
            Show 10 more ({remaining} left)
          </button>
          <button
            onClick={() => setVisible(rows.length)}
            className="rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
          >
            Show all
          </button>
        </div>
      )}
    </div>
  );
};

// Minimal bar/line chart renderers (same style as EngineResponse)
const formatCompact = (n) => {
  const num = typeof n === "string" ? Number(n) : n;
  if (!Number.isFinite(num)) return String(n ?? "");
  const abs = Math.abs(num);
  if (abs >= 1_000_000_000) return (num / 1_000_000_000).toFixed(1).replace(/\.0$/, "") + "B";
  if (abs >= 1_000_000)     return (num / 1_000_000).toFixed(1).replace(/\.0$/, "") + "M";
  if (abs >= 1_000)         return (num / 1_000).toFixed(1).replace(/\.0$/, "") + "k";
  return num.toLocaleString();
};

const defaultPalette = [
  "#1E3A8A", "#0EA5E9", "#10B981", "#F59E0B", "#EF4444",
  "#3B82F6", "#8B5CF6", "#EC4899", "#06B6D4", "#84CC16",
];

const ColumnChart = ({ data, xKey, yKey }) => {
  if (!data?.length) return <div className="text-sm text-gray-500">No chart data.</div>;
  const max = Math.max(...data.map((d) => Number(d?.[yKey]) || 0), 1);
  const barWidth = Math.max(16, Math.min(56, Math.floor(640 / Math.max(1, data.length))));
  return (
    <div className="relative w-full h-56 border border-gray-200 rounded-md bg-white p-3">
      <div className="absolute left-10 right-2 top-2 bottom-8">
        {[1, 0.75, 0.5, 0.25].map((t) => (
          <div
            key={t}
            className="absolute left-0 right-0 border-t border-dashed border-gray-200"
            style={{ bottom: `${t * 100}%` }}
          />
        ))}
        <div className="absolute bottom-0 left-0 right-0 flex items-end gap-2">
          {data.map((d, i) => {
            const y = Number(d?.[yKey]) || 0;
            const hPct = Math.max(0, Math.min(100, (y / max) * 100));
            const color = defaultPalette[i % defaultPalette.length];
            const label = String(d?.[xKey]);
            return (
              <div key={i} className="flex flex-col items-center" style={{ width: barWidth }}>
                <div className="w-full rounded-t" style={{ height: `${hPct}%`, backgroundColor: color }} title={`${label}: ${formatCompact(y)}`} />
              </div>
            );
          })}
        </div>
      </div>
      <div className="absolute left-10 right-2 bottom-1 flex items-end gap-2">
        {data.map((d, i) => {
          const label = String(d?.[xKey] ?? "");
          const short = label.length > 8 ? label.slice(0, 8) + "…" : label;
          return (
            <div key={i} className="text-[10px] text-gray-600 truncate" style={{ width: barWidth }} title={label}>
              {short}
            </div>
          );
        })}
      </div>
    </div>
  );
};

const ChartPreview = ({ spec }) => {
  const [visible, setVisible] = useState(10);
  const full = spec?.data || [];
  const data = full.slice(0, visible);
  const remaining = Math.max(0, full.length - data.length);

  const xKey =
    (spec?.encoding && (spec.encoding.x?.field || spec.encoding.x)) ||
    spec?.x || (data[0] ? Object.keys(data[0])[0] : "x");
  const yKey =
    (spec?.encoding && (spec.encoding.y?.field || spec.encoding.y)) ||
    spec?.y || (data[0] ? Object.keys(data[0]).find((k) => typeof data[0][k] === "number") : "y");

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <div className="text-sm font-medium text-blue-900">{spec?.title || "Chart"}</div>
        <Badge>{spec?.type}</Badge>
      </div>
      <ColumnChart data={data} xKey={xKey} yKey={yKey} />
      {remaining > 0 && (
        <div className="flex gap-2">
          <button
            onClick={() => setVisible((v) => v + 10)}
            className="rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
          >
            Show 10 more ({remaining} left)
          </button>
          <button
            onClick={() => setVisible(full.length)}
            className="rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
          >
            Show all
          </button>
        </div>
      )}

      <div className="rounded border border-gray-100 bg-gray-50 p-2">
        <SectionTitle>Data (showing {data.length} of {full.length})</SectionTitle>
        <SimpleTable rows={data} initial={10} />
      </div>
    </div>
  );
};

export default function ScientificAnalysis({ item }) {
  if (!item) return null;

  const { title, objective, steps = [], sections = [], kpis = {}, chart_previews = [], summary_table = [] } = item;

  return (
    <Card>
      <div className="mb-2">
        <div className="text-base font-semibold text-blue-900">{title || "Scientific Analysis"}</div>
        {objective && <div className="text-sm text-gray-700 mt-1">{objective}</div>}
      </div>

      {/* KPIs */}
      {kpis && Object.keys(kpis).length > 0 && (
        <div className="mb-3">
          <SectionTitle blue>KPIs</SectionTitle>
          <div className="flex flex-wrap gap-2">
            {Object.entries(kpis).map(([k, v]) => (
              <Badge key={k}>
                {k}: {String(v)}
              </Badge>
            ))}
          </div>
        </div>
      )}

      {/* Steps */}
      {steps.length > 0 && (
        <div className="mb-3">
          <SectionTitle blue>CRISP-DM Steps</SectionTitle>
          <ol className="list-decimal pl-5 space-y-2">
            {steps.map((s, i) => (
              <li key={i}>
                <div className="font-medium text-gray-900">{s.name}</div>
                {s.what_you_do && <div className="text-sm text-gray-700">{s.what_you_do}</div>}
                {Array.isArray(s.expected_outcomes) && s.expected_outcomes.length > 0 && (
                  <ul className="list-disc pl-5 text-sm text-gray-700 mt-1">
                    {s.expected_outcomes.map((o, j) => (
                      <li key={j}>{o}</li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ol>
        </div>
      )}

      {/* Sections */}
      {sections.length > 0 && (
        <div className="mb-3 space-y-3">
          {sections.map((sec, i) => (
            <div key={i}>
              <div className="text-sm font-semibold text-blue-900">{sec.title}</div>
              <div className="prose prose-sm max-w-none text-gray-800">
                <p className="whitespace-pre-wrap">{sec.content}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Chart previews */}
      {Array.isArray(chart_previews) && chart_previews.length > 0 && (
        <div className="space-y-4">
          <SectionTitle blue>Charts</SectionTitle>
          {chart_previews.map((c, idx) => (
            <ChartPreview key={idx} spec={c} />
          ))}
        </div>
      )}

      {/* Summary table */}
      {Array.isArray(summary_table) && summary_table.length > 0 && (
        <div className="mt-4">
          <SectionTitle blue>Summary</SectionTitle>
          <SimpleTable rows={summary_table} initial={10} />
        </div>
      )}
    </Card>
  );
}
