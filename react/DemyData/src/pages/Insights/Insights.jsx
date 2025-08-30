import React, { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import EngineResponse from "../../components/engine/EngineResponse";
import SciAnalysisCard from "../../components/insights/SciAnalysisCard";
import { LuRefreshCw } from "react-icons/lu";

const normalizeEngineError = (res, err) => {
  const status = res?.status ?? err?.response?.status;
  const data = res?.data ?? err?.response?.data ?? {};
  const detail = data?.detail || data?.message || err?.message || "Request failed.";
  return {
    message: typeof detail === "string" ? detail : JSON.stringify(detail, null, 2),
    status: status || 500,
  };
};

const Tabs = ({ active, onChange }) => (
  <div className="inline-flex rounded-lg border border-gray-200 bg-white p-1 text-sm">
    <button
      onClick={() => onChange("queries")}
      className={`px-3 py-1.5 rounded-md ${
        active === "queries" ? "bg-indigo-600 text-white" : "text-gray-700 hover:bg-gray-50"
      }`}
    >
      Engine Queries
    </button>
    <button
      onClick={() => onChange("analyses")}
      className={`px-3 py-1.5 rounded-md ${
        active === "analyses" ? "bg-indigo-600 text-white" : "text-gray-700 hover:bg-gray-50"
      }`}
    >
      Scientific Analyses
    </button>
  </div>
);

const GroupHeader = ({ uploadId, name, count }) => {
  if (!uploadId || uploadId === "unassigned") {
    return (
      <div className="flex items-center justify-between">
        <div className="text-sm font-semibold text-gray-900">Unassigned</div>
        {typeof count === "number" && (
          <span className="text-xs text-gray-500">{count} item{count === 1 ? "" : "s"}</span>
        )}
      </div>
    );
  }
  const short = String(uploadId).slice(0, 6).toUpperCase();
  return (
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-2">
        <span className="inline-flex items-center rounded-md bg-indigo-600/10 px-2 py-0.5 text-xs font-semibold text-indigo-700">
          {short}
        </span>
        <span className="text-sm font-semibold text-gray-900">{name || "(unknown file)"}</span>
      </div>
      {typeof count === "number" && (
        <span className="text-xs text-gray-500">{count} item{count === 1 ? "" : "s"}</span>
      )}
    </div>
  );
};

export default function Insights() {
  const [activeTab, setActiveTab] = useState("queries"); // 'queries' | 'analyses'

  // Upload metadata (id -> object with original_name, etc.)
  const [uploadsMap, setUploadsMap] = useState({});
  const [uploadsErr, setUploadsErr] = useState("");

  // Engine queries
  const [queries, setQueries] = useState([]);
  const [qLoading, setQLoading] = useState(false);
  const [qErr, setQErr] = useState("");

  // Scientific analyses
  const [analyses, setAnalyses] = useState([]);
  const [aLoading, setALoading] = useState(false);
  const [aErr, setAErr] = useState("");

  // Load uploads list for names
  const loadUploads = async () => {
    setUploadsErr("");
    try {
      const res = await axiosInstance.get(API_PATHS.UPLOADS.LIST, { validateStatus: () => true });
      if (res.status >= 400) {
        const { message } = normalizeEngineError(res);
        throw new Error(message);
      }
      const list = Array.isArray(res.data) ? res.data : [];
      const map = {};
      list.forEach((u) => {
        map[u.id] = u;
      });
      setUploadsMap(map);
    } catch (e) {
      setUploadsErr(e?.message || "Failed to load uploads list.");
    }
  };

  // Load all engine queries
  const loadQueries = async () => {
    setQErr("");
    setQLoading(true);
    try {
      const lim = 100;
      let ofs = 0;
      let acc = [];
      // fetch pages
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const url =
          API_PATHS?.ENGINE?.QUERIES_ALL?.(lim, ofs) ||
          `/0.1.0/engine/queries?limit=${lim}&offset=${ofs}`;
        // eslint-disable-next-line no-await-in-loop
        const res = await axiosInstance.get(url, { validateStatus: () => true });
        if (res.status >= 400) {
          const { message } = normalizeEngineError(res);
          throw new Error(message);
        }
        const d = res.data || {};
        const items = Array.isArray(d?.items)
          ? d.items
          : Array.isArray(d)
          ? d
          : [];
        acc = acc.concat(items);
        const total = typeof d?.total === "number" ? d.total : undefined;
        if ((total !== undefined && acc.length >= total) || items.length < lim) break;
        ofs += lim;
      }
      acc.sort((a, b) => {
        const da = new Date(a?.created_at || 0).getTime();
        const db = new Date(b?.created_at || 0).getTime();
        return db - da;
      });
      setQueries(acc);
    } catch (e) {
      setQErr(e?.message || "Failed to load engine queries.");
    } finally {
      setQLoading(false);
    }
  };

  // Load all scientific analyses
  const loadAnalyses = async () => {
    setAErr("");
    setALoading(true);
    try {
      const lim = 100;
      let ofs = 0;
      let acc = [];
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const url = `${API_PATHS.ENGINE.SCI_LIST}?limit=${lim}&offset=${ofs}`;
        // eslint-disable-next-line no-await-in-loop
        const res = await axiosInstance.get(url, { validateStatus: () => true });
        if (res.status >= 400) {
          const { message } = normalizeEngineError(res);
          throw new Error(message);
        }
        const d = res.data || {};
        const items = Array.isArray(d?.items)
          ? d.items
          : Array.isArray(d)
          ? d
          : [];
        acc = acc.concat(items);
        const total = typeof d?.total === "number" ? d.total : undefined;
        if ((total !== undefined && acc.length >= total) || items.length < lim) break;
        ofs += lim;
      }
      acc.sort((a, b) => {
        const da = new Date(a?.created_at || 0).getTime();
        const db = new Date(b?.created_at || 0).getTime();
        return db - da;
      });
      setAnalyses(acc);
    } catch (e) {
      setAErr(e?.message || "Failed to load scientific analyses.");
    } finally {
      setALoading(false);
    }
  };

  useEffect(() => {
    loadUploads();
    loadQueries();
    loadAnalyses();
  }, []);

  // Group helpers
  const groupQueriesByUpload = useMemo(() => {
    const groups = {};
    (queries || []).forEach((item) => {
      const used = item?.used_tables || item?.result_json?.used_tables || {};
      const ids = Object.values(used || {});
      if (!ids || ids.length === 0) {
        groups.unassigned = groups.unassigned ? groups.unassigned.concat(item) : [item];
      } else {
        ids.forEach((id) => {
          const key = String(id);
          groups[key] = groups[key] ? groups[key].concat(item) : [item];
        });
      }
    });
    return groups;
  }, [queries]);

  const groupAnalysesByUpload = useMemo(() => {
    const groups = {};
    (analyses || []).forEach((item) => {
      // prefer top-level upload_ids; fallback to result_json.used_tables -> values
      const top = Array.isArray(item?.upload_ids) ? item.upload_ids : null;
      const fromUsedTables = Object.values(item?.result_json?.used_tables || {});
      const ids = (top && top.length ? top : fromUsedTables) || [];
      if (!ids || ids.length === 0) {
        groups.unassigned = groups.unassigned ? groups.unassigned.concat(item) : [item];
      } else {
        ids.forEach((id) => {
          const key = String(id);
          groups[key] = groups[key] ? groups[key].concat(item) : [item];
        });
      }
    });
    return groups;
  }, [analyses]);

  // Compute ordered upload groups for the active tab
  const orderedUploadIds = useMemo(() => {
    const source = activeTab === "queries" ? groupQueriesByUpload : groupAnalysesByUpload;
    const keys = Object.keys(source || {});
    // Put 'unassigned' last
    const normal = keys.filter((k) => k !== "unassigned");
    normal.sort((a, b) => {
      // sort by name asc
      const nA = uploadsMap[a]?.original_name || "";
      const nB = uploadsMap[b]?.original_name || "";
      return nA.localeCompare(nB);
    });
    if (keys.includes("unassigned")) normal.push("unassigned");
    return normal;
  }, [activeTab, groupQueriesByUpload, groupAnalysesByUpload, uploadsMap]);

  const renderQueryGroup = (uploadId) => {
    const items = groupQueriesByUpload[uploadId] || [];
    const name = uploadsMap[uploadId]?.original_name || uploadsMap[uploadId]?.name || "";
    return (
      <div key={`q-${uploadId}`} className="rounded-xl border border-gray-200 bg-white p-3 shadow-sm">
        <GroupHeader uploadId={uploadId} name={name} count={items.length} />
        <div className="mt-3 space-y-3">
          {items.map((item) => (
            <div key={item.id} className="rounded-lg border border-gray-200 bg-gray-50 p-3">
              <EngineResponse item={item} viewMode="graph" chartType="bar" />
            </div>
          ))}
        </div>
      </div>
    );
  };

  const renderAnalysisGroup = (uploadId) => {
    const items = groupAnalysesByUpload[uploadId] || [];
    const name = uploadsMap[uploadId]?.original_name || uploadsMap[uploadId]?.name || "";
    return (
      <div key={`a-${uploadId}`} className="rounded-xl border border-gray-200 bg-white p-3 shadow-sm">
        <GroupHeader uploadId={uploadId} name={name} count={items.length} />
        <div className="mt-3 space-y-3">
          {items.map((item) => (
            <SciAnalysisCard key={item.id} item={item} />
          ))}
        </div>
      </div>
    );
  };

  const anyLoading = qLoading || aLoading;
  const anyErr = qErr || aErr || uploadsErr;

  return (
    <DashboardLayout activeMenu="Insights">
      <div className="m-3 space-y-6 min-w-0">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-semibold text-gray-900">Insights</h1>
            <Tabs active={activeTab} onChange={setActiveTab} />
          </div>
          <button
            onClick={() => {
              loadUploads();
              loadQueries();
              loadAnalyses();
            }}
            className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            title="Reload"
          >
            <LuRefreshCw className={anyLoading ? "animate-spin" : ""} />
            Refresh
          </button>
        </div>

        {/* Errors */}
        {anyErr && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {uploadsErr || qErr || aErr}
          </div>
        )}

        {/* Content */}
        {activeTab === "queries" ? (
          qLoading ? (
            <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
              Loading engine queries…
            </div>
          ) : orderedUploadIds.length === 0 ? (
            <div className="rounded-md border border-dashed border-gray-300 bg-white px-3 py-6 text-center text-sm text-gray-500">
              No engine queries yet.
            </div>
          ) : (
            <div className="space-y-4">
              {orderedUploadIds.map((id) => renderQueryGroup(id))}
            </div>
          )
        ) : aLoading ? (
          <div className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
            Loading scientific analyses…
          </div>
        ) : orderedUploadIds.length === 0 ? (
          <div className="rounded-md border border-dashed border-gray-300 bg-white px-3 py-6 text-center text-sm text-gray-500">
            No scientific analyses yet.
          </div>
        ) : (
          <div className="space-y-4">
            {orderedUploadIds.map((id) => renderAnalysisGroup(id))}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}