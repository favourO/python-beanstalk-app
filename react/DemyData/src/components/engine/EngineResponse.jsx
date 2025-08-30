import React, { useMemo, useState } from "react";

const Card = ({ children }) => (
  <div className="rounded-lg border border-gray-200 bg-white p-3 text-sm text-gray-800 shadow-sm">
    {children}
  </div>
);

const SectionTitle = ({ children }) => (
  <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-500">
    {children}
  </div>
);

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
  "#6366F1", "#10B981", "#F59E0B", "#EF4444", "#3B82F6",
  "#8B5CF6", "#EC4899", "#06B6D4", "#84CC16", "#F43F5E",
];

/* ----------------- Simple SVG charts (bar/line/scatter/pie) ----------------- */

const SvgFrame = ({ children, height = 260, padding = 30 }) => {
  return (
    <svg viewBox={`0 0 700 ${height}`} className="w-full h-[260px]">
      <g transform={`translate(${padding},${padding})`}>{children}</g>
    </svg>
  );
};

const BarChart = ({ data, xKey, yKey }) => {
  if (!data?.length || !xKey || !yKey) return <div className="text-sm text-gray-500">No chart data.</div>;
  const H = 200, W = 640, P = 30;
  const vals = data.map((d) => Number(d?.[yKey]) || 0);
  const max = Math.max(1, ...vals);
  const bw = Math.max(8, Math.floor(W / data.length) - 4);

  return (
    <SvgFrame height={H + P * 2} padding={P}>
      {[0.25, 0.5, 0.75, 1].map((t) => (
        <line key={t} x1="0" x2={W} y1={H * (1 - t)} y2={H * (1 - t)} stroke="#e5e7eb" strokeDasharray="3 3" />
      ))}
      {data.map((d, i) => {
        const yv = Number(d?.[yKey]) || 0;
        const h = (yv / max) * H;
        const x = i * (W / data.length) + 2;
        const y = H - h;
        return (
          <rect key={i} x={x} y={y} width={bw} height={h} fill={defaultPalette[i % defaultPalette.length]}>
            <title>{`${d?.[xKey]}: ${formatCompact(yv)}`}</title>
          </rect>
        );
      })}
    </SvgFrame>
  );
};

const LineChart = ({ data, xKey, yKey }) => {
  if (!data?.length || !xKey || !yKey) return <div className="text-sm text-gray-500">No chart data.</div>;
  const H = 200, W = 640, P = 30;
  const vals = data.map((d) => Number(d?.[yKey]) || 0);
  const max = Math.max(1, ...vals);
  const pts = data.map((d, i) => {
    const x = (i / (data.length - 1 || 1)) * W;
    const y = H - (Number(d?.[yKey]) || 0) / max * H;
    return [x, y];
  });
  const path = pts.map(([x, y], i) => (i ? `L${x},${y}` : `M${x},${y}`)).join(" ");
  return (
    <SvgFrame height={H + P * 2} padding={P}>
      {[0.25, 0.5, 0.75, 1].map((t) => (
        <line key={t} x1="0" x2={W} y1={H * (1 - t)} y2={H * (1 - t)} stroke="#e5e7eb" strokeDasharray="3 3" />
      ))}
      <path d={path} fill="none" stroke="#2563eb" strokeWidth="2" />
      {pts.map(([x, y], i) => (
        <circle key={i} cx={x} cy={y} r="2.5" fill="#2563eb">
          <title>{`${data[i]?.[xKey]}: ${formatCompact(data[i]?.[yKey])}`}</title>
        </circle>
      ))}
    </SvgFrame>
  );
};

const ScatterChart = ({ data, xKey, yKey }) => {
  if (!data?.length || !xKey || !yKey) return <div className="text-sm text-gray-500">No chart data.</div>;
  const H = 200, W = 640, P = 30;
  const xn = data.map((d) => Number(d?.[xKey]));
  const yn = data.map((d) => Number(d?.[yKey]));
  const xMin = Math.min(...xn), xMax = Math.max(...xn);
  const yMin = Math.min(...yn), yMax = Math.max(...yn);
  const sx = (v) => ((v - xMin) / (xMax - xMin || 1)) * W;
  const sy = (v) => H - ((v - yMin) / (yMax - yMin || 1)) * H;
  return (
    <SvgFrame height={H + P * 2} padding={P}>
      {[0.25, 0.5, 0.75, 1].map((t) => (
        <line key={t} x1="0" x2={W} y1={H * (1 - t)} y2={H * (1 - t)} stroke="#e5e7eb" strokeDasharray="3 3" />
      ))}
      {data.map((d, i) => (
        <circle
          key={i}
          cx={sx(Number(d?.[xKey]))}
          cy={sy(Number(d?.[yKey]))}
          r="3"
          fill={defaultPalette[i % defaultPalette.length]}
        >
          <title>{`${xKey}: ${d?.[xKey]}, ${yKey}: ${d?.[yKey]}`}</title>
        </circle>
      ))}
    </SvgFrame>
  );
};

