import React, { useMemo, useState } from "react";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";

const TYPES = [
  { id: "postgres", label: "PostgreSQL" },
  { id: "snowflake", label: "Snowflake" },
  { id: "bigquery", label: "BigQuery" },
  { id: "mongodb", label: "MongoDB" },
];

export default function ConnectDataSourceModal({ open, initialType, onClose, onSuccess }) {
  const [type, setType] = useState(initialType || "postgres");
  const [submitting, setSubmitting] = useState(false);
  const [err, setErr] = useState(null);

  // shared fields
  const [name, setName] = useState("");

  // postgres
  const [pg, setPg] = useState({ host: "", port: 5432, dbname: "", user: "", password: "", sslmode: "require" });

  // snowflake (common fields)
  const [sf, setSf] = useState({ account: "", user: "", password: "", role: "", warehouse: "", database: "", schema: "" });

  // bigquery
  const [bq, setBq] = useState({ project_id: "", service_account_json: "" });

  // mongodb
  const [mg, setMg] = useState({ uri: "", database: "" });

  const typeLabel = useMemo(() => TYPES.find(t => t.id === type)?.label || "Source", [type]);

  if (!open) return null;

  const submit = async (e) => {
    e?.preventDefault();
    setErr(null);
    setSubmitting(true);
    try {
      const payload = { name: name?.trim(), source_type: type };
      if (!payload.name) throw new Error("Please give this connection a name.");

      if (type === "postgres") {
        payload.postgres = { ...pg, port: Number(pg.port) || 5432 };
      } else if (type === "snowflake") {
        payload.snowflake = { ...sf };
      } else if (type === "bigquery") {
        let sa;
        try { sa = JSON.parse(bq.service_account_json || "{}"); } catch (_) { throw new Error("Service Account JSON is not valid JSON."); }
        payload.bigquery = { project_id: bq.project_id.trim(), service_account_json: sa };
      } else if (type === "mongodb") {
        payload.mongodb = { ...mg };
      }

      await axiosInstance.post(API_PATHS.CONNECTED_DATA.CREATE, payload);
      onSuccess?.();   // caller will navigate
    } catch (e) {
      setErr(e?.response?.data?.message || e.message || "Failed to create connection.");
    } finally {
      setSubmitting(false);
    }
  };

  const fieldBase =
    "rounded-md border border-gray-300 px-3 py-2 text-sm bg-white text-gray-900 " +
    "placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent " +
    "dark:border-gray-300 dark:bg-white dark:text-gray-900";

  const labelBase = "text-sm font-medium text-gray-900 dark:text-gray-900";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-white/40">
      {/* Modal panel: force white bg + dark text in both themes */}
      <div className="w-full max-w-xl rounded-xl border border-gray-200 bg-white p-5 shadow-xl text-gray-900 dark:border-gray-300 dark:bg-white dark:text-gray-900">
        <div className="mb-3 flex items-center justify-between">
          <h3 className="text-lg font-semibold">Connect a data source</h3>
          <button
            onClick={onClose}
            className="rounded-md px-2 py-1 text-sm text-gray-600 hover:bg-gray-100"
          >
            Close
          </button>
        </div>

        <form onSubmit={submit} className="space-y-4">
          {/* type */}
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <label className={labelBase}>Source type</label>
            <select
              value={type}
              onChange={(e) => setType(e.target.value)}
              className={fieldBase}
            >
              {TYPES.map(t => <option key={t.id} value={t.id}>{t.label}</option>)}
            </select>
          </div>

          {/* name */}
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <label className={labelBase}>Connection name</label>
            <input
              value={name}
              onChange={(e)=>setName(e.target.value)}
              placeholder={`e.g. prod-${type}`}
              className={fieldBase}
            />
          </div>

          {/* type-specific fields */}
          {type === "postgres" && (
            <div className="space-y-3">
              {[
                ["Host","host","text"], ["Port","port","number"], ["Database","dbname","text"],
                ["User","user","text"], ["Password","password","password"]
              ].map(([label,key,inputType])=>(
                <div key={key} className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <label className={labelBase}>{label}</label>
                  <input
                    type={inputType}
                    value={pg[key]}
                    onChange={(e)=>setPg(v=>({...v,[key]: e.target.value}))}
                    className={fieldBase}
                  />
                </div>
              ))}
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <label className={labelBase}>SSL Mode</label>
                <select
                  value={pg.sslmode}
                  onChange={(e)=>setPg(v=>({...v, sslmode: e.target.value}))}
                  className={fieldBase}
                >
                  <option value="require">require</option>
                  <option value="disable">disable</option>
                </select>
              </div>
            </div>
          )}

          {type === "snowflake" && (
            <div className="space-y-3">
              {[
                ["Account","account"], ["User","user"], ["Password","password"], ["Role","role"],
                ["Warehouse","warehouse"], ["Database","database"], ["Schema","schema"]
              ].map(([label,key])=>(
                <div key={key} className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <label className={labelBase}>{label}</label>
                  <input
                    type={key==="password" ? "password" : "text"}
                    value={sf[key]}
                    onChange={(e)=>setSf(v=>({...v,[key]: e.target.value}))}
                    className={fieldBase}
                  />
                </div>
              ))}
            </div>
          )}

          {type === "bigquery" && (
            <div className="space-y-3">
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <label className={labelBase}>Project ID</label>
                <input
                  value={bq.project_id}
                  onChange={(e)=>setBq(v=>({...v, project_id: e.target.value}))}
                  className={fieldBase}
                />
              </div>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <label className={labelBase}>Service Account JSON</label>
                <textarea
                  rows={6}
                  value={bq.service_account_json}
                  onChange={(e)=>setBq(v=>({...v, service_account_json: e.target.value}))}
                  placeholder='Paste full JSON here'
                  className={`${fieldBase} font-mono`}
                />
              </div>
            </div>
          )}

          {type === "mongodb" && (
            <div className="space-y-3">
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <label className={labelBase}>Connection URI</label>
                <input
                  value={mg.uri}
                  onChange={(e)=>setMg(v=>({...v, uri: e.target.value}))}
                  placeholder="mongodb+srv://user:pass@cluster0.mongodb.net/"
                  className={fieldBase}
                />
              </div>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <label className={labelBase}>Database</label>
                <input
                  value={mg.database}
                  onChange={(e)=>setMg(v=>({...v, database: e.target.value}))}
                  className={fieldBase}
                />
              </div>
            </div>
          )}

          {err && <p className="text-sm text-red-600">{err}</p>}

          <div className="mt-2 flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-900 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-70"
            >
              {submitting ? "Connecting…" : `Connect ${typeLabel}`}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}