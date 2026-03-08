"use client";

import { fetchProjects, resolveProjectId, type ProjectRecord } from "@/shared/api/projects";
import {
  resolveUploadsScopeId,
  uploadsApi,
  type UploadRecord,
  type UploadUsageSummary,
} from "@/shared/api/uploads";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChangeEvent, DragEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";

const MAX_SIZE = 50 * 1024 * 1024;

const quickNav = [
  { label: "New Task", iconSrc: "/file.svg", href: "/dashboard" },
  { label: "Library", iconSrc: "/library.png", href: "/library" },
  { label: "Search", iconSrc: "/search.png", href: "/search" },
  { label: "Projects", iconSrc: "/projects.png", href: "/projects" },
];

const allTasks = [
  { label: "Top 10 Transacting Merchants...", iconSrc: "/library.png", href: "#" },
  { label: "How to Run a Query to find th...", iconSrc: "/file.svg", href: "#" },
  { label: "Settings", iconSrc: "/window.svg", href: "/settings" },
];

type QueuedFile = {
  id: string;
  file: File;
  progress: number;
  uploaded: boolean;
  error: string | null;
};

const formatBytes = (bytes: number): string => {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const power = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / Math.pow(1024, power)).toFixed(power > 0 ? 1 : 0)} ${units[power]}`;
};

const resolveUploadId = (item: UploadRecord): string =>
  String(item.upload_id ?? item.uploadId ?? item.file_id ?? item.id ?? "");

const getKind = (file: File): "csv" | "excel" | "other" => {
  const type = (file.type || "").toLowerCase();
  const name = file.name.toLowerCase();
  if (type === "text/csv" || name.endsWith(".csv")) return "csv";
  if (
    type === "application/vnd.ms-excel" ||
    type === "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ||
    name.endsWith(".xls") ||
    name.endsWith(".xlsx")
  ) {
    return "excel";
  }
  return "other";
};

const isAllowedCombo = (kinds: Set<string>): boolean => {
  if (kinds.has("other")) return false;
  if (kinds.size === 1 && (kinds.has("csv") || kinds.has("excel"))) return true;
  return kinds.size === 2 && kinds.has("csv") && kinds.has("excel");
};

const uuid = () =>
  typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;

export function LibraryScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const [globalError, setGlobalError] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<number | null>(null);
  const [uploadEta, setUploadEta] = useState<number | null>(null);
  const uploadStartRef = useRef(0);
  const [queue, setQueue] = useState<QueuedFile[]>([]);

  const [projects, setProjects] = useState<ProjectRecord[]>([]);
  const [projectsLoading, setProjectsLoading] = useState(false);
  const [selectedProjectId, setSelectedProjectId] = useState("");

  const [uploads, setUploads] = useState<UploadRecord[]>([]);
  const [uploadsLoading, setUploadsLoading] = useState(false);
  const [usage, setUsage] = useState<UploadUsageSummary>({
    total_size_bytes: 0,
    upload_count: 0,
    plan_remaining_bytes: null,
    plan_max_bytes: null,
  });
  const [search, setSearch] = useState("");

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
    }
  }, [router]);

  const loadProjects = useCallback(async () => {
    const token = getValidAccessToken();
    if (!token) return;
    setProjectsLoading(true);
    try {
      const list = await fetchProjects(token);
      setProjects(list);
      setSelectedProjectId((prev) => prev || resolveProjectId(list[0] ?? {}));
    } catch (error) {
      setGlobalError(error instanceof Error ? error.message : "Failed to load projects.");
    } finally {
      setProjectsLoading(false);
    }
  }, []);

  const loadUploads = useCallback(async () => {
    const token = getValidAccessToken();
    if (!token) return;
    const userId = resolveUploadsScopeId();
    if (!userId) return;
    setUploadsLoading(true);
    try {
      const [list, summary] = await Promise.all([
        uploadsApi.list(token, userId),
        uploadsApi.usageSummary(token),
      ]);
      setUploads(list);
      setUsage(summary);
    } catch (error) {
      setGlobalError(error instanceof Error ? error.message : "Failed to load uploads.");
    } finally {
      setUploadsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadProjects();
    void loadUploads();
  }, [loadProjects, loadUploads]);

  const addFiles = (list: FileList | File[]) => {
    const incoming = Array.from(list || []);
    if (!incoming.length) return;

    setGlobalError("");
    setQueue((prev) => {
      const existing = new Set(prev.map((item) => `${item.file.name}_${item.file.size}_${item.file.lastModified}`));
      let kinds = new Set(prev.map((item) => getKind(item.file)));
      const next: QueuedFile[] = [];
      const oversize: string[] = [];

      for (const file of incoming) {
        if (file.size > MAX_SIZE) {
          oversize.push(`${file.name} (${formatBytes(file.size)})`);
          continue;
        }
        const key = `${file.name}_${file.size}_${file.lastModified}`;
        if (existing.has(key)) continue;

        const kind = getKind(file);
        const nextKinds = new Set(kinds);
        nextKinds.add(kind);
        if (!isAllowedCombo(nextKinds)) {
          setGlobalError("Allowed combos: CSV-only, Excel-only, or CSV+Excel.");
          continue;
        }

        kinds = nextKinds;
        next.push({
          id: uuid(),
          file,
          progress: 0,
          uploaded: false,
          error: null,
        });
      }

      if (oversize.length) {
        setGlobalError(`File exceeds 50 MB limit: ${oversize.join(", ")}`);
      }

      return [...prev, ...next];
    });
  };

  const onFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    if (event.target.files?.length) addFiles(event.target.files);
    event.target.value = "";
  };

  const onDrop = (event: DragEvent<HTMLDivElement>) => {
    event.preventDefault();
    event.stopPropagation();
    setDragActive(false);
    if (event.dataTransfer?.files?.length) addFiles(event.dataTransfer.files);
  };

  const uploadAll = async () => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    const pending = queue.filter((item) => !item.uploaded && !item.error);
    if (!pending.length) return;
    if (!selectedProjectId) {
      setGlobalError("Select a project before uploading files.");
      return;
    }

    const boundary = pending.reduce<Array<{ id: string; start: number; end: number; size: number }>>((acc, item, index) => {
      const start = index === 0 ? 0 : acc[index - 1].end;
      acc.push({
        id: item.id,
        start,
        end: start + item.file.size,
        size: item.file.size,
      });
      return acc;
    }, []);

    setUploading(true);
    setUploadProgress(0);
    uploadStartRef.current = performance.now();
    setGlobalError("");

    try {
      await uploadsApi.uploadFiles(
        token,
        selectedProjectId,
        pending.map((item) => item.file),
        (loaded, total) => {
          setQueue((prev) =>
            prev.map((item) => {
              const b = boundary.find((entry) => entry.id === item.id);
              if (!b) return item;
              const segment = Math.min(Math.max(loaded - b.start, 0), b.size);
              return { ...item, progress: Math.round((segment * 100) / b.size) };
            }),
          );

          const percent = Math.min(100, Math.round((loaded / Math.max(total, 1)) * 100));
          setUploadProgress(percent);
          const elapsed = Math.max((performance.now() - uploadStartRef.current) / 1000, 0.1);
          const speed = loaded / elapsed;
          setUploadEta(speed > 0 ? Math.round((total - loaded) / speed) : null);
        },
      );

      setQueue((prev) =>
        prev.map((item) =>
          pending.some((entry) => entry.id === item.id)
            ? { ...item, uploaded: true, progress: 100, error: null }
            : item,
        ),
      );
      await loadUploads();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Upload failed.";
      setGlobalError(message);
      setQueue((prev) =>
        prev.map((item) =>
          pending.some((entry) => entry.id === item.id) ? { ...item, error: message } : item,
        ),
      );
    } finally {
      setUploading(false);
      setUploadProgress(null);
      setUploadEta(null);
    }
  };

  const removeQueueItem = (id: string) => {
    setQueue((prev) => prev.filter((item) => item.id !== id));
  };

  const clearQueue = () => {
    setQueue([]);
    setGlobalError("");
  };

  const deleteUpload = async (uploadId: string) => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }
    try {
      await uploadsApi.deleteUpload(token, uploadId);
      await loadUploads();
    } catch (error) {
      setGlobalError(error instanceof Error ? error.message : "Failed to delete file.");
    }
  };

  const filteredUploads = useMemo(() => {
    if (!search.trim()) return uploads;
    const term = search.toLowerCase();
    return uploads.filter((item) =>
      String(item.original_name ?? item.name ?? "").toLowerCase().includes(term),
    );
  }, [uploads, search]);

  const usageLabel = useMemo(() => {
    const max = usage.plan_max_bytes ?? null;
    const remaining = usage.plan_remaining_bytes ?? null;
    if (max === null || remaining === null) return "0B / 200MB";
    const used = Math.max(max - remaining, 0);
    return `${formatBytes(used)} / ${formatBytes(max)}`;
  }, [usage.plan_max_bytes, usage.plan_remaining_bytes]);

  const usagePercent = useMemo(() => {
    const max = usage.plan_max_bytes ?? null;
    const remaining = usage.plan_remaining_bytes ?? null;
    if (max === null || remaining === null || max <= 0) return 0;
    const used = Math.max(max - remaining, 0);
    return Math.min(100, Math.round((used / max) * 100));
  }, [usage.plan_max_bytes, usage.plan_remaining_bytes]);

  const sidebar = useMemo(() => {
    return (
      <aside className="flex h-full w-full flex-col border-r border-[var(--border)] bg-[color-mix(in_oklab,var(--surface)_96%,#eef3f8)] px-4 py-4">
        <div className="mb-4 flex items-center gap-2">
          <BrandWordmark />
        </div>

        <nav className="space-y-1.5">
          {quickNav.map((item) => (
            <Link
              key={item.label}
              href={item.href}
              className={`flex items-center gap-2 rounded-md px-2 py-1.5 text-[13px] ${
                pathname === item.href
                  ? "bg-[var(--surface)] text-[var(--electric-blue)]"
                  : "text-[var(--muted)] hover:bg-[var(--surface)]"
              }`}
            >
              <Image src={item.iconSrc} alt="" width={12} height={12} className="h-3 w-3 object-contain" />
              {item.label}
            </Link>
          ))}
        </nav>

        <p className="mt-6 px-2 text-[11px] font-medium uppercase tracking-[0.08em] text-[var(--muted)]">
          All Tasks
        </p>

        <nav className="mt-2 space-y-1.5">
          {allTasks.map((item) => (
            <Link
              key={item.label}
              href={item.href}
              className="flex items-center gap-2 rounded-md px-2 py-1.5 text-[13px] text-[var(--muted)] hover:bg-[var(--surface)]"
            >
              <Image src={item.iconSrc} alt="" width={11} height={11} className="h-[11px] w-[11px] object-contain" />
              {item.label}
            </Link>
          ))}
        </nav>

        <button
          type="button"
          onClick={() => {
            clearAuthSession();
            router.replace("/login");
          }}
          className="mt-auto px-2 pb-2 text-left text-[13px] text-[#ef4444] hover:underline"
        >
          ← Logout
        </button>
      </aside>
    );
  }, [pathname, router]);

  return (
    <main className="h-screen w-screen overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
      <section className="h-full w-full overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
        <div className="grid h-full md:grid-cols-[290px_1fr]">
          <div className="hidden md:block">{sidebar}</div>

          <div className="relative flex h-full flex-col overflow-y-auto px-3 py-3 md:px-5 md:py-4">
            <TopBar onOpenMenu={() => setDrawerOpen(true)} />

            <div className="mt-3 flex items-center justify-between gap-3 md:mt-0">
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)] md:text-[28px]">
                  Library
                </h1>
              </div>

              <div className="min-w-[145px] md:min-w-[250px]">
                <div className="mb-1 flex items-center justify-end gap-2 text-[11px] text-[var(--muted)]">
                  <span>{usageLabel}</span>
                </div>
                <div className="h-1.5 rounded-full bg-[color-mix(in_oklab,var(--charcoal)_10%,white)]">
                  <div className="h-full rounded-full bg-[#27ae60]" style={{ width: `${Math.max(8, usagePercent)}%` }} />
                </div>
              </div>
            </div>

            <div className="mt-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <label className="relative block w-full max-w-[420px]">
                <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]">
                  ⌕
                </span>
                <input
                  type="text"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Search for files"
                  className="h-10 w-full rounded-full border border-[var(--border)] bg-[var(--surface)] pl-9 pr-3 text-sm text-[var(--foreground)] outline-none placeholder:text-[var(--muted)] focus:border-[var(--electric-blue)]"
                />
              </label>

              <div className="flex flex-wrap items-center gap-2">
                <select
                  value={selectedProjectId}
                  onChange={(event) => setSelectedProjectId(event.target.value)}
                  disabled={projectsLoading}
                  className="h-9 rounded-full border border-[var(--border)] bg-[var(--surface)] px-3 text-[13px] text-[var(--muted)]"
                >
                  <option value="">Select project</option>
                  {projects.map((project) => {
                    const id = resolveProjectId(project);
                    return (
                      <option key={id || String(project.name ?? Math.random())} value={id}>
                        {String(project.name ?? id)}
                      </option>
                    );
                  })}
                </select>
                <button
                  type="button"
                  onClick={uploadAll}
                  disabled={uploading || !queue.some((item) => !item.uploaded && !item.error)}
                  className="inline-flex h-9 items-center rounded-full bg-[var(--electric-blue)] px-4 text-[13px] font-medium text-white disabled:opacity-60"
                >
                  {uploading ? "Uploading..." : "Upload"}
                </button>
                <button
                  type="button"
                  onClick={clearQueue}
                  disabled={!queue.length}
                  className="inline-flex h-9 items-center rounded-full border border-[var(--border)] bg-[var(--surface)] px-4 text-[13px] text-[var(--muted)] disabled:opacity-60"
                >
                  Clear
                </button>
              </div>
            </div>

            {globalError ? (
              <div className="mt-3 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700 dark:border-red-500/40 dark:bg-red-500/10 dark:text-red-200">
                {globalError}
              </div>
            ) : null}

            <div
              onDrop={onDrop}
              onDragOver={(event) => {
                event.preventDefault();
                setDragActive(true);
              }}
              onDragEnter={(event) => {
                event.preventDefault();
                setDragActive(true);
              }}
              onDragLeave={(event) => {
                event.preventDefault();
                setDragActive(false);
              }}
              onClick={() => document.getElementById("library-upload-input")?.click()}
              className={`mt-4 cursor-pointer rounded-2xl border-2 border-dashed p-6 text-center transition-colors ${
                dragActive ? "border-[var(--electric-blue)] bg-[color-mix(in_oklab,var(--electric-blue)_8%,white)]" : "border-[var(--border)] bg-[var(--surface)]"
              }`}
            >
              <input
                id="library-upload-input"
                type="file"
                multiple
                accept=".csv,.xls,.xlsx"
                onChange={onFileChange}
                className="hidden"
              />
              <p className="text-sm text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                Click here to upload files or drag and drop
              </p>
              <p className="mt-1 text-xs text-[var(--muted)]">
                CSV, XLS, XLSX only. Max 50 MB each. Allowed combos: CSV-only, Excel-only, or CSV+Excel.
              </p>
              {uploadProgress !== null ? (
                <div className="mx-auto mt-3 max-w-[360px]">
                  <div className="h-2 rounded-full bg-[color-mix(in_oklab,var(--charcoal)_12%,white)]">
                    <div className="h-full rounded-full bg-[var(--electric-blue)]" style={{ width: `${uploadProgress}%` }} />
                  </div>
                  <p className="mt-1 text-xs text-[var(--muted)]">
                    Uploading {uploadProgress}%{uploadEta !== null ? ` • ETA ${uploadEta}s` : ""}
                  </p>
                </div>
              ) : null}
            </div>

            {queue.length ? (
              <section className="mt-4 rounded-xl border border-[var(--border)] bg-[var(--surface)] p-3">
                <h2 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Selected files ({queue.length})
                </h2>
                <div className="mt-2 grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
                  {queue.map((item) => (
                    <article key={item.id} className="rounded-lg border border-[var(--border)] bg-[var(--surface-subtle)] p-2.5">
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="truncate text-xs font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                            {item.file.name}
                          </p>
                          <p className="text-[11px] text-[var(--muted)]">{formatBytes(item.file.size)}</p>
                        </div>
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            removeQueueItem(item.id);
                          }}
                          className="text-[var(--muted)] hover:text-red-600"
                          aria-label="Remove selected file"
                        >
                          ×
                        </button>
                      </div>
                      {item.error ? (
                        <p className="mt-1 text-[11px] text-red-500">{item.error}</p>
                      ) : item.uploaded ? (
                        <p className="mt-1 text-[11px] text-emerald-600">Uploaded</p>
                      ) : item.progress > 0 ? (
                        <div className="mt-2 h-1.5 rounded-full bg-[color-mix(in_oklab,var(--charcoal)_12%,white)]">
                          <div className="h-full rounded-full bg-[var(--electric-blue)]" style={{ width: `${item.progress}%` }} />
                        </div>
                      ) : null}
                    </article>
                  ))}
                </div>
              </section>
            ) : null}

            <section className="mt-4 pb-8">
              <div className="mb-2 flex items-center justify-between">
                <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Uploaded files
                </h2>
                <p className="text-xs text-[var(--muted)]">
                  {usage.upload_count} files • {formatBytes(usage.total_size_bytes)}
                </p>
              </div>

              <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)]">
                <table className="min-w-full text-sm">
                  <thead className="bg-[var(--surface-subtle)]">
                    <tr>
                      <th className="px-3 py-2 text-left text-xs font-semibold text-[var(--muted)]">File</th>
                      <th className="px-3 py-2 text-left text-xs font-semibold text-[var(--muted)]">Type</th>
                      <th className="px-3 py-2 text-left text-xs font-semibold text-[var(--muted)]">Size</th>
                      <th className="px-3 py-2 text-left text-xs font-semibold text-[var(--muted)]">Status</th>
                      <th className="px-3 py-2 text-right text-xs font-semibold text-[var(--muted)]">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {uploadsLoading ? (
                      <tr>
                        <td colSpan={5} className="px-3 py-5 text-center text-sm text-[var(--muted)]">
                          Loading uploads...
                        </td>
                      </tr>
                    ) : filteredUploads.length ? (
                      filteredUploads.map((item) => {
                        const id = resolveUploadId(item);
                        const fileName = String(item.original_name ?? item.name ?? "Untitled");
                        return (
                          <tr
                            key={id || fileName}
                            className="cursor-pointer border-t border-[var(--border)] hover:bg-[var(--surface-subtle)]"
                            onClick={() => id && router.push(`/files/${encodeURIComponent(id)}`)}
                          >
                            <td className="px-3 py-2 text-[13px] text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                              {fileName}
                            </td>
                            <td className="px-3 py-2 text-[13px] text-[var(--muted)]">
                              {String(item.content_type ?? item.ext ?? "file")}
                            </td>
                            <td className="px-3 py-2 text-[13px] text-[var(--muted)]">
                              {formatBytes(Number(item.size_bytes) || 0)}
                            </td>
                            <td className="px-3 py-2 text-[13px] text-[var(--muted)]">
                              {String(item.status ?? "uploaded")}
                            </td>
                            <td className="px-3 py-2 text-right">
                              <button
                                type="button"
                                onClick={(event) => {
                                  event.stopPropagation();
                                  if (id) void deleteUpload(id);
                                }}
                                disabled={!id}
                                className="rounded-md border border-red-200 px-2 py-1 text-[11px] text-red-600 hover:bg-red-50 disabled:opacity-60"
                              >
                                Delete
                              </button>
                            </td>
                          </tr>
                        );
                      })
                    ) : (
                      <tr>
                        <td colSpan={5} className="px-3 py-5 text-center text-sm text-[var(--muted)]">
                          No uploads found.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>

            {drawerOpen ? (
              <div className="absolute inset-0 z-30 md:hidden">
                <button
                  type="button"
                  aria-label="Close drawer backdrop"
                  className="absolute inset-0 bg-black/25"
                  onClick={() => setDrawerOpen(false)}
                />
                <div className="relative z-10 h-full w-[74%] max-w-[290px]">
                  <div className="absolute right-3 top-3 z-20">
                    <button
                      type="button"
                      onClick={() => setDrawerOpen(false)}
                      className="inline-flex h-6 w-6 items-center justify-center rounded bg-[color-mix(in_oklab,var(--charcoal)_8%,white)] text-[var(--muted)]"
                      aria-label="Close drawer"
                    >
                      ×
                    </button>
                  </div>
                  {sidebar}
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </section>
    </main>
  );
}

function TopBar({ onOpenMenu }: { onOpenMenu: () => void }) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-[var(--border)] pb-3 md:border-b-0 md:pb-0">
      <button
        type="button"
        onClick={onOpenMenu}
        className="inline-flex h-7 w-7 items-center justify-center rounded border border-[var(--border)] text-[var(--deep-navy)] dark:text-[var(--foreground)] md:hidden"
        aria-label="Open menu"
      >
        ☰
      </button>

      <div className="flex items-center gap-2 md:hidden">
        <button className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--electric-blue)]">
          Upgrade Plan
        </button>
        <NotificationBell />
        <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[linear-gradient(140deg,#f9d576,#f39f6a)] text-[13px]">
          🧑
        </span>
      </div>
    </div>
  );
}

function BrandWordmark() {
  return (
    <picture>
      <source media="(prefers-color-scheme: dark)" srcSet="/icon-light.png" />
      <img src="/icon-dark.png" alt="Demycorp" className="h-6 w-auto" />
    </picture>
  );
}
