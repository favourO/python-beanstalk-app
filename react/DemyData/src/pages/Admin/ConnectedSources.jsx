import React, { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";

const Empty = ({ children }) => (
  <div className="flex h-40 items-center justify-center rounded-lg border border-dashed border-gray-300 text-sm text-gray-500 dark:border-gray-700 dark:text-gray-400">
    {children}
  </div>
);

// -------- helpers to make response robust --------
const toArray = (raw) => {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw;
  const candidates = ["items", "data", "results", "sources", "connections", "list"];
  for (const k of candidates) {
    if (Array.isArray(raw?.[k])) return raw[k];
  }
  // sometimes APIs return { items: { data: [...] } }
  for (const k of candidates) {
    const maybe = raw?.[k];
    if (maybe && typeof maybe === "object" && Array.isArray(maybe.data)) return maybe.data;
  }
  return [];
};

const canon = (s) => ({
  id: s.id ?? s.source_id ?? s._id ?? String(s.name || "unknown"),
  name: s.name ?? s.display_name ?? `${s.source_type || s.type || "source"}`,
  source_type: s.source_type ?? s.type ?? "unknown",
  ...s,
});
// -------------------------------------------------

export default function ConnectedSources() {
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState(null);
  const [sources, setSources] = useState([]);
  const [selected, setSelected] = useState(null);

  // right pane state
  const [discovering, setDiscovering] = useState(false);
  const [discoveryErr, setDiscoveryErr] = useState(null);
  const [items, setItems] = useState([]); // tables/collections preview

  const fetchSources = async () => {
    setErr(null);
    setLoading(true);
    try {
      const res = await axiosInstance.get(API_PATHS.CONNECTED_DATA.LIST);
      const list = toArray(res?.data).map(canon);
      setSources(list);
      // auto-select first if nothing selected
      if (!selected && list.length) setSelected(list[0]);
    } catch (e) {
      setErr(e?.response?.data?.message || e.message || "Failed to load sources");
      setSources([]); // ensure array so render is safe
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchSources(); /* eslint-disable-next-line */ }, []);

  useEffect(() => {
    if (!selected) return;
    const run = async () => {
      setDiscovering(true);
      setDiscoveryErr(null);
      setItems([]);

      try {
        const { id, source_type } = selected;

        if (source_type === "postgres") {
          const payload = {
            sql: `SELECT table_schema, table_name
                  FROM information_schema.tables
                  WHERE table_type = 'BASE TABLE'
                  ORDER BY 1, 2
                  LIMIT 200`,
            offset: 0,
            limit: 200
          };
          const r = await axiosInstance.post(API_PATHS.CONNECTED_DATA.QUERY(id), payload);
          const rows = Array.isArray(r.data?.rows) ? r.data.rows : toArray(r.data);
          setItems(rows?.map(x => ({ name: `${x.table_schema}.${x.table_name}`, kind: "table" })) || []);
        } else if (source_type === "snowflake") {
          const payload = {
            sql: `SELECT table_schema, table_name
                  FROM information_schema.tables
                  ORDER BY 1, 2
                  LIMIT 200`,
            offset: 0,
            limit: 200
          };
          const r = await axiosInstance.post(API_PATHS.CONNECTED_DATA.QUERY(id), payload);
          const rows = Array.isArray(r.data?.rows) ? r.data.rows : toArray(r.data);
          setItems(rows?.map(x => ({ name: `${x.TABLE_SCHEMA || x.table_schema}.${x.TABLE_NAME || x.table_name}`, kind: "table" })) || []);
        } else if (source_type === "bigquery") {
          const payload = {
            sql: `
              SELECT CONCAT(table_schema, '.', table_name) AS fq
              FROM \`region-us\`.INFORMATION_SCHEMA.TABLES
              LIMIT 200
            `,
            offset: 0, limit: 200
          };
          const r = await axiosInstance.post(API_PATHS.CONNECTED_DATA.QUERY(id), payload);
          const rows = Array.isArray(r.data?.rows) ? r.data.rows : toArray(r.data);
          const names = rows?.map(x => x.fq || x.table_name || x.TABLE_NAME).filter(Boolean) || [];
          setItems(names.map(n => ({ name: n, kind: "table" })));
        } else if (source_type === "mongodb") {
          setItems([]); // handled via manual collection preview UI
        } else {
          setItems([]);
        }
      } catch (e) {
        setDiscoveryErr(e?.response?.data?.message || e.message || "Failed to discover connected data");
      } finally {
        setDiscovering(false);
      }
    };

    run();
  }, [selected]);

  const [mongoCollection, setMongoCollection] = useState("");
  const previewMongo = async () => {
    if (!selected || !mongoCollection.trim()) return;
    setDiscoveryErr(null);
    setDiscovering(true);
    try {
      const r = await axiosInstance.post(API_PATHS.CONNECTED_DATA.QUERY(selected.id), {
        collection: mongoCollection.trim(),
        filter: {},
        projection: {},
        sort: [],
        offset: 0,
        limit: 100
      });
      const rows = Array.isArray(r.data?.rows) ? r.data.rows : toArray(r.data);
      setItems([{ name: mongoCollection.trim(), kind: "collection", sampleCount: rows?.length || 0 }]);
    } catch (e) {
      setDiscoveryErr(e?.response?.data?.message || e.message);
    } finally {
      setDiscovering(false);
    }
  };

  return (
    <DashboardLayout activeMenu="Databoard">
      <div className="m-3">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-xl font-medium">Connected sources</h2>
        </div>

        {loading ? (
          <Empty>Loading…</Empty>
        ) : err ? (
          <Empty>{err}</Empty>
        ) : (sources?.length ?? 0) === 0 ? (
          <Empty>No sources yet. Use “Connect to data source” to add one.</Empty>
        ) : (
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            {/* Left: list of sources */}
            <div className="rounded-xl border border-gray-200 p-3 dark:border-gray-700">
              <h4 className="mb-2 text-sm font-medium text-gray-600 dark:text-gray-300">Sources</h4>
              <ul className="divide-y divide-gray-200 dark:divide-gray-800">
                {sources.map((s) => (
                  <li key={s.id}>
                    <button
                      onClick={() => setSelected(s)}
                      className={`flex w-full items-center justify-between px-2 py-3 text-left hover:bg-gray-50 dark:hover:bg-gray-800 ${selected?.id === s.id ? "bg-gray-50 dark:bg-gray-800" : ""}`}
                    >
                      <div>
                        <div className="text-sm font-medium">{s.name}</div>
                        <div className="text-xs text-gray-500">{s.source_type}</div>
                      </div>
                      <span className="text-xs text-gray-400">ID: {s.id}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </div>

            {/* Right: split detail showing connected data */}
            <div className="rounded-xl border border-gray-200 p-3 dark:border-gray-700">
              {!selected ? (
                <Empty>Select a source to explore its data.</Empty>
              ) : (
                <>
                  <div className="mb-2 flex items-center justify-between">
                    <div>
                      <div className="text-sm font-medium">{selected.name}</div>
                      <div className="text-xs text-gray-500">{selected.source_type}</div>
                    </div>
                    {discovering && <span className="text-xs text-gray-500">Discovering…</span>}
                  </div>

                  {selected.source_type === "mongodb" && (
                    <div className="mb-3 flex items-center gap-2">
                      <input
                        value={mongoCollection}
                        onChange={(e)=>setMongoCollection(e.target.value)}
                        placeholder="Enter collection to preview (e.g. events)"
                        className="flex-1 rounded-md border border-gray-300 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800"
                      />
                      <button
                        onClick={previewMongo}
                        className="rounded-md bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 dark:bg-indigo-500 dark:hover:bg-indigo-400"
                      >
                        Preview
                      </button>
                    </div>
                  )}

                  {discoveryErr && <p className="mb-2 text-sm text-red-600">{discoveryErr}</p>}

                  {items.length === 0 ? (
                    <Empty>No connected data found yet.</Empty>
                  ) : (
                    <div className="max-h-[480px] overflow-auto rounded-lg border border-gray-200 dark:border-gray-700">
                      <table className="min-w-full text-sm">
                        <thead className="bg-gray-50 dark:bg-gray-800">
                          <tr>
                            <th className="px-3 py-2 text-left font-medium text-gray-700 dark:text-gray-200">Name</th>
                            <th className="px-3 py-2 text-left font-medium text-gray-700 dark:text-gray-200">Type</th>
                            <th className="px-3 py-2 text-left font-medium text-gray-700 dark:text-gray-200">Notes</th>
                          </tr>
                        </thead>
                        <tbody>
                          {items.map((it, i) => (
                            <tr key={i} className="odd:bg-white even:bg-gray-50 dark:odd:bg-gray-900 dark:even:bg-gray-800">
                              <td className="px-3 py-2">{it.name}</td>
                              <td className="px-3 py-2">{it.kind}</td>
                              <td className="px-3 py-2 text-gray-500">
                                {it.sampleCount !== undefined ? `${it.sampleCount} docs previewed` : "—"}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}