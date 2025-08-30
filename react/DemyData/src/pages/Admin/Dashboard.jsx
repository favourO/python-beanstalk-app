import React, { useEffect, useRef, useState, useContext } from "react";
import { useUserAuth } from "../../hooks/useUserAuth";
import { UserContext } from "../../context/userContext";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import { useNavigate } from "react-router-dom";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import moment from "moment";
import { addThousandsSeparator } from "../../utils/helper";
import InfoCard from "../../components/Cards/InfoCard";
import { LuArrowRight, LuPlus, LuDatabase, LuChevronDown, LuUpload, LuPlay } from "react-icons/lu";
import TaskListTable from "../../components/TaskListTable";
import CustomPieChart from "../../components/Charts/CustomPieChart";
import CustomBarChart from "../../components/Charts/CustomBarChart";
import ConnectDataSourceModal from "../../components/modals/ConnectDataSourceModal";

const COLORS = ["#8D51FF", "#00B8DB", "#7BCE00"];

const Dashboard = () => {
  useUserAuth();

  const { user } = useContext(UserContext);
  const navigate = useNavigate();

  // actions ui state
  const [dsOpen, setDsOpen] = useState(false);
  const dsMenuRef = useRef(null);
  const fileInputRef = useRef(null);

  // connect modal state
  const [showConnectModal, setShowConnectModal] = useState(false);
  const [connectType, setConnectType] = useState(null);

  // query editor state
  const [queryText, setQueryText] = useState("SELECT * FROM tasks LIMIT 10;");
  const [running, setRunning] = useState(false);
  const [queryError, setQueryError] = useState(null);
  const [queryResult, setQueryResult] = useState(null);

  

  const goToUploadPage = () => navigate("/admin/files");

  // Close dropdown on outside click
  useEffect(() => {
    function onDocClick(e) {
      if (dsMenuRef.current && !dsMenuRef.current.contains(e.target)) {
        setDsOpen(false);
      }
    }
    if (dsOpen) document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, [dsOpen]);

  // Actions handlers
  const handleCreateProject = () => navigate("/admin/projects/new");

  // UPDATED: open the connection modal instead of navigating
  const handleConnect = (type) => {
    setDsOpen(false);
    // normalize "postgresql" -> "postgres" to match backend
    setConnectType(type === "postgresql" ? "postgres" : type);
    setShowConnectModal(true);
  };

  const openFilePicker = () => fileInputRef.current?.click();
  const onFileChange = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      // TODO: plug into your upload flow
      console.log("Selected file:", file);
    }
  };

  // Query editor handlers
  const runQuery = async () => {
    const q = queryText.trim();
    if (!q) return;
    setRunning(true);
    setQueryError(null);
    setQueryResult(null);
    try {
      // NOTE: wire this to your backend path
      const res = await axiosInstance.post(RUN_QUERY_PATH, { query: q });
      setQueryResult(res.data);
    } catch (err) {
      setQueryError(err?.response?.data?.message || err.message || "Failed to run query");
    } finally {
      setRunning(false);
    }
  };

  const onKeyDown = (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      e.preventDefault();
      runQuery();
    }
  };

  // Render result as table if possible
  const ResultView = ({ data }) => {
    if (!data) return null;
    const rows = Array.isArray(data) ? data : Array.isArray(data?.rows) ? data.rows : null;

    if (rows && rows.length && typeof rows[0] === "object") {
      const cols = Array.from(
        rows.reduce((set, r) => {
          Object.keys(r || {}).forEach((k) => set.add(k));
          return set;
        }, new Set())
      );
      return (
        <div className="mt-3 overflow-auto rounded-lg border border-gray-200 dark:border-gray-700">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800">
              <tr>
                {cols.map((c) => (
                  <th key={c} className="px-3 py-2 text-left font-medium text-gray-700 dark:text-gray-200">
                    {c}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={i} className="odd:bg-white even:bg-gray-50 dark:odd:bg-gray-900 dark:even:bg-gray-800">
                  {cols.map((c) => (
                    <td key={c} className="px-3 py-2 text-gray-800 dark:text-gray-100 align-top">
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
        </div>
      );
    }

    // Fallback: show raw JSON
    return (
      <pre className="mt-3 overflow-auto rounded-lg border border-gray-200 bg-gray-50 p-3 text-xs text-gray-800 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100">
        {JSON.stringify(data, null, 2)}
      </pre>
    );
  };

  return (
    <DashboardLayout activeMenu="Databoard">
      {/* Header row with actions on the far right */}
      <div className="m-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <h2 className="text-xl md:text-xl font-medium">Databoard</h2>

        <div className="flex items-center gap-2 sm:gap-3">
          {/* Create project */}
          <button
            onClick={handleCreateProject}
            className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 dark:bg-indigo-500 dark:hover:bg-indigo-400"
          >
            <LuPlus className="text-base" />
            <span>Create project</span>
          </button>

          {/* Connect to data source (dropdown) */}
          <div className="relative" ref={dsMenuRef}>
            <button
              onClick={() => setDsOpen((v) => !v)}
              aria-haspopup="menu"
              aria-expanded={dsOpen}
              className="inline-flex items-center gap-2 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 dark:border-gray-700 dark:text-black-200 dark:hover:bg-white-800"
            >
              <LuDatabase className="text-base" />
              <span>Connect to data source</span>
              <LuChevronDown className="text-sm" />
            </button>

            {dsOpen && (
              <div
                role="menu"
                className="absolute right-0 z-40 mt-2 w-64 overflow-hidden rounded-xl border border-gray-200 bg-white shadow-lg dark:border-gray-700 dark:bg-white"
              >
                <button
                  onClick={() => handleConnect("postgresql")}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-gray-50 dark:hover:bg-white-800"
                  role="menuitem"
                >
                  PostgreSQL
                </button>
                <button
                  onClick={() => handleConnect("snowflake")}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-gray-50 dark:hover:bg-white-800"
                  role="menuitem"
                >
                  Snowflake
                </button>
                <button
                  onClick={() => handleConnect("bigquery")}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-gray-50 dark:hover:bg-white-800"
                  role="menuitem"
                >
                  BigQuery
                </button>
                <button
                  onClick={() => handleConnect("mongodb")}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-gray-50 dark:hover:bg-white-800"
                  role="menuitem"
                >
                  MongoDB
                </button>
              </div>
            )}
          </div>

          {/* Upload file */}
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            onChange={onFileChange}
          />
          <button
            onClick={goToUploadPage}
            className="inline-flex items-center gap-2 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 dark:border-gray-700 dark:text-black-200 dark:hover:bg-white-800"
          >
            <LuUpload className="text-base" />
            <span>Upload files</span>
          </button>
        </div>
      </div>

      {/* === Query Editor (directly below header) === */}
      <div className="m-3">
        <div className="card">
          <div className="flex items-center justify-between">
            <h5 className="font-medium">Query data</h5>
            <p className="text-xs text-gray-500 dark:text-gray-400">Press ⌘/Ctrl + Enter to run</p>
          </div>

          <div className="mt-3">
            <textarea
              value={queryText}
              onChange={(e) => setQueryText(e.target.value)}
              onKeyDown={onKeyDown}
              placeholder="Type your SQL or natural language query…"
              className="w-full min-h-[120px] resize-y rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 font-mono text-sm text-gray-900 placeholder-gray-400 focus:border-transparent focus:outline-none focus:ring-2 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-500"
            />
            <div className="mt-2 flex items-center gap-2">
              <button
                onClick={runQuery}
                disabled={running}
                className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-70 dark:bg-indigo-500 dark:hover:bg-indigo-400"
              >
                <LuPlay />
                {running ? "Running…" : "Run"}
              </button>
              {queryError && <span className="text-sm text-red-600 dark:text-red-400">{queryError}</span>}
            </div>

            {queryResult && <ResultView data={queryResult} />}
          </div>
        </div>
      </div>
      {/* === /Query Editor === */}

      {/* === Connect Modal === */}
      {showConnectModal && (
        <ConnectDataSourceModal
          open={showConnectModal}
          initialType={connectType}
          onClose={() => setShowConnectModal(false)}
          onSuccess={() => {
            setShowConnectModal(false);
            navigate("/admin/connected-sources");
          }}
        />
      )}
      {/* === /Connect Modal === */}
    </DashboardLayout>
  );
};

export default Dashboard;