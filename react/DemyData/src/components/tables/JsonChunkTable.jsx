import React, { useMemo } from "react";

/** Convert any value to a readable string (objects -> JSON) */
const toFullString = (v) => {
  if (v === null || v === undefined) return "";
  if (typeof v === "object") {
    try { return JSON.stringify(v); } catch { return String(v); }
  }
  return String(v);
};

/** Truncate to N words, keep full in title attribute */
const truncateWords = (text, n = 5) => {
  const words = String(text || "").trim().split(/\s+/);
  if (words.length <= n) return text;
  return `${words.slice(0, n).join(" ")}…`;
};

const JsonChunkTable = ({
  rows = [],
  columns = [],
  loading,
  error,
  q,

  // server-side pagination
  offset = 0,
  limit = 100,
  totalRows = 0,
  hasPrev = false,
  hasNext = false,
  onPrev,
  onNext,
  onPrev100,
  onNext100,
  onPageSize,
}) => {
  const headers = useMemo(() => {
    if (Array.isArray(columns) && columns.length) return columns;
    const set = new Set();
    rows.forEach((r) => Object.keys(r || {}).forEach((k) => set.add(k)));
    return Array.from(set);
  }, [columns, rows]);

  const filtered = useMemo(() => {
    const t = (q || "").trim().toLowerCase();
    if (!t) return rows;
    return rows.filter((r) =>
      headers.some((h) => toFullString(r?.[h] ?? "").toLowerCase().includes(t))
    );
  }, [rows, headers, q]);

  const page = Math.floor(offset / Math.max(1, limit)) + 1;
  const totalPages = Math.ceil(totalRows / Math.max(1, limit));
  const showingStart = totalRows ? Math.min(totalRows, offset + 1) : offset + 1;
  const showingEnd = totalRows ? Math.min(totalRows, offset + filtered.length) : offset + filtered.length;

  return (
    <div className="space-y-3 min-w-0">
      {/* Paging controls (no filter input here) */}
      <div className="flex flex-wrap items-center gap-2">
        {onPageSize && (
          <select
            value={limit}
            onChange={(e) => onPageSize?.(Number(e.target.value))}
            className="rounded-lg border border-gray-300 px-2 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          >
            {[25, 50, 100, 200, 500].map((n) => (
              <option key={n} value={n}>{n}/page</option>
            ))}
          </select>
        )}

        <div className="ml-auto flex items-center gap-3">
          <span className="text-sm text-gray-600">
            Showing {showingStart.toLocaleString()}–{showingEnd.toLocaleString()}
            {totalRows ? <> of {totalRows.toLocaleString()}</> : null}
            {totalPages > 0 && <> (Page {page} of {totalPages})</>}
          </span>

          <div className="flex items-center gap-2">
            <button
              onClick={onPrev100}
              disabled={!hasPrev || loading || offset < 100}
              className="px-3 py-1.5 text-sm rounded border border-gray-300 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous 100
            </button>

            <button
              onClick={onPrev}
              disabled={!hasPrev || loading || offset === 0}
              className="px-3 py-1.5 text-sm rounded border border-gray-300 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>

            <button
              onClick={onNext}
              disabled={!hasNext || loading}
              className="px-3 py-1.5 text-sm rounded border border-gray-300 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>

            <button
              onClick={onNext100}
              disabled={!hasNext || loading}
              className="px-3 py-1.5 text-sm rounded border border-gray-300 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next 100
            </button>
          </div>
        </div>
      </div>

      {/* States */}
      {loading ? (
        <p className="text-sm text-gray-600">Loading…</p>
      ) : error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>
      ) : (
        // Single horizontal/vertical scroll container
        <div
          className="w-full overflow-auto rounded-xl border border-gray-200 shadow-sm"
          style={{ maxHeight: "70vh", WebkitOverflowScrolling: "touch" }}
        >
          <table
            className="min-w-full divide-y divide-gray-200"
            style={{ minWidth: Math.max(headers.length * 220, 600) }}
          >
            <thead className="bg-gray-50">
              <tr>
                {headers.map((h) => (
                  <th
                    key={h}
                    className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider whitespace-nowrap"
                    style={{ minWidth: 200, maxWidth: 400 }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filtered.map((r, i) => (
                <tr key={i} className="hover:bg-gray-50">
                  {headers.map((h) => {
                    const full = toFullString(r?.[h]);
                    const clipped = full ? truncateWords(full, 5) : "";
                    return (
                      <td
                        key={h}
                        title={full}
                        className="px-4 py-3 text-sm text-gray-800 whitespace-nowrap overflow-hidden text-ellipsis"
                        style={{ minWidth: 200, maxWidth: 400 }}
                      >
                        {clipped || <span className="text-gray-400">—</span>}
                      </td>
                    );
                  })}
                </tr>
              ))}
              {!filtered.length && (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-gray-500"
                    colSpan={Math.max(headers.length, 1)}
                  >
                    No rows found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default JsonChunkTable;