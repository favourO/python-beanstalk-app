// src/pages/admin/FilesAndAssets.jsx
import React, { useEffect, useMemo, useRef, useState } from "react";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import { useNavigate } from "react-router-dom";
import {
  LuCloudUpload,
  LuX,
  LuTrash2,
  LuFileText,
  LuFileCheck2,
  LuArrowLeft,
} from "react-icons/lu";

/* ---------- helpers ---------- */
const MAX_SIZE = 50 * 1024 * 1024; // 50 MB

const formatBytes = (bytes, decimals = 1) => {
  if (!+bytes) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(decimals < 0 ? 0 : decimals))} ${sizes[i]}`;
};

const getKind = (file) => {
  const t = (file.type || "").toLowerCase();
  const n = (file.name || "").toLowerCase();
  if (t === "text/csv" || n.endsWith(".csv")) return "csv";
  if (
    t === "application/vnd.ms-excel" ||
    t === "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ||
    n.endsWith(".xls") ||
    n.endsWith(".xlsx")
  ) return "excel";
  if (t === "application/pdf" || n.endsWith(".pdf")) return "pdf";
  return "other";
};

// allowed: csv-only, excel-only, csv+excel, pdf-only
const isAllowedCombo = (kinds) => {
  const s = new Set(kinds);
  if (s.has("other")) return false;
  if (s.size === 1 && (s.has("csv") || s.has("excel") || s.has("pdf"))) return true;
  if (s.size === 2 && s.has("csv") && s.has("excel")) return true;
  return false;
};

const FileBadge = ({ file, previewUrl }) => {
  const isImg = (file.type || "").startsWith("image/");
  return (
    <div className="w-16 h-16 flex items-center justify-center rounded-xl bg-gray-100 overflow-hidden">
      {isImg && previewUrl ? (
        <img src={previewUrl} alt={file.name} className="w-full h-full object-cover" />
      ) : (
        <LuFileText className="text-2xl text-gray-500" />
      )}
    </div>
  );
};

/* ---------- page ---------- */
const FilesAndAssets = () => {
  const navigate = useNavigate();

  // local selection (pre-upload)
  const [files, setFiles] = useState([]); 
  const [dragActive, setDragActive] = useState(false);
  const [globalError, setGlobalError] = useState("");

  // oversize banner
  const [oversizeFound, setOversizeFound] = useState(false);
  const [oversizeNames, setOversizeNames] = useState([]);

  // server (old uploads)
  const [serverFiles, setServerFiles] = useState([]);

  // recent uploads (from last POST only)
  const [recentUploads, setRecentUploads] = useState([]);
  const [showRecentMergePrompt, setShowRecentMergePrompt] = useState(false);
  const [recentMergeIds, setRecentMergeIds] = useState(new Set());
  const [recentMergeName, setRecentMergeName] = useState("");

  // pagination for old files (client-side)
  const [page, setPage] = useState(1);
  const pageSize = 10;
  const totalPages = Math.max(1, Math.ceil(serverFiles.length / pageSize));
  const pageItems = useMemo(() => {
    const start = (page - 1) * pageSize;
    return serverFiles.slice(start, start + pageSize);
  }, [serverFiles, page]);

  // NEW: bulk delete mode + selection
  const [deleteMode, setDeleteMode] = useState(false);
  const [deleteSel, setDeleteSel] = useState(new Set()); // selected ids
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [deleteMsg, setDeleteMsg] = useState(""); // success/error banner

  const fileInputRef = useRef(null);

  const selectableCount = files.length;
  const canUpload = selectableCount > 0 && files.some((f) => !f.uploaded && !f.error);

  const ACCEPT = [
    ".csv",
    ".xls",
    ".xlsx",
    "text/csv",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/pdf",
  ].join(",");

  /* ----- add files (respect rules) ----- */
  const addFiles = (list) => {
    const incoming = Array.from(list || []);
    if (!incoming.length) return;

    setFiles((prev) => {
      const existing = new Set(prev.map((p) => `${p.file.name}_${p.file.size}_${p.file.lastModified}`));
      let kindsSoFar = new Set(prev.map((p) => getKind(p.file)));
      let err = "";
      const accepted = [];
      const tooBig = [];

      for (const f of incoming) {
        if (f.size > MAX_SIZE) { tooBig.push(`${f.name} (${formatBytes(f.size)})`); continue; }
        const key = `${f.name}_${f.size}_${f.lastModified}`;
        if (existing.has(key)) continue;

        const k = getKind(f);
        if (k === "other") { err = "Only CSV, Excel (XLS/XLSX), or PDF files are allowed."; continue; }

        const test = new Set(kindsSoFar); test.add(k);
        if (!isAllowedCombo(test)) {
          if (k === "pdf" && kindsSoFar.has("excel")) err = "Cannot upload PDF and Excel together.";
          else if (k === "pdf" && kindsSoFar.has("csv")) err = "Cannot upload PDF and CSV together.";
          else if ((k === "excel" && kindsSoFar.has("pdf")) || (k === "csv" && kindsSoFar.has("pdf")))
            err = "Cannot upload PDF with other file types.";
          else err = "Allowed: CSV-only, Excel-only, CSV+Excel, or PDF-only.";
          continue;
        }

        accepted.push({
          id: crypto.randomUUID(),
          file: f,
          previewUrl: (f.type || "").startsWith("image/") ? URL.createObjectURL(f) : null,
          progress: 0,
          uploaded: false,
          error: null,
        });
        kindsSoFar = test;
      }

      if (tooBig.length) {
        setOversizeFound(true);
        setOversizeNames(tooBig);
      }

      setGlobalError(err);
      return [...prev, ...accepted];
    });
  };

  useEffect(() => () => files.forEach((f) => f.previewUrl && URL.revokeObjectURL(f.previewUrl)), [files]);

  const onDrop = (e) => { e.preventDefault(); e.stopPropagation(); setDragActive(false);
    if (e.dataTransfer?.files?.length) addFiles(e.dataTransfer.files); };
  const onDragOver = (e) => { e.preventDefault(); e.stopPropagation(); setDragActive(true); };
  const onDragLeave = (e) => { e.preventDefault(); e.stopPropagation(); setDragActive(false); };

  const onFileChange = (e) => { if (e.target.files?.length) addFiles(e.target.files); e.target.value = ""; };

  const removeOne = (id) => {
    setFiles((prev) => {
      const it = prev.find((x) => x.id === id);
      if (it?.previewUrl) URL.revokeObjectURL(it.previewUrl);
      return prev.filter((x) => x.id !== id);
    });
  };
  const clearAll = () => {
    files.forEach((f) => f.previewUrl && URL.revokeObjectURL(f.previewUrl));
    setFiles([]); setGlobalError("");
  };

  /* ----- server list (old uploads) ----- */
  const fetchServerFiles = async () => {
    try {
      const res = await axiosInstance.get(API_PATHS.UPLOADS.LIST);
      setServerFiles(Array.isArray(res.data) ? res.data : []);
    } catch (e) {
      console.error("Failed to fetch uploads:", e);
    }
  };
  useEffect(() => { fetchServerFiles(); }, []);

  /* ----- upload (multiple in one request, key: files) ----- */
  const uploadAll = async () => {
    const pending = files.filter((f) => !f.uploaded && !f.error);
    if (!pending.length) return;

    const kinds = new Set(pending.map((f) => getKind(f.file)));
    if (!isAllowedCombo(kinds)) {
      setGlobalError("Invalid selection. Allowed: CSV-only, Excel-only, CSV+Excel, or PDFs-only.");
      return;
    }

    const form = new FormData();
    pending.forEach((p) => form.append("files", p.file));

    // composite progress split by file sizes
    const sizes = pending.map((p) => p.file.size);
    const boundaries = sizes.reduce((arr, size, i) => {
      const start = i === 0 ? 0 : arr[i - 1].end;
      arr.push({ id: pending[i].id, start, end: start + size, size });
      return arr;
    }, []);

    try {
      const res = await axiosInstance.post(API_PATHS.UPLOADS.UPLOAD, form, {
        headers: { "Content-Type": "multipart/form-data" },
        onUploadProgress: (evt) => {
          if (!evt.total) return;
          const loaded = evt.loaded;
          setFiles((prev) =>
            prev.map((f) => {
              const b = boundaries.find((b) => b.id === f.id);
              if (!b) return f;
              const segLoaded = Math.min(Math.max(loaded - b.start, 0), b.size);
              const pct = Math.round((segLoaded * 100) / b.size);
              return { ...f, progress: pct };
            })
          );
        },
      });

      // mark local as uploaded
      setFiles((prev) => prev.map((f) => (pending.some((p) => p.id === f.id) ? { ...f, uploaded: true, progress: 100 } : f)));

      // recent section
      let recents = Array.isArray(res?.data) ? res.data : [];
      if (!recents.length) {
        await fetchServerFiles();
        const names = new Set(pending.map((p) => p.file.name));
        recents = serverFiles.filter((sf) => names.has(sf.original_name));
      }
      setRecentUploads(recents || []);
      setShowRecentMergePrompt(true);
      setRecentMergeIds(new Set());
      setRecentMergeName("");

      await fetchServerFiles();
    } catch (err) {
      const msg = err?.response?.data?.message || err.message || "Upload failed";
      setFiles((prev) =>
        prev.map((f) =>
          pending.some((p) => p.id === f.id) ? { ...f, error: msg } : f
        )
      );
    }
  };

  /* ----- recent merge (only recent uploads) ----- */
  const toggleRecent = (id) => {
    setRecentMergeIds((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  const doMergeRecent = async () => {
    const ids = Array.from(recentMergeIds);
    if (ids.length < 2) return alert("Pick at least 2 recent files to merge.");

    // Guard: do not merge PDFs with others
    const exts = new Set(recentUploads.filter((r) => ids.includes(r.id)).map((r) => (r.ext || "").toLowerCase()));
    if (exts.has("pdf")) return alert("Cannot merge PDF files with other types.");

    try {
      await axiosInstance.post(API_PATHS.UPLOADS.MERGE, {
        file_ids: ids,
        output_name: recentMergeName?.trim() || "merged_output",
      });
      await fetchServerFiles();
      setShowRecentMergePrompt(false);
      setRecentMergeIds(new Set());
      setRecentMergeName("");
    } catch (e) {
      alert(e?.response?.data?.message || e.message || "Failed to merge files");
    }
  };

  /* ----- BULK DELETE (server files) ----- */
  const toggleDeleteMode = () => {
    setDeleteMode((v) => {
      if (v) setDeleteSel(new Set());
      setDeleteMsg("");
      return !v;
    });
  };

  const toggleSelect = (id) => {
    setDeleteSel((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  const selectAllOnPage = () => {
    setDeleteSel((prev) => {
      const next = new Set(prev);
      pageItems.forEach((f) => next.add(f.id));
      return next;
    });
  };

  const clearSelection = () => setDeleteSel(new Set());

  const deleteSelected = async () => {
    if (!deleteSel.size) return;
    const ok = window.confirm(`Delete ${deleteSel.size} file(s)? This cannot be undone.`);
    if (!ok) return;

    setDeleteBusy(true);
    setDeleteMsg("");
    const ids = Array.from(deleteSel);

    const failed = [];
    for (const id of ids) {
      try {
        await axiosInstance.delete(API_PATHS.UPLOADS.DELETE(id));
      } catch (e) {
        failed.push(id);
      }
    }

    // refresh state
    await fetchServerFiles();
    // also remove from recent list if present
    setRecentUploads((prev) => prev.filter((r) => !ids.includes(r.id)));

    setDeleteBusy(false);
    setDeleteSel(new Set());

    if (failed.length) {
      setDeleteMsg(`Some files could not be deleted (${failed.length}/${ids.length}).`);
    } else {
      setDeleteMsg(`Deleted ${ids.length} file(s) successfully.`);
    }

    // If we deleted all items on the last page, move back a page
    const maxPage = Math.max(1, Math.ceil((serverFiles.length - ids.length) / pageSize));
    if (page > maxPage) setPage(maxPage);
  };

  return (
    <DashboardLayout activeMenu="Files">
      <div className="m-3 space-y-6">

        {/* Back to dashboard */}
        <button
          onClick={() => navigate("/admin/dashboard")}
          className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900"
        >
          <LuArrowLeft className="text-base" />
          <span>Back to Dashboard</span>
        </button>

        {/* Header */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-xl md:text-2xl font-semibold">My Files & Assets</h2>

          <div className="flex items-center gap-2 sm:gap-3">
            <button
              onClick={uploadAll}
              disabled={!canUpload}
              className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
            >
              <LuFileCheck2 className="text-base" />
              Upload {files.length ? `(${files.length})` : ""}
            </button>
            <button
              onClick={clearAll}
              disabled={!files.length}
              className="inline-flex items-center gap-2 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
            >
              <LuTrash2 className="text-base" />
              Clear
            </button>
          </div>
        </div>

        {/* Global error */}
        {globalError && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {globalError}
          </div>
        )}

        {/* Oversize upgrade prompt */}
        {oversizeFound && (
          <div className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-3 text-sm text-amber-900">
            <div className="font-medium mb-1">These files exceed the 50 MB limit:</div>
            <ul className="list-disc ml-5">
              {oversizeNames.map((n) => <li key={n}>{n}</li>)}
            </ul>
            <div className="mt-2">
              Upgrade to <span className="font-semibold">Premium</span> to upload large files.
              <button
                onClick={() => navigate("/premium")}
                className="ml-3 inline-flex items-center rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-500"
              >
                See Premium plans
              </button>
            </div>
          </div>
        )}

        {/* Drag & Drop zone */}
        <div
          onClick={() => fileInputRef.current?.click()}
          onDrop={onDrop}
          onDragOver={onDragOver}
          onDragEnter={onDragOver}
          onDragLeave={onDragLeave}
          className={`cursor-pointer rounded-2xl border-2 border-dashed p-8 text-center transition-colors ${
            dragActive ? "border-indigo-500 bg-indigo-50/60" : "border-gray-300 hover:border-indigo-300"
          }`}
        >
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept={ACCEPT}
            onChange={onFileChange}
            className="hidden"
          />
          <div className="mx-auto max-w-xl">
            <LuCloudUpload className="mx-auto text-3xl text-indigo-500" />
            <p className="mt-3 text-sm text-gray-700">
              <span className="text-indigo-600 underline">Click here</span> to upload your files or drag & drop
            </p>
            <p className="text-xs text-gray-500 mt-1">
              Supported: CSV, XLS, XLSX, PDF (<strong>50 MB</strong> each). Allowed combos: CSV-only, Excel-only, CSV+Excel, or PDF-only.
            </p>
          </div>
        </div>

        {/* Local previews (pre-upload) */}
        <div className="space-y-3">
          {files.length ? (
            <>
              <h3 className="text-sm font-medium text-gray-700">Selected files ({files.length})</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {files.map((it) => (
                  <div key={it.id} className="flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm">
                    <FileBadge file={it.file} previewUrl={it.previewUrl} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-gray-900">{it.file.name}</p>
                      <p className="mt-0.5 text-xs text-gray-500">
                        {formatBytes(it.file.size)} • {it.file.type || "file"}
                      </p>
                      {it.error ? (
                        <p className="mt-1 text-xs text-red-600">{it.error}</p>
                      ) : it.uploaded ? (
                        <p className="mt-1 text-xs text-green-600">Uploaded</p>
                      ) : it.progress > 0 ? (
                        <div className="mt-1 h-2 rounded-full bg-gray-200">
                          <div className="h-2 rounded-full bg-indigo-500 transition-all" style={{ width: `${it.progress}%` }} />
                        </div>
                      ) : null}
                    </div>
                    <button
                      className="p-2 rounded-lg hover:bg-gray-100 text-gray-600"
                      onClick={(e) => { e.stopPropagation(); removeOne(it.id); }}
                      title="Remove"
                    >
                      <LuX />
                    </button>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <p className="text-sm text-gray-500">No files selected yet.</p>
          )}
        </div>

        {/* Merge prompt — ONLY for the most recently uploaded files */}
        {showRecentMergePrompt && recentUploads.length > 0 && (
          <div className="space-y-3 rounded-xl border border-indigo-200 bg-indigo-50 p-4">
            <div className="text-sm text-indigo-900">
              Upload complete. Merge the recently uploaded files, or continue to dashboard.
            </div>

            <div className="overflow-auto rounded-lg border border-indigo-200 bg-white">
              <table className="min-w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-3 py-2 text-left">Select</th>
                    <th className="px-3 py-2 text-left">File</th>
                    <th className="px-3 py-2 text-left">Type</th>
                    <th className="px-3 py-2 text-left">Size</th>
                    <th className="px-3 py-2 text-left">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {recentUploads.map((f) => (
                    <tr
                      key={f.id}
                      className="odd:bg-white even:bg-gray-50 hover:bg-indigo-50 cursor-pointer"
                      onClick={() => navigate(`/admin/files/${f.id}`)}
                    >
                      <td className="px-3 py-2 align-top" onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={recentMergeIds.has(f.id)}
                          onChange={() => toggleRecent(f.id)}
                        />
                      </td>
                      <td className="px-3 py-2 align-top">
                        <div className="font-medium text-gray-900 break-all">{f.original_name}</div>
                        <div className="text-xs text-gray-500">id: {f.id}</div>
                      </td>
                      <td className="px-3 py-2 align-top">{f.content_type || f.ext}</td>
                      <td className="px-3 py-2 align-top">{formatBytes(f.size_bytes || 0)}</td>
                      <td className="px-3 py-2 align-top capitalize">{f.status || "uploaded"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  value={recentMergeName}
                  onChange={(e) => setRecentMergeName(e.target.value)}
                  placeholder="Merged output name (e.g., sales_q1_q2)"
                  className="w-64 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
                <button
                  onClick={doMergeRecent}
                  disabled={recentMergeIds.size < 2}
                  className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
                >
                  Merge Selected
                </button>
              </div>

              <button
                onClick={() => { setShowRecentMergePrompt(false); navigate("/admin/dashboard"); }}
                className="text-sm text-gray-700 underline"
              >
                Continue to Dashboard
              </button>
            </div>
          </div>
        )}

        {/* Old uploads (bulk delete mode available) */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-medium text-gray-700">Previously uploaded files</h3>

            <div className="flex items-center gap-2">
              {/* NEW: toggle bulk delete */}
              <button
                onClick={toggleDeleteMode}
                className={`inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium ${
                  deleteMode
                    ? "border-red-300 text-red-700 bg-red-50 hover:bg-red-100"
                    : "border-gray-200 text-gray-700 hover:bg-gray-50"
                }`}
              >
                <LuTrash2 className="text-base" />
                {deleteMode ? "Exit delete mode" : "Bulk delete"}
              </button>

              {/* NEW: when in delete mode, show actions */}
              {deleteMode && (
                <>
                  <button
                    onClick={selectAllOnPage}
                    className="rounded-lg border border-gray-200 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
                  >
                    Select all (page)
                  </button>
                  <button
                    onClick={clearSelection}
                    className="rounded-lg border border-gray-200 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
                  >
                    Clear selection
                  </button>
                  <button
                    onClick={deleteSelected}
                    disabled={!deleteSel.size || deleteBusy}
                    className="rounded-lg bg-red-600 px-3 py-2 text-sm font-medium text-white hover:bg-red-500 disabled:opacity-60"
                  >
                    {deleteBusy ? "Deleting…" : `Delete selected (${deleteSel.size})`}
                  </button>
                </>
              )}
            </div>
          </div>

          {/* NEW: delete message */}
          {deleteMsg && (
            <div className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
              {deleteMsg}
            </div>
          )}

          <div className="overflow-auto rounded-xl border border-gray-200">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {deleteMode && <th className="px-3 py-2 text-left w-10">Select</th>}
                  <th className="px-3 py-2 text-left">File</th>
                  <th className="px-3 py-2 text-left">Type</th>
                  <th className="px-3 py-2 text-left">Size</th>
                  <th className="px-3 py-2 text-left">Status</th>
                </tr>
              </thead>
              <tbody>
                {pageItems.map((f) => (
                  <tr
                    key={f.id}
                    className="odd:bg-white even:bg-gray-50 hover:bg-gray-100 cursor-pointer"
                    onClick={() => !deleteMode && navigate(`/admin/files/${f.id}`)}
                  >
                    {deleteMode && (
                      <td className="px-3 py-2 align-top" onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={deleteSel.has(f.id)}
                          onChange={() => toggleSelect(f.id)}
                        />
                      </td>
                    )}
                    <td className="px-3 py-2 align-top">
                      <div className="font-medium text-gray-900 break-all">{f.original_name}</div>
                      <div className="text-xs text-gray-500">id: {f.id}</div>
                    </td>
                    <td className="px-3 py-2 align-top">{f.content_type || f.ext}</td>
                    <td className="px-3 py-2 align-top">{formatBytes(f.size_bytes || 0)}</td>
                    <td className="px-3 py-2 align-top capitalize">{f.status || "uploaded"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* pagination */}
          {totalPages > 1 && (
            <div className="flex items-center gap-2">
              <button
                className="px-2 py-1 text-sm rounded border border-gray-300 disabled:opacity-50"
                disabled={page === 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                Prev
              </button>
              <span className="text-sm text-gray-600">Page {page} of {totalPages}</span>
              <button
                className="px-2 py-1 text-sm rounded border border-gray-300 disabled:opacity-50"
                disabled={page === totalPages}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              >
                Next
              </button>
            </div>
          )}
        </div>
      </div>
    </DashboardLayout>
  );
};

export default FilesAndAssets;