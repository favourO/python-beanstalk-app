// src/pages/files/ViewFile.jsx
import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import {
  LuArrowLeft,
  LuDownload,
  LuLink,
  LuChevronDown,
  LuSend,
  LuRefreshCw,
  LuChevronRight,
  LuChevronDown as LuChevronDownSm,
  LuFileText,
  LuFlaskConical,
  LuPlay,
} from "react-icons/lu";
import JsonChunkTable from "../../components/tables/JsonChunkTable";
import EngineResponse from "../../components/engine/EngineResponse";
import ScientificAnalysis from "../../components/engine/ScientificAnalysis";

const S3_PREFIX =
  (import.meta.env.VITE_S3_PUBLIC_PREFIX ||
    "https://s3-bucket-imortol.s3.us-east-1.amazonaws.com"
  ).replace(/\/$/, "");

const formatBytes = (bytes, decimals = 1) => {
  if (!+bytes) return "0 B";
  const k = 1024, sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(decimals < 0 ? 0 : decimals))} ${sizes[i]}`;
};

const urlFromKey = (key) => {
  if (!key) return "";
  if (/^https?:\/\//i.test(key)) return key;
  return `${S3_PREFIX}/${String(key).replace(/^\/+/, "")}`;
};

const clamp = (val, min, max) => Math.min(max, Math.max(min, val));
const stringifyCell = (v) => (v == null ? "" : typeof v === "object" ? (() => { try { return JSON.stringify(v); } catch { return String(v); } })() : String(v));
const escapeCSV = (value) => {
  const needsQuotes = /[",\n\r]/.test(value);
  const v = value.replace(/"/g, '""');
  return needsQuotes ? `"${v}"` : v;
};

const normalizeEngineError = (res, err) => {
  const status = res?.status ?? err?.response?.status;
  const data = res?.data ?? err?.response?.data ?? {};
  const detail = data?.detail || data?.message || err?.message || "Request failed.";
  return { message: typeof detail === "string" ? detail : JSON.stringify(detail, null, 2), status: status || 500 };
};

// Fallback URL builders if API_PATHS doesn't include these yet
const ENGINE_QUERY_PATH = API_PATHS?.ENGINE?.QUERY || "/0.1.0/engine/query";
const ENGINE_REPORT_PATH = API_PATHS?.ENGINE?.REPORT || "/0.1.0/engine/report";
const engineQueriesUrl = (uploadId, limit = 100, offset = 0) =>
  API_PATHS?.ENGINE?.QUERIES
    ? API_PATHS.ENGINE.QUERIES(uploadId, limit, offset)
    : `/0.1.0/engine/queries?upload_id=${encodeURIComponent(uploadId)}&limit=${limit}&offset=${offset}`;

const ViewFile = () => {
  const { uploadId } = useParams();
  const navigate = useNavigate();

  // Tabs: 'query' | 'science'
  const [tab, setTab] = useState("query");

  // meta
  const [meta, setMeta] = useState(null);
  const [sourceUrl, setSourceUrl] = useState("");

  // rows page
  const [rows, setRows] = useState([]);
  const [columns, setColumns] = useState([]);
  const [offset, setOffset] = useState(0);
  const [limit, setLimit] = useState(100);
  const [totalRows, setTotalRows] = useState(0);
  const [hasMore, setHasMore] = useState(false);

  // column visibility
  const [droppedCols, setDroppedCols] = useState(() => new Set());

  // ui
  const [q, setQ] = useState("");
  const [queryText, setQueryText] = useState("");
  const [loadingMeta, setLoadingMeta] = useState(true);
  const [loadingRows, setLoadingRows] = useState(false);
  const [errorMeta, setErrorMeta] = useState("");
  const [errorRows, setErrorRows] = useState("");

  // --- Engine query state ---
  const [engineLoading, setEngineLoading] = useState(false);
  const [engineErr, setEngineErr] = useState("");
  const [engineItem, setEngineItem] = useState(null);

  // --- Engine history state ---
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyErr, setHistoryErr] = useState("");
  const [openIds, setOpenIds] = useState(() => new Set());

  // Presentation
  const [viewMode, setViewMode] = useState("graph");
  const [responseType, setResponseType] = useState("auto");
  const [preferredChartType, setPreferredChartType] = useState("bar");

  // --- Detailed Report ---
  const [reportStatus, setReportStatus] = useState("idle"); // idle | generating | ready
  const [reportOpen, setReportOpen] = useState(false);
  const [reportErr, setReportErr] = useState("");
  const [report, setReport] = useState(null);
  const reportContentRef = useRef(null);

  // Export dropdown inside the report modal
  const [reportExportOpen, setReportExportOpen] = useState(false);
  const exportMenuRef = useRef(null);
  useEffect(() => {
    const handler = (e) => {
      if (!exportMenuRef.current) return;
      if (!exportMenuRef.current.contains(e.target)) setReportExportOpen(false);
    };
    if (reportOpen) document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [reportOpen]);


  // --- Scientific analysis state ---
  const [sciTopic, setSciTopic] = useState("");
  const [sciLoading, setSciLoading] = useState(false);
  const [sciErr, setSciErr] = useState("");
  const [sciItem, setSciItem] = useState(null);
  const [sciList, setSciList] = useState([]);
  const [sciListLoading, setSciListLoading] = useState(false);
  const [sciListErr, setSciListErr] = useState("");
  const [sciOpenIds, setSciOpenIds] = useState(() => new Set());

  const toggleOpen = (id) =>
    setOpenIds((prev) => {
      const n = new Set(prev);
      n.has(id) ? n.delete(id) : n.add(id);
      return n;
    });
  const expandAll = () => setOpenIds(new Set(history.map((h) => h.id)));
  const collapseAll = () => setOpenIds(new Set());

  const toggleSciOpen = (id) =>
    setSciOpenIds((prev) => {
      const n = new Set(prev);
      n.has(id) ? n.delete(id) : n.add(id);
      return n;
    });
  const sciExpandAll = () => setSciOpenIds(new Set(sciList.map((h) => h.id)));
  const sciCollapseAll = () => setSciOpenIds(new Set());

  const refreshHistory = async () => {
    if (!uploadId) return;
    setHistoryLoading(true);
    setHistoryErr("");
    try {
      const lim = 100;
      let ofs = 0;
      let acc = [];
      while (true) {
        const url = engineQueriesUrl(uploadId, lim, ofs);
        const res = await axiosInstance.get(url);
        const d = res.data || {};
        const items = Array.isArray(d?.items) ? d.items : Array.isArray(d) ? d : [];
        acc = acc.concat(items);
        const total = typeof d?.total === "number" ? d.total : undefined;
        if ((total !== undefined && acc.length >= total) || items.length < lim) break;
        ofs += lim;
      }
      acc.sort((a, b) => new Date(b?.created_at || 0) - new Date(a?.created_at || 0));
      setHistory(acc);
    } catch (e) {
      setHistoryErr(e?.response?.data?.message || e.message || "Failed to load previous queries.");
    } finally {
      setHistoryLoading(false);
    }
  };

  const refreshSciList = async () => {
    setSciListLoading(true);
    setSciListErr("");
    try {
      const res = await axiosInstance.get(API_PATHS.ENGINE.SCI_LIST);
      const d = res.data || {};
      const items = Array.isArray(d?.items) ? d.items : [];
      // Most recent first
      items.sort((a, b) => new Date(b?.created_at || 0) - new Date(a?.created_at || 0));
      setSciList(items);
    } catch (e) {
      setSciListErr(e?.response?.data?.message || e.message || "Failed to load scientific analyses.");
    } finally {
      setSciListLoading(false);
    }
  };

  const runEngineQuery = async (textOverride, { respType, chartPref } = {}) => {
    const text = (textOverride ?? queryText ?? "").trim();
    if (!text) return;
    setEngineLoading(true);
    setEngineErr("");
    setEngineItem(null);
    setQueryText("");

    try {
      const effectiveRespType = respType ?? responseType;
      const effectiveChartType = chartPref ?? (effectiveRespType === "chart" ? preferredChartType : undefined);

      const payload = {
        query_text: text,
        upload_ids: [uploadId],
        max_rows_per_table: 100000,
      };
      if (effectiveRespType && effectiveRespType !== "auto") {
        payload.response_type = effectiveRespType;
      }
      if (effectiveRespType === "chart" && effectiveChartType) {
        payload.preferred_chart_type = effectiveChartType;
      }

      const res = await axiosInstance.post(ENGINE_QUERY_PATH, payload, {
        timeout: 120000,
        validateStatus: () => true,
      });

      if (res.status >= 400) {
        const { message } = normalizeEngineError(res);
        setEngineErr(message);
        return;
      }

      const d = res.data || {};
      const first = Array.isArray(d.items) ? d.items[0] : d;
      setEngineItem(first || null);
    } catch (err) {
      const { message } = normalizeEngineError(null, err);
      setEngineErr(message);
    } finally {
      setEngineLoading(false);
    }
  };

  // === Generate report (async; modal opens when ready) ===
  const startGenerateReport = async () => {
    if (reportStatus === "generating") return;
    setReportStatus("generating");
    setReportErr("");
    setReport(null);
    try {
      const topic = (queryText || "Detailed analysis report").trim();
      const payload = {
        topic,
        upload_ids: [uploadId],
        max_rows_per_table: 250000,
        audience: null,
        tone: "concise",
        include_charts: true,
      };
      const res = await axiosInstance.post(ENGINE_REPORT_PATH, payload, {
        timeout: 180000,
        validateStatus: () => true,
      });
      if (res.status >= 400) {
        const { message } = normalizeEngineError(res);
        setReportErr(message);
        setReportStatus("idle");
      } else {
        setReport(res.data || null);
        setReportStatus("ready");
        refreshHistory();
      }
    } catch (err) {
      const { message } = normalizeEngineError(null, err);
      setReportErr(message);
      setReportStatus("idle");
    }
  };

  const exportReportToPdf = () => {
    if (!reportContentRef.current) return;
    const title = report?.title || "Detailed Report";
    const html = reportContentRef.current.innerHTML;

    const popup = window.open("", "_blank", "noopener,noreferrer");
    if (!popup) return;

    // Minimal printable HTML with inline styles (avoids dependency on Tailwind in the new window)
    popup.document.write(`<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>${title}</title>
  <style>
    :root { color-scheme: light; }
    body { font-family: ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,"Apple Color Emoji","Segoe UI Emoji"; color:#111827; padding:24px; }
    h1 { font-size:22px; margin:0 0 8px; font-weight:700; }
    h2 { font-size:16px; margin:18px 0 6px; font-weight:700; border-bottom:1px solid #e5e7eb; padding-bottom:4px; }
    h3 { font-size:14px; margin:14px 0 4px; font-weight:600; }
    p { margin:8px 0; }
    .muted { color:#6b7280; }
    .kpi { display:inline-flex; border:1px solid #e5e7eb; border-radius:8px; padding:8px 10px; margin:6px 8px 0 0; font-size:12px; }
    .chip { display:inline-block; border:1px solid #e5e7eb; border-radius:9999px; padding:4px 8px; margin:4px 6px 0 0; font-size:12px; background:#f9fafb; }
    ul { margin:6px 0 10px 20px; }
    .section { page-break-inside: avoid; }
    @page { margin:16mm; }
    @media print {
      a[href]:after { content:""; }
      .no-print { display:none !important; }
    }
  </style>
</head>
<body>
${html}
</body>
</html>`);
    popup.document.close();
    popup.focus();
    popup.print();
  };

  const runScientificAnalysis = async () => {
    const topic =
      (sciTopic || queryText || meta?.original_name || "").trim() ||
      "Scientific analysis";
    setSciLoading(true);
    setSciErr("");
    setSciItem(null);

    try {
      const payload = {
        topic,
        upload_ids: [uploadId],
        max_rows_per_table: 100000,
        include_charts: true,
      };
      const res = await axiosInstance.post(API_PATHS.ENGINE.SCI_ANALYZE, payload, {
        timeout: 180000,
        validateStatus: () => true,
      });
      if (res.status >= 400) {
        const { message } = normalizeEngineError(res);
        setSciErr(message);
        return;
      }
      setSciItem(res.data || null);
      // Refresh list so the new item appears
      refreshSciList();
    } catch (err) {
      const { message } = normalizeEngineError(null, err);
      setSciErr(message);
    } finally {
      setSciLoading(false);
    }
  };

  const fetchSciOne = async (id) => {
    try {
      const res = await axiosInstance.get(API_PATHS.ENGINE.SCI_GET(id));
      return res.data;
    } catch (e) {
      return null;
    }
  };

  // --- NEW: build clean HTML for Word/PDF exports (independent of Tailwind) ---
const buildReportHTML = (rpt) => {
  const para = (t) =>
    String(t || "")
      .split(/\n{2,}/)
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => `<p>${p.replace(/</g, "&lt;").replace(/>/g, "&gt;")}</p>`)
      .join("");

  const kpiHtml = rpt?.kpis
    ? Object.entries(rpt.kpis)
        .map(
          ([k, v]) =>
            `<span class="kpi"><strong>${k}:</strong> ${
              typeof v === "number" ? v.toLocaleString() : String(v)
            }</span>`
        )
        .join("")
    : "";

  const sectionsHtml = (rpt?.sections || [])
    .map(
      (s) => `
      <section class="section">
        <h2>${s.title || ""}</h2>
        <div>${para(s.content || "")}</div>
      </section>`
    )
    .join("");

  const insightsHtml = Array.isArray(rpt?.insights) && rpt.insights.length
    ? `<section class="section">
         <h2>Key Insights</h2>
         <ul>${rpt.insights.map((x) => `<li>${x}</li>`).join("")}</ul>
       </section>`
    : "";

  const chartsHtml =
    Array.isArray(rpt?.chart_suggestions) && rpt.chart_suggestions.length
      ? `<section class="section">
          <h2>Chart Suggestions</h2>
          <div class="chips">
            ${rpt.chart_suggestions
              .map((c) => {
                const bits = [
                  c.title || c.type,
                  c.x ? `x: ${c.x}` : "",
                  c.y ? `y: ${c.y}` : "",
                  c.series ? `series: ${c.series}` : "",
                ]
                  .filter(Boolean)
                  .join(" • ");
                return `<span class="chip">${bits}</span>`;
              })
              .join("")}
          </div>
        </section>`
      : "";

  return `<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${(rpt?.title || "Detailed Report")
  .replace(/[<>&]/g, "")
  .trim()}</title>
<style>
  :root { color-scheme: light; }
  body { font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; color:#0f172a; background:#ffffff; padding:24px; }
  h1 { font-size:22px; margin:0 0 8px; font-weight:700; color:#0b3a75; }
  h2 { font-size:16px; margin:18px 0 8px; font-weight:700; color:#0b3a75; border-left:4px solid #0b3a75; padding-left:10px; }
  p { margin:8px 0; line-height:1.5; }
  ul { margin:8px 0 8px 22px; }
  .muted { color:#334155; }
  .meta { font-size:12px; color:#1e40af; margin-top:2px; }
  .section { background:#eff6ff; border:1px solid #bfdbfe; border-radius:10px; padding:12px 14px; margin:12px 0; page-break-inside: avoid; }
  .kpi { display:inline-flex; border:1px solid #bfdbfe; background:#ffffff; color:#0b3a75; border-radius:8px; padding:6px 10px; margin:6px 8px 0 0; font-size:12px; }
  .chip { display:inline-block; border:1px solid #bfdbfe; background:#ffffff; color:#0b3a75; border-radius:9999px; padding:4px 10px; margin:4px 6px 0 0; font-size:12px; }
  .chips { margin-top:4px; }
  @page { margin:16mm; }
</style>
</head>
<body>
  <h1>${(rpt?.title || "Detailed Report").replace(/[<>&]/g, "")}</h1>
  <div class="meta">Generated report • ${
    Object.keys(rpt?.used_tables || {}).length
  } data source${Object.keys(rpt?.used_tables || {}).length === 1 ? "" : "s"}</div>

  ${
    rpt?.summary
      ? `<section class="section"><h2>Executive Summary</h2>${para(
          rpt.summary
        )}</section>`
      : ""
  }

  ${insightsHtml}

  ${
    kpiHtml
      ? `<section class="section"><h2>KPIs</h2><div>${kpiHtml}</div></section>`
      : ""
  }

  ${sectionsHtml}

  ${chartsHtml}
</body>
</html>`;
};

  // === FIXED: Export as PDF using html2canvas + jsPDF (robust pagination) ===
  const exportReportAsPDF = async () => {
    if (!report) return;
    // Create a hidden iframe to render our clean HTML (ensures self-contained styling)
    const html = buildReportHTML(report);
    const iframe = document.createElement("iframe");
    iframe.style.position = "fixed";
    iframe.style.left = "-10000px";
    iframe.style.top = "-10000px";
    document.body.appendChild(iframe);
    const doc = iframe.contentDocument || iframe.contentWindow.document;
    doc.open();
    doc.write(html);
    doc.close();

    await new Promise((r) => setTimeout(r, 250)); // allow layout

    const html2canvas = (await import("html2canvas")).default;
    const { jsPDF } = await import("jspdf");

    const target = doc.body; // render whole body
    const canvas = await html2canvas(target, {
      scale: 2,
      backgroundColor: "#ffffff",
      useCORS: true,
      windowWidth: target.scrollWidth,
      windowHeight: target.scrollHeight,
    });

    const pdf = new jsPDF({ unit: "mm", format: "a4" });
    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const margin = 10;
    const contentWidth = pageWidth - margin * 2;

    const mmPerPx = contentWidth / canvas.width;
    const pageHeightPx = (pageHeight - margin * 2) / mmPerPx;

    let y = 0;
    let pageIndex = 0;
    while (y < canvas.height) {
      const sliceHeight = Math.min(pageHeightPx, canvas.height - y);
      const pageCanvas = document.createElement("canvas");
      pageCanvas.width = canvas.width;
      pageCanvas.height = sliceHeight;
      const ctx = pageCanvas.getContext("2d");
      ctx.drawImage(
        canvas,
        0,
        y,
        canvas.width,
        sliceHeight,
        0,
        0,
        canvas.width,
        sliceHeight
      );
      const imgData = pageCanvas.toDataURL("image/jpeg", 0.95);
      if (pageIndex > 0) pdf.addPage();
      pdf.addImage(imgData, "JPEG", margin, margin, contentWidth, sliceHeight * mmPerPx);
      y += sliceHeight;
      pageIndex += 1;
    }

    const filename = `${String(report?.title || "Detailed_Report")
      .replace(/[^\w\s-]/g, "")
      .trim()
      .replace(/\s+/g, "_")}.pdf`;
    pdf.save(filename);

    // cleanup
    document.body.removeChild(iframe);
  };


  // === Export Word (.doc) ===
  const exportReportAsWord = () => {
    if (!report) return;
    const html = buildReportHTML(report);
    const blob = new Blob(["\ufeff", html], { type: "application/msword" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    const filename = `${String(report?.title || "Detailed_Report")
      .replace(/[^\w\s-]/g, "")
      .trim()
      .replace(/\s+/g, "_")}.doc`;
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  // column dropdown
  const [colMenuOpen, setColMenuOpen] = useState(false);
  const colMenuRef = useRef(null);
  useEffect(() => {
    const onClickAway = (e) => {
      if (!colMenuRef.current) return;
      if (!colMenuRef.current.contains(e.target)) setColMenuOpen(false);
    };
    if (colMenuOpen) document.addEventListener("mousedown", onClickAway);
    return () => document.removeEventListener("mousedown", onClickAway);
  }, [colMenuOpen]);


  // export dropdown (table export)
  const [exportOpen, setExportOpen] = useState(false);
  const exportRef = useRef(null);
  const [exporting, setExporting] = useState(false);
  const [exportOptions, setExportOptions] = useState({
    format: "csv",
    scope: "page",
    applyFilter: true,
    includeHidden: false,
  });
  useEffect(() => {
    const onClickAway = (e) => {
      if (!exportRef.current) return;
      if (!exportRef.current.contains(e.target)) setExportOpen(false);
    };
    if (exportOpen) document.addEventListener("mousedown", onClickAway);
    return () => document.removeEventListener("mousedown", onClickAway);
  }, [exportOpen]);


  // resizable split
  const containerRef = useRef(null);
  const [leftWidth, setLeftWidth] = useState(720);
  const [dragging, setDragging] = useState(false);
  const onDragMove = (clientX) => {
    const el = containerRef.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const x = clamp(clientX - rect.left, 320, rect.width - 280);
    setLeftWidth(x);
  };
  const onMouseMove = (e) => dragging && onDragMove(e.clientX);
  const onTouchMove = (e) => {
    if (!dragging) return;
    const t = e.touches[0];
    if (t) onDragMove(t.clientX);
  };
  const endDrag = () => {
    setDragging(false);
    document.body.style.userSelect = "";
  };
  useEffect(() => {
    if (!dragging) return;
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", endDrag);
    window.addEventListener("touchmove", onTouchMove, { passive: false });
    window.addEventListener("touchend", endDrag);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", endDrag);
      window.removeEventListener("touchmove", onTouchMove);
      window.removeEventListener("touchend", endDrag);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dragging]);

  useEffect(() => {
    const el = containerRef.current;
    if (el) {
      const w = el.clientWidth || window.innerWidth || 1200;
      setLeftWidth(clamp(Math.round(w * 0.62), 360, w - 320));
    }
  }, []);

  // meta
  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoadingMeta(true);
      setErrorMeta("");
      try {
        const res = await axiosInstance.get(API_PATHS.UPLOADS.LIST);
        const list = Array.isArray(res.data) ? res.data : [];
        const m = list.find((x) => x.id === uploadId);
        if (!m) throw new Error("Upload not found.");
        if (cancelled) return;
        setMeta(m);
        const firstKey = m.s3_key_json || m.s3_key_parquet || m.s3_key_csv || m.s3_key_raw;
        if (firstKey) setSourceUrl(urlFromKey(firstKey));
      } catch (e) {
        if (!cancelled) setErrorMeta(e?.message || "Failed to load file details.");
      } finally {
        if (!cancelled) setLoadingMeta(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [uploadId]);

  // rows
  const fetchPage = async (newOffset, newLimit) => {
    setLoadingRows(true);
    setErrorRows("");
    try {
      const url = API_PATHS.UPLOADS.ROWS(uploadId, newOffset, newLimit);
      const res = await axiosInstance.get(url);
      const {
        data = [],
        columns = [],
        offset = newOffset,
        limit = newLimit,
        total_rows = 0,
        has_more = false,
        source_key,
      } = res.data || {};
      setRows(Array.isArray(data) ? data : []);
      setColumns(Array.isArray(columns) ? columns : []);
      setOffset(offset);
      setLimit(limit);
      setTotalRows(total_rows);
      setHasMore(Boolean(has_more));
      if (source_key) setSourceUrl(urlFromKey(source_key));
    } catch (e) {
      setErrorRows(e?.response?.data?.message || e?.message || "Failed to load rows.");
    } finally {
      setLoadingRows(false);
    }
  };
  useEffect(() => {
    fetchPage(0, limit);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [uploadId]);

  // history & sci list
  useEffect(() => {
    refreshHistory();
    refreshSciList();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [uploadId]);

  const onPrev = () => offset > 0 && fetchPage(Math.max(0, offset - limit), limit);
  const onNext = () => hasMore && fetchPage(offset + limit, limit);
  const onPrev100 = () => offset > 0 && fetchPage(Math.max(0, offset - 100), 100);
  const onNext100 = () => hasMore && fetchPage(offset + 100, 100);
  const onPageSize = (n) => fetchPage(0, n);

  const download = () => {
    if (!sourceUrl) return;
    const a = document.createElement("a");
    a.href = sourceUrl;
    a.download = meta?.original_name || `file_${uploadId}`;
    document.body.appendChild(a);
    a.click();
    a.remove();
  };

  const allColumns = useMemo(() => {
    if (Array.isArray(columns) && columns.length) return columns;
    const set = new Set();
    rows.forEach((r) => Object.keys(r || {}).forEach((k) => set.add(k)));
    return Array.from(set);
  }, [columns, rows]);

  const visibleColumns = useMemo(
    () => allColumns.filter((c) => !droppedCols.has(c)),
    [allColumns, droppedCols]
  );

  const Section = ({ title, children }) => (
    <section className="mb-5 rounded-lg border border-blue-200 bg-blue-50/60 p-3">
      <h3 className="mb-2 border-l-4 border-blue-800 pl-3 text-sm font-semibold text-blue-900 uppercase tracking-wide">
        {title}
      </h3>
      <div className="prose prose-sm max-w-none text-slate-800">{children}</div>
    </section>
  );

  const ReportBody = ({ rpt }) => {
    const paraSplit = (text) =>
      String(text || "")
        .split(/\n{2,}/)
        .map((p) => p.trim())
        .filter(Boolean);

    return (
      <div ref={reportContentRef} className="px-1 pb-2">
        <div className="mb-4">
          <h1 className="text-xl font-bold text-blue-900">{rpt.title}</h1>
          <div className="mt-1 text-xs text-blue-700">
            Generated report • {Object.keys(rpt.used_tables || {}).length} data
            source{Object.keys(rpt.used_tables || {}).length === 1 ? "" : "s"}
          </div>
        </div>

        {rpt.summary && (
          <Section title="Executive Summary">
            {paraSplit(rpt.summary).map((p, i) => (
              <p key={i} className="mb-2">
                {p}
              </p>
            ))}
          </Section>
        )}

        {Array.isArray(rpt.insights) && rpt.insights.length > 0 && (
            <Section title="Key Insights">
              <ul className="list-disc pl-6">
                {rpt.insights.map((s, i) => (
                  <li key={i} className="mb-1">
                    {s}
                  </li>
                ))}
              </ul>
            </Section>
          )}

        {rpt.kpis && Object.keys(rpt.kpis).length > 0 && (
          <Section title="KPIs">
            <div className="flex flex-wrap gap-2">
              {Object.entries(rpt.kpis).map(([k, v]) => (
                <div
                  key={k}
                  className="rounded-md border border-blue-200 bg-white px-3 py-2 text-sm text-blue-900 shadow-sm"
                >
                  <span className="font-semibold">{k}:</span>{" "}
                  {typeof v === "number" ? v.toLocaleString() : String(v)}
                </div>
              ))}
            </div>
          </Section>
        )}

        {Array.isArray(rpt.sections) &&
          rpt.sections.map((s, idx) => (
            <Section key={`${s.title}-${idx}`} title={s.title}>
              {paraSplit(s.content).map((p, i) => (
                <p key={i} className="mb-2">
                  {p}
                </p>
              ))}
            </Section>
          ))}

        {Array.isArray(rpt.chart_suggestions) &&
          rpt.chart_suggestions.length > 0 && (
            <Section title="Chart Suggestions">
              <div className="flex flex-wrap gap-2">
                {rpt.chart_suggestions.map((c, i) => (
                  <div
                    key={i}
                    className="rounded-full border border-blue-200 bg-white px-3 py-1 text-xs text-blue-900"
                  >
                    <span className="font-medium">{c.title || c.type}</span>
                    {c.x ? ` • x: ${c.x}` : ""}
                    {c.y ? ` • y: ${c.y}` : ""}
                    {c.series ? ` • series: ${c.series}` : ""}
                  </div>
                ))}
              </div>
            </Section>
          )}
      </div>
    );
  };


  const reportBtnLabel =
    reportStatus === "generating"
      ? "Generating report…"
      : reportStatus === "ready"
      ? "Report ready"
      : "Detailed report";

  const onReportButtonClick = () => {
    if (reportStatus === "idle") {
      startGenerateReport();
    } else if (reportStatus === "ready") {
      setReportOpen(true);
      setReportStatus("idle");
    }
  };
  const toggleColumn = (name) =>
    setDroppedCols((prev) => {
      const n = new Set(prev);
      n.has(name) ? n.delete(name) : n.add(name);
      return n;
    });
  const selectAll = () => setDroppedCols(new Set());
  const clearAll = () => setDroppedCols(new Set(allColumns));

  const exportCols = exportOptions.includeHidden ? allColumns : visibleColumns;

  const applyClientFilter = (inRows) => {
    const term = (q || "").trim().toLowerCase();
    if (!term) return inRows;
    return inRows.filter((r) => Object.values(r ?? {}).some((v) => stringifyCell(v).toLowerCase().includes(term)));
  };
  const rowsForPage = useMemo(() => applyClientFilter(rows), [rows, q]);

  const fetchAllRows = async () => {
    const pageSize = Math.max(1000, limit);
    let ofs = 0;
    let keepGoing = true;
    const acc = [];
    while (keepGoing) {
      const url = API_PATHS.UPLOADS.ROWS(uploadId, ofs, pageSize);
      // eslint-disable-next-line no-await-in-loop
      const res = await axiosInstance.get(url);
      const {
        data = [],
        has_more = false,
        total_rows: tr = totalRows,
      } = res.data || {};
      acc.push(...(Array.isArray(data) ? data : []));
      ofs += pageSize;
      keepGoing = Boolean(has_more);
      if (!has_more && acc.length < tr && data.length > 0) {
        keepGoing = data.length === pageSize;
      }
      if (!data.length) break;
    }
    return acc;
  };

  const doExport = async () => {
    try {
      setExporting(true);
      const base =
        meta?.original_name?.replace(/\.[^/.]+$/, "") || `file_${uploadId}`;
      const cols = exportCols;

      let data = [];
      if (exportOptions.scope === "all") {
        const all = await fetchAllRows();
        data = applyClientFilter(all);
      } else {
        data = rowsForPage;
      }

      if (exportOptions.format === "json") {
        const out = data.map((row) => {
          const obj = {};
          cols.forEach((c) => {
            obj[c] = row?.[c];
          });
          return obj;
        });
        const blob = new Blob([JSON.stringify(out, null, 2)], {
          type: "application/json;charset=utf-8;",
        });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `${base}_export.json`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(url);
        setExportOpen(false);
        return;
      }

      if (exportOptions.format === "xlsx") {
        const XLSX = await import("xlsx");
        const aoa = [
          cols,
          ...data.map((row) => cols.map((c) => stringifyCell(row?.[c]))),
        ];
        const ws = XLSX.utils.aoa_to_sheet(aoa);
        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, "Export");
        XLSX.writeFile(wb, `${base}_export.xlsx`);
        setExportOpen(false);
        return;
      }

      // CSV
      const header = cols.join(",");
      const lines = data.map((row) =>
        cols.map((c) => escapeCSV(stringifyCell(row?.[c]))).join(",")
      );
      const csv = [header, ...lines].join("\n");
      const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${base}_export.csv`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      setExportOpen(false);
    } finally {
      setExporting(false);
    }
  };

  const fmtDate = (iso) => {
    try { return new Date(iso).toLocaleString(); } catch { return String(iso || ""); }
  };

  return (
    <DashboardLayout activeMenu="Files">
      <div className="m-3 space-y-4 min-w-0">
        {/* back + actions */}
        <div className="flex items-center justify-between">
          <button
            onClick={() => navigate("/admin/files")}
            className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900"
          >
            <LuArrowLeft className="text-base" />
            <span>Back to Files</span>
          </button>

          <div className="flex items-center gap-3">
            {meta && (
              <div className="text-xs text-gray-500">
                <span className="font-medium">{meta.original_name}</span>{" "}
                {" • "}
                <span>{meta.content_type || meta.ext}</span>{" • "}
                <span>{formatBytes(meta.size_bytes || 0)}</span>{" • "}
                <span className="capitalize">{meta.status}</span>
              </div>
            )}
            {sourceUrl && (
              <>
                <a
                  href={sourceUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-indigo-600 hover:underline"
                  title="Open source"
                >
                  <LuLink /> Source
                </a>
                <button
                  onClick={download}
                  className="inline-flex items-center gap-2 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  <LuDownload />
                  Download
                </button>
              </>
            )}
          </div>
        </div>

         <div className="row">
          <div className="flex flex-wrap items-center justify-between gap-2">
                {/* Detailed report async button */}
                <div className="relative">
                  <button
                    onClick={onReportButtonClick}
                    disabled={reportStatus === "generating"}
                    className={`inline-flex items-center justify-center gap-2 rounded-lg border px-4 py-2 text-sm font-medium ${
                      reportStatus === "ready"
                        ? "border-green-600 bg-green-600 text-white hover:bg-green-700"
                        : "border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                    } disabled:opacity-50`}
                    title={
                      reportStatus === "ready"
                        ? "Open the generated report"
                        : "Generate a detailed narrative report from this data"
                    }
                  >
                    <LuFileText />
                    {reportBtnLabel}
                  </button>
                  {reportErr && reportStatus !== "generating" && (
                    <div className="mt-1 text-xs text-red-600">{reportErr}</div>
                  )}
                </div>

                <div className="flex items-center gap-2">
                  {/* Column selector dropdown */}
                  <div className="relative" ref={colMenuRef}>
                    <button
                      type="button"
                      onClick={() => setColMenuOpen((v) => !v)}
                      disabled={!allColumns.length}
                      className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                      title="Show/Hide columns"
                    >
                      Columns
                      <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-700">
                        {visibleColumns.length}/{allColumns.length}
                      </span>
                      <LuChevronDown className="text-base" />
                    </button>

                    {colMenuOpen && (
                      <div
                        className="absolute right-0 z-20 mt-2 w-72 rounded-xl border border-gray-200 bg-white shadow-lg"
                        role="menu"
                      >
                        <div className="flex items-center justify-between border-b px-3 py-2">
                          <div className="text-sm font-medium">Columns</div>
                          <div className="flex gap-2">
                            <button
                              onClick={selectAll}
                              className="text-xs text-gray-600 hover:text-gray-900 underline underline-offset-2"
                            >
                              Select all
                            </button>
                            <button
                              onClick={clearAll}
                              className="text-xs text-gray-600 hover:text-gray-900 underline underline-offset-2"
                            >
                              Clear all
                            </button>
                          </div>
                        </div>
                        <div className="max-h-80 overflow-auto p-2">
                          {allColumns.map((c) => {
                            const checked = !droppedCols.has(c);
                            return (
                              <label
                                key={c}
                                className="flex items-center gap-2 rounded-md px-2 py-1 text-sm hover:bg-gray-50 cursor-pointer"
                              >
                                <input
                                  type="checkbox"
                                  className="h-4 w-4 rounded border-gray-300"
                                  checked={checked}
                                  onChange={() => toggleColumn(c)}
                                />
                                <span className="truncate" title={c}>
                                  {c}
                                </span>
                              </label>
                            );
                          })}
                          {!allColumns.length && (
                            <div className="px-2 py-3 text-sm text-gray-500">
                              No columns.
                            </div>
                          )}
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Export dropdown (table export) */}
                  <div className="relative" ref={exportRef}>
                    <button
                      onClick={() => setExportOpen((v) => !v)}
                      disabled={exporting}
                      className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                      title="Export data"
                    >
                      <LuDownload />
                      {exporting ? "Exporting…" : "Export"}
                      <LuChevronDown className="text-base" />
                    </button>

                    {exportOpen && (
                      <div className="absolute right-0 z-20 mt-2 w-80 rounded-xl border border-gray-200 bg-white shadow-lg">
                        <div className="border-b px-3 py-2">
                          <div className="text-sm font-medium">Export options</div>
                          <p className="text-xs text-gray-500">
                            Exports the data currently loaded in state or the entire dataset.
                          </p>
                        </div>

                        <div className="p-3 space-y-3">
                          {/* Format */}
                          <div className="space-y-1">
                            <div className="text-xs font-medium text-gray-700">Format</div>
                            <div className="flex flex-wrap items-center gap-3">
                              <label className="inline-flex items-center gap-2 text-sm">
                                <input
                                  type="radio"
                                  name="export-format"
                                  value="csv"
                                  checked={exportOptions.format === "csv"}
                                  onChange={() =>
                                    setExportOptions((o) => ({ ...o, format: "csv" }))
                                  }
                                />
                                CSV
                              </label>
                              <label className="inline-flex items-center gap-2 text-sm">
                                <input
                                  type="radio"
                                  name="export-format"
                                  value="json"
                                  checked={exportOptions.format === "json"}
                                  onChange={() =>
                                    setExportOptions((o) => ({ ...o, format: "json" }))
                                  }
                                />
                                JSON
                              </label>
                              <label className="inline-flex items-center gap-2 text-sm">
                                <input
                                  type="radio"
                                  name="export-format"
                                  value="xlsx"
                                  checked={exportOptions.format === "xlsx"}
                                  onChange={() =>
                                    setExportOptions((o) => ({ ...o, format: "xlsx" }))
                                  }
                                />
                                Excel (.xlsx)
                              </label>
                            </div>
                          </div>

                          {/* Scope */}
                          <div className="space-y-1">
                            <div className="text-xs font-medium text-gray-700">Scope</div>
                            <div className="flex flex-col gap-2">
                              <label className="inline-flex items-center gap-2 text-sm">
                                <input
                                  type="radio"
                                  name="export-scope"
                                  value="page"
                                  checked={exportOptions.scope === "page"}
                                  onChange={() =>
                                    setExportOptions((o) => ({ ...o, scope: "page" }))
                                  }
                                />
                                Current page only
                              </label>
                              <label className="inline-flex items-center gap-2 text-sm">
                                <input
                                  type="radio"
                                  name="export-scope"
                                  value="all"
                                  checked={exportOptions.scope === "all"}
                                  onChange={() =>
                                    setExportOptions((o) => ({ ...o, scope: "all" }))
                                  }
                                />
                                Entire dataset (all pages)
                              </label>
                            </div>
                          </div>

                          {/* Filter */}
                          <div className="space-y-1">
                            <div className="text-xs font-medium text-gray-700">Filter</div>
                            <label className="flex items-center gap-2 text-sm">
                              <input
                                type="checkbox"
                                checked={exportOptions.applyFilter}
                                onChange={(e) =>
                                  setExportOptions((o) => ({
                                    ...o,
                                    applyFilter: e.target.checked,
                                  }))
                                }
                              />
                              Apply current filter text
                            </label>
                          </div>

                          {/* Columns */}
                          <div className="space-y-1">
                            <div className="text-xs font-medium text-gray-700">Columns</div>
                            <label className="flex items-center gap-2 text-sm">
                              <input
                                type="checkbox"
                                checked={exportOptions.includeHidden}
                                onChange={(e) =>
                                  setExportOptions((o) => ({
                                    ...o,
                                    includeHidden: e.target.checked,
                                  }))
                                }
                              />
                              Include hidden columns
                            </label>
                          </div>

                          {/* Summary */}
                          <div className="rounded-md bg-gray-50 px-3 py-2 text-xs text-gray-600">
                            {exportOptions.scope === "all" ? (
                              <>
                                Will fetch and export up to{" "}
                                <span className="font-medium">
                                  {totalRows.toLocaleString()}
                                </span>{" "}
                                rows ×{" "}
                                <span className="font-medium">
                                  {exportCols.length.toLocaleString()}
                                </span>{" "}
                                columns ({exportOptions.format.toUpperCase()}).
                              </>
                            ) : (
                              <>
                                Will export{" "}
                                <span className="font-medium">
                                  {rowsForPage.length.toLocaleString()}
                                </span>{" "}
                                rows ×{" "}
                                <span className="font-medium">
                                  {exportCols.length.toLocaleString()}
                                </span>{" "}
                                columns ({exportOptions.format.toUpperCase()}).
                              </>
                            )}
                          </div>

                          <div className="flex justify-end gap-2 pt-1">
                            <button
                              onClick={() => setExportOpen(false)}
                              className="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                            >
                              Cancel
                            </button>
                            <button
                              onClick={doExport}
                              disabled={exporting}
                              className="rounded-lg border border-indigo-600 bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
                            >
                              {exporting ? "Exporting…" : "Export"}
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
        </div>

        {/* Tabs */}
        <div className="flex items-center gap-2 border-b border-gray-200">
          <button
            onClick={() => setTab("query")}
            className={`px-3 py-2 text-sm font-medium ${
              tab === "query" ? "border-b-2 border-indigo-600 text-indigo-700" : "text-gray-600 hover:text-gray-900"
            }`}
          >
            Query
          </button>
          <button
            onClick={() => setTab("science")}
            className={`px-3 py-2 text-sm font-medium ${
              tab === "science" ? "border-b-2 border-indigo-600 text-indigo-700" : "text-gray-600 hover:text-gray-900"
            }`}
          >
            Scientific Analysis
          </button>
        </div>

        {/* Split view */}
        <div
          ref={containerRef}
          className="relative flex w-full min-w-0 rounded-xl border border-gray-200 shadow-sm"
          style={{ minHeight: "70vh" }}
        >
          {/* LEFT PANE (Table) */}
          <div className="min-w-0 p-3" style={{ width: leftWidth }}>
            <JsonChunkTable
              rows={rows}
              columns={visibleColumns}
              loading={loadingRows || loadingMeta}
              error={errorRows}
              q={q}
              offset={offset}
              limit={limit}
              totalRows={totalRows}
              hasPrev={offset > 0}
              hasNext={hasMore}
              onPrev={onPrev}
              onNext={onNext}
              onPrev100={onPrev100}
              onNext100={onNext100}
              onPageSize={onPageSize}
            />
          </div>

          {/* DRAG HANDLE */}
          <div
            onPointerDown={(e) => {
              if (e.cancelable) e.preventDefault();
              setDragging(true);
              e.currentTarget.setPointerCapture?.(e.pointerId);
              document.body.style.userSelect = "none";
            }}
            className="relative z-10 w-2 cursor-col-resize hover:bg-indigo-200 active:bg-indigo-300"
            style={{ touchAction: "none" }}
            title="Drag to resize"
          >
            <div className="absolute inset-y-0 left-0 right-0 m-auto h-full w-px bg-gray-300" />
          </div>

          {/* RIGHT PANE */}
          <div className="min-w-[300px] flex-1 p-3 border-l border-gray-200 bg-gray-50">
            {tab === "query" ? (
              <div className="space-y-3">
                <div>
                  <h3 className="text-sm font-medium text-gray-800">Query</h3>
                  <p className="text-xs text-gray-500">
                    Ask a plain-English question about this file. We’ll run it and show the result below.
                  </p>
                </div>

                <textarea
                  value={queryText}
                  onChange={(e) => setQueryText(e.target.value)}
                  placeholder='e.g. "Show monthly sales by region"'
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none h-28 bg-white"
                />

                <div className="flex flex-wrap items-center gap-2">
                  <button
                    onClick={() => {
                      const t = queryText;
                      setQ(t);
                      runEngineQuery(t);
                    }}
                    disabled={engineLoading || !queryText.trim()}
                    className="inline-flex items-center justify-center gap-2 rounded-lg border border-indigo-600 bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-60"
                  >
                    <LuSend />
                    {engineLoading ? "Running…" : "Apply"}
                  </button>
                  <button
                    onClick={() => {
                      setQueryText("");
                      setQ("");
                      setEngineErr("");
                      setEngineItem(null);
                    }}
                    className="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                  >
                    Clear
                  </button>

                  <div className="ml-auto flex items-center gap-2">
                    <label className="text-xs text-gray-600">View</label>
                    <select
                      value={viewMode}
                      onChange={(e) => setViewMode(e.target.value)}
                      className="rounded-md border border-gray-300 bg-white px-2 py-1 text-xs"
                    >
                      <option value="graph">Graph</option>
                      <option value="analysis">Analysis</option>
                    </select>
                  </div>
                </div>

                {/* Response type and chart preference (kept) */}
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-2">
                    <label className="text-xs text-gray-600">Response</label>
                    <select
                      value={responseType}
                      onChange={(e) => setResponseType(e.target.value)}
                      className="rounded-md border border-gray-300 bg-white px-2 py-1 text-xs"
                      title="Choose what the engine should return"
                    >
                      <option value="auto">Auto</option>
                      <option value="chart">Chart</option>
                      <option value="analysis">Analysis</option>
                      <option value="fpa">FPA</option>
                      <option value="table">Table</option>
                    </select>
                  </div>

                  {responseType === "chart" && (
                    <div className="flex items-center gap-2">
                      <label className="text-xs text-gray-600">Chart</label>
                      <select
                        value={preferredChartType}
                        onChange={(e) => setPreferredChartType(e.target.value)}
                        className="rounded-md border border-gray-300 bg-white px-2 py-1 text-xs"
                        title="Preferred chart style"
                      >
                        <option value="bar">Bar (vertical)</option>
                        <option value="line">Line</option>
                        <option value="histogram">Histogram</option>
                        <option value="pie">Pie</option>
                        <option value="scatter">Scatter</option>
                      </select>
                    </div>
                  )}

                  <button
                    onClick={refreshHistory}
                    disabled={historyLoading}
                    className="inline-flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
                    title="Reload previous queries"
                  >
                    <LuRefreshCw className={historyLoading ? "animate-spin" : ""} />
                    Refresh
                  </button>
                </div>

                {/* Current engine response */}
                {engineErr && (
                  <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                    {engineErr}
                  </div>
                )}
                {engineLoading && (
                  <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
                    Working on it…
                  </div>
                )}
                {engineItem && (
                  <EngineResponse
                    item={engineItem}
                    viewMode={viewMode}
                    chartType={preferredChartType}
                  />
                )}

                {/* Previous queries */}
                <div className="pt-2">
                  <div className="mb-2 flex items-center justify-between">
                    <div className="text-sm font-medium text-gray-800">
                      Previous queries ({history.length})
                    </div>
                    <div className="flex items-center gap-2">
                      <button onClick={expandAll} className="text-xs text-gray-600 hover:text-gray-900 underline underline-offset-2">
                        Expand all
                      </button>
                      <button onClick={collapseAll} className="text-xs text-gray-600 hover:text-gray-900 underline underline-offset-2">
                        Collapse all
                      </button>
                    </div>
                  </div>

                  {historyErr && (
                    <div className="mb-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                      {historyErr}
                    </div>
                  )}

                  {historyLoading ? (
                    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
                      Loading history…
                    </div>
                  ) : history.length === 0 ? (
                    <div className="rounded-md border border-dashed border-gray-300 bg-white px-3 py-6 text-center text-sm text-gray-500">
                      No previous queries for this upload yet.
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {history.map((it) => {
                        const open = openIds.has(it.id);
                        return (
                          <div key={it.id} className="rounded-lg border border-gray-200 bg-white">
                            <button
                              onClick={() => toggleOpen(it.id)}
                              className="flex w-full items-center gap-2 px-3 py-2 text-left hover:bg-gray-50"
                            >
                              {open ? <LuChevronDownSm /> : <LuChevronRight />}
                              <div className="min-w-0 flex-1">
                                <div className="truncate text-sm font-medium text-gray-900" title={it.question || it.query_text}>
                                  {it.question || it.query_text || "(no title)"}
                                </div>
                                <div className="text-xs text-gray-500">
                                  {fmtDate(it.created_at)} •{" "}
                                  {it.chart ? "chart" : it.table ? "table" : it.intent || "insight"} •{" "}
                                  {it.status || "completed"}
                                </div>
                              </div>
                            </button>
                            {open && (
                              <div className="px-3 pb-3">
                                <EngineResponse
                                  item={it}
                                  viewMode={viewMode}
                                  chartType={preferredChartType}
                                />
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            ) : (
              // Scientific Analysis Tab
              <div className="space-y-3">
                <div>
                  <h3 className="text-sm font-medium text-gray-800">Scientific Analysis</h3>
                  <p className="text-xs text-gray-500">
                    Generate a CRISP-DM style scientific analysis with steps, sections, KPIs and chart previews.
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <input
                    value={sciTopic}
                    onChange={(e) => setSciTopic(e.target.value)}
                    placeholder='Topic (e.g., "Churn Drivers in Q3 dataset")'
                    className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white"
                  />
                  <button
                    onClick={runScientificAnalysis}
                    disabled={sciLoading}
                    className="inline-flex items-center justify-center gap-2 rounded-lg border border-indigo-600 bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-60"
                  >
                    <LuPlay />
                    {sciLoading ? "Generating…" : "Generate"}
                  </button>
                </div>

                {sciErr && (
                  <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                    {sciErr}
                  </div>
                )}
                {sciLoading && (
                  <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
                    Working on it…
                  </div>
                )}
                {sciItem && <ScientificAnalysis item={sciItem} />}

                {/* Previous Scientific Analyses */}
                <div className="pt-2">
                  <div className="mb-2 flex items-center justify-between">
                    <div className="text-sm font-medium text-gray-800">
                      Previous scientific analyses ({sciList.length})
                    </div>
                    <div className="flex items-center gap-2">
                      <button onClick={sciExpandAll} className="text-xs text-gray-600 hover:text-gray-900 underline underline-offset-2">
                        Expand all
                      </button>
                      <button onClick={sciCollapseAll} className="text-xs text-gray-600 hover:text-gray-900 underline underline-offset-2">
                        Collapse all
                      </button>
                      <button
                        onClick={refreshSciList}
                        disabled={sciListLoading}
                        className="inline-flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
                        title="Reload scientific analyses"
                      >
                        <LuRefreshCw className={sciListLoading ? "animate-spin" : ""} />
                        Refresh
                      </button>
                    </div>
                  </div>

                  {sciListErr && (
                    <div className="mb-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                      {sciListErr}
                    </div>
                  )}

                  {sciListLoading ? (
                    <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
                      Loading…
                    </div>
                  ) : sciList.length === 0 ? (
                    <div className="rounded-md border border-dashed border-gray-300 bg-white px-3 py-6 text-center text-sm text-gray-500">
                      No scientific analyses yet.
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {sciList.map((it) => {
                        const open = sciOpenIds.has(it.id);
                        return (
                          <div key={it.id} className="rounded-lg border border-gray-200 bg-white">
                            <button
                              onClick={async () => {
                                if (!open) {
                                  // fetch full details lazily
                                  const full = await fetchSciOne(it.id);
                                  if (full) {
                                    setSciItem(full); // also show on top area
                                  }
                                }
                                toggleSciOpen(it.id);
                              }}
                              className="flex w-full items-center gap-2 px-3 py-2 text-left hover:bg-gray-50"
                            >
                              {open ? <LuChevronDownSm /> : <LuChevronRight />}
                              <div className="min-w-0 flex-1">
                                <div className="truncate text-sm font-medium text-gray-900" title={it.title || it.topic}>
                                  {it.title || it.topic || "(no title)"}
                                </div>
                                <div className="text-xs text-gray-500">
                                  {fmtDate(it.created_at)} • {it.status || "completed"}
                                </div>
                              </div>
                            </button>
                            {open && (
                              <div className="px-3 pb-3">
                                {/* Use the latest fetched full item if it matches id, else a lightweight header */}
                                {sciItem && sciItem.id === it.id ? (
                                  <ScientificAnalysis item={sciItem} />
                                ) : (
                                  <div className="text-sm text-gray-600 px-2 py-2">
                                    Opened. Click refresh (top-right) if details didn’t load.
                                  </div>
                                )}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Drag overlay */}
          {dragging && (
            <div className="absolute inset-0 cursor-col-resize" onMouseUp={endDrag} onTouchEnd={endDrag} />
          )}
        </div>

        {/* Error display */}
        {errorMeta && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {errorMeta}
          </div>
        )}
        {errorRows && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {errorRows}
          </div>
        )}
      </div>
      
    </DashboardLayout>
  );
};

export default ViewFile;