const PieChart = ({ data, labelKey, valueKey }) => {
  if (!data?.length) return <div className="text-sm text-gray-500">No chart data.</div>;
  const size = 260, r = 100, cx = 130, cy = 130;
  const total = data.reduce((s, d) => s + (Number(d?.[valueKey]) || 0), 0) || 1;
  let start = 0;
  const arcs = data.map((d, i) => {
    const val = Number(d?.[valueKey]) || 0;
    const angle = (val / total) * Math.PI * 2;
    const end = start + angle;
    const large = angle > Math.PI ? 1 : 0;
    const x1 = cx + r * Math.cos(start);
    const y1 = cy + r * Math.sin(start);
    const x2 = cx + r * Math.cos(end);
    const y2 = cy + r * Math.sin(end);
    const path = `M${cx},${cy} L${x1},${y1} A${r},${r} 0 ${large} 1 ${x2},${y2} Z`;
    const fill = defaultPalette[i % defaultPalette.length];
    const label = `${d?.[labelKey]}: ${formatCompact(val)}`;
    start = end;
    return <path key={i} d={path} fill={fill}><title>{label}</title></path>;
  });

  return (
    <svg viewBox={`0 0 ${size} ${size}`} className="w-full h-[260px]">
      {arcs}
    </svg>
  );
};

/* --------------------------------- Table --------------------------------- */

const SimpleTable = ({ rows, limit = 10 }) => {
  const allRows = Array.isArray(rows) ? rows : [];
  const previewRows = allRows.slice(0, limit);
  const cols = useMemo(() => {
    const set = new Set();
    (previewRows || []).forEach((r) => Object.keys(r || {}).forEach((k) => set.add(k)));
    return Array.from(set);
  }, [rows, limit]);

  if (!previewRows?.length) return <div className="text-sm text-gray-500">No rows.</div>;

  return (
    <div className="overflow-auto rounded-md border border-gray-200">
      <table className="min-w-full text-xs">
        <thead className="bg-gray-50">
          <tr>
            {cols.map((c) => (
              <th key={c} className="px-3 py-2 text-left font-medium text-gray-700">
                {c}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {previewRows.map((r, i) => (
            <tr key={i} className="odd:bg-white even:bg-gray-50">
              {cols.map((c) => (
                <td key={c} className="px-3 py-2 align-top text-gray-800">
                  {r?.[c] === null || r?.[c] === undefined ? (
                    <span className="text-gray-400">—</span>
                  ) : typeof r[c] === "object" ? (
                    <pre className="whitespace-pre-wrap break-words">{JSON.stringify(r[c], null, 2)}</pre>
                  ) : (
                    String(r[c])
                  )}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      {Array.isArray(rows) && rows.length > limit && (
        <div className="px-3 py-1 text-[10px] text-gray-500">
          Showing first {limit.toLocaleString()} of {rows.length.toLocaleString()} rows.
        </div>
      )}
    </div>
  );
};

/* ----------------------------- Chart selector ----------------------------- */

const ChartBlock = ({ spec, limit = 10 }) => {
  const fullData = Array.isArray(spec?.data) ? spec.data : [];
  const limitN = limit === "all" ? fullData.length : Number(limit) || 10;
  const data = fullData.slice(0, limitN);

  // pick keys using full dataset, not only the slice
  const xKey = spec?.x || spec?.encoding?.x || (fullData[0] && Object.keys(fullData[0])[0]);
  const yKey =
    spec?.y || spec?.encoding?.y ||
    (fullData[0] && Object.keys(fullData[0]).find((k) => typeof fullData[0][k] === "number"));
  const title = spec?.title;
  const type = (spec?.type || "bar").toLowerCase();

  if (!data.length || !xKey) {
    return <div className="text-sm text-gray-500">No chart data returned by the engine.</div>;
  }

  return (
    <div className="space-y-2">
      {title ? <div className="text-sm font-semibold text-gray-900">{title}</div> : null}

      {type === "line" ? (
        <LineChart data={data} xKey={xKey} yKey={yKey} />
      ) : type === "scatter" ? (
        <ScatterChart data={data} xKey={xKey} yKey={yKey} />
      ) : type === "pie" ? (
        <PieChart
          data={data}
          labelKey={data[0]?.category !== undefined ? "category" : xKey}
          valueKey={data[0]?.value !== undefined ? "value" : yKey}
        />
      ) : (
        <BarChart data={data} xKey={xKey} yKey={yKey} />
      )}

      {/* Data preview */}
      <div className="rounded-md border border-gray-100 bg-gray-50 p-2">
        <SectionTitle>Data (first {limitN})</SectionTitle>
        <SimpleTable rows={fullData} limit={limitN} />
      </div>
    </div>
  );
};

/* ------------------------------ Main export ------------------------------ */

const UploadsList = ({ uploads }) => {
  if (!uploads?.length) return null;
  return (
    <div className="text-xs text-gray-500">
      Using: {uploads.map((u) => u?.original_name || u?.id).filter(Boolean).join(", ")}
    </div>
  );
};

export default function EngineResponse({ item, viewMode = "graph" }) {
  if (!item) return null;

  const [pointLimit, setPointLimit] = useState(10); // default 10

  const resultType = item.result_type || (item.chart ? "chart" : item.table ? "table" : "insight");
  const question = item.question || item.query_text;
  const answerText = item.answer_text || item.summary || item?.insight?.text || "";
  const explanation = item.explanation || item?.analysis?.text || "";

  // Merge chart + chart_data into a single plot-ready spec
  const chartSpec = useMemo(() => {
    const c = item?.chart || {};
    const cd = item?.chart_data || {};
    const type = (c.type || cd.type || "bar");
    const merged = {
      type,
      title: c.title || cd.title,
      x: c.x || cd.x || c?.encoding?.x || cd?.encoding?.x,
      y: c.y || cd.y || c?.encoding?.y || cd?.encoding?.y,
      encoding: c.encoding || cd.encoding,
      data: c.data || cd.data || [],
    };
    return merged;
  }, [item]);

  const onChangeLimit = (e) => {
    const v = e.target.value;
    setPointLimit(v === "all" ? "all" : Number(v));
  };

  return (
    <Card>
      {/* Header */}
      <div className="mb-2 flex items-start justify-between gap-3">
        <div className="min-w-0">
          {question && (
            <div className="truncate text-sm font-semibold text-gray-900" title={question}>
              {question}
            </div>
          )}
          <UploadsList uploads={item.uploads} />
        </div>

        {/* Data points control */}
        <div className="flex items-center gap-2">
          <label className="text-[11px] text-gray-500">Data points</label>
          <select
            value={String(pointLimit)}
            onChange={onChangeLimit}
            className="rounded-md border border-gray-300 bg-white px-2 py-1 text-[11px]"
            title="How many points/rows to render"
          >
            <option value="10">10</option>
            <option value="25">25</option>
            <option value="50">50</option>
            <option value="100">100</option>
            <option value="all">All</option>
          </select>
        </div>
      </div>

      {/* Analysis-first view */}
      {viewMode === "analysis" && (
        <div className="space-y-3">
          {answerText && (
            <>
              <SectionTitle>Answer</SectionTitle>
              <div className="rounded-md bg-indigo-50 px-3 py-2 text-sm text-indigo-900">
                {answerText}
              </div>
            </>
          )}
          {explanation && (
            <>
              <SectionTitle>Explanation</SectionTitle>
              <p className="text-sm text-gray-800">{explanation}</p>
            </>
          )}
        </div>
      )}

      {/* Graph-first view */}
      {viewMode === "graph" && (
        <div className="space-y-3">
          {chartSpec?.data?.length ? (
            <>
              <ChartBlock spec={chartSpec} limit={pointLimit} />

              {/* Explanation directly under the chart */}
              {explanation && (
                <div className="rounded-md border border-blue-100 bg-blue-50 px-3 py-2">
                  <SectionTitle>Explanation</SectionTitle>
                  <p className="text-sm text-blue-900">{explanation}</p>
                </div>
              )}
            </>
          ) : (
            <div className="text-sm text-gray-500">No chart payload in this response.</div>
          )}

          {/* Answer after explanation */}
          {answerText && (
            <>
              <SectionTitle>Answer</SectionTitle>
              <div className="rounded-md bg-indigo-50 px-3 py-2 text-sm text-indigo-900">
                {answerText}
              </div>
            </>
          )}
        </div>
      )}

      {/* Fallback table mode */}
      {viewMode !== "graph" && viewMode !== "analysis" && resultType === "table" && (
        <SimpleTable rows={item?.table?.rows || item?.rows || item?.data || []} limit={pointLimit === "all" ? 10_000 : pointLimit} />
      )}

      {item.status && item.status !== "completed" && (
        <div className="mt-3 text-xs text-gray-500">Status: {item.status}</div>
      )}
    </Card>
  );
}
