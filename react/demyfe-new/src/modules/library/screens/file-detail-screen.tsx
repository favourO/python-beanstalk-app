"use client";

import {
  resolveUploadsScopeId,
  uploadsApi,
  type UploadRecord,
  type UploadRowsResponse,
} from "@/shared/api/uploads";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

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

const PAGE_SIZE = 100;

const formatBytes = (bytes: number): string => {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const power = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / Math.pow(1024, power)).toFixed(power > 0 ? 1 : 0)} ${units[power]}`;
};

const formatDateTime = (value: unknown): string => {
  if (typeof value !== "string") return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
};

const getProjectId = (item: UploadRecord): string => {
  if (typeof item.project_id === "string") return item.project_id;
  if (item.project && typeof item.project === "object") {
    const project = item.project as Record<string, unknown>;
    if (typeof project.project_id === "string") return project.project_id;
    if (typeof project.id === "string") return project.id;
  }
  return "";
};

const urlFromKey = (key: unknown): string => {
  if (typeof key !== "string" || !key.trim()) return "";
  if (/^https?:\/\//i.test(key)) return key;
  const prefix =
    (process.env.NEXT_PUBLIC_S3_PUBLIC_PREFIX ||
      "https://s3-bucket-imortol.s3.us-east-1.amazonaws.com").replace(/\/$/, "");
  return `${prefix}/${key.replace(/^\/+/, "")}`;
};

const getFileCategory = (meta: UploadRecord | null): "pdf" | "image" | "sheet" | "csv" | "text" | "unknown" => {
  if (!meta) return "unknown";
  const contentType = String(meta.content_type ?? "").toLowerCase();
  const ext = String(meta.ext ?? "").toLowerCase().replace(/^\./, "");
  const name = String(meta.original_name ?? meta.name ?? "").toLowerCase();

  if (contentType.includes("pdf") || ext === "pdf" || name.endsWith(".pdf")) return "pdf";
  if (contentType.startsWith("image/") || ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"].includes(ext)) {
    return "image";
  }
  if (
    contentType.includes("spreadsheet") ||
    contentType.includes("ms-excel") ||
    ["xls", "xlsx"].includes(ext) ||
    name.endsWith(".xls") ||
    name.endsWith(".xlsx")
  ) {
    return "sheet";
  }
  if (contentType.includes("csv") || ext === "csv" || name.endsWith(".csv")) return "csv";
  if (contentType.startsWith("text/") || ["txt", "json", "md", "log"].includes(ext)) return "text";
  return "unknown";
};

export function FileDetailScreen({ uploadId }: { uploadId: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);

  const [meta, setMeta] = useState<UploadRecord | null>(null);
  const [rows, setRows] = useState<UploadRowsResponse>({
    data: [],
    columns: [],
    total_rows: 0,
  });
  const [offset, setOffset] = useState(0);
  const [loadingMeta, setLoadingMeta] = useState(true);
  const [loadingRows, setLoadingRows] = useState(false);
  const [textPreview, setTextPreview] = useState("");
  const [textPreviewLoading, setTextPreviewLoading] = useState(false);
  const [error, setError] = useState("");
  const fileCategory = useMemo(() => getFileCategory(meta), [meta]);

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
    }
  }, [router]);

  const loadMeta = useCallback(async () => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }
    setLoadingMeta(true);
    setError("");
    try {
      // Stage parity: resolve details from uploads list scoped to current user.
      const scopeId = resolveUploadsScopeId();
      if (!scopeId) throw new Error("Unable to determine the current user. Please sign in again.");
      const list = await uploadsApi.list(token, scopeId);
      const found =
        list.find((entry) => String(entry.upload_id ?? entry.uploadId ?? entry.id ?? "") === uploadId) ?? null;
      if (!found) throw new Error("Upload not found.");
      setMeta(found);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Failed to load file details.");
    } finally {
      setLoadingMeta(false);
    }
  }, [router, uploadId]);

  const loadRows = useCallback(
    async (nextOffset: number) => {
      const token = getValidAccessToken();
      if (!token) {
        clearAuthSession();
        router.replace("/login");
        return;
      }
      if (!meta) return;
      if (fileCategory !== "sheet" && fileCategory !== "csv") return;
      const projectId = getProjectId(meta);
      if (!projectId) return;

      setLoadingRows(true);
      setError("");
      try {
        const data = await uploadsApi.rows(token, uploadId, projectId, nextOffset, PAGE_SIZE);
        setRows(data);
        setOffset(nextOffset);
      } catch (rowsError) {
        setError(rowsError instanceof Error ? rowsError.message : "Failed to load rows.");
      } finally {
        setLoadingRows(false);
      }
    },
    [fileCategory, meta, router, uploadId],
  );

  useEffect(() => {
    void loadMeta();
  }, [loadMeta]);

  useEffect(() => {
    if (!meta) return;
    if (fileCategory !== "sheet" && fileCategory !== "csv") return;
    const projectId = getProjectId(meta);
    if (!projectId) return;
    void loadRows(0);
  }, [fileCategory, loadRows, meta]);

  const totalPages = Math.max(1, Math.ceil((rows.total_rows || rows.data.length) / PAGE_SIZE));
  const currentPage = Math.floor(offset / PAGE_SIZE) + 1;
  const sourceUrl = useMemo(
    () =>
      urlFromKey(
        meta?.s3_key_json ?? meta?.s3_key_parquet ?? meta?.s3_key_csv ?? meta?.s3_key_raw ?? meta?.s3_key,
      ),
    [meta],
  );
  useEffect(() => {
    if (!sourceUrl || (fileCategory !== "csv" && fileCategory !== "text")) {
      setTextPreview("");
      setTextPreviewLoading(false);
      return;
    }
    let active = true;
    const run = async () => {
      setTextPreviewLoading(true);
      try {
        const response = await fetch(sourceUrl, { cache: "no-store" });
        const text = await response.text();
        if (!active) return;
        setTextPreview(text.split("\n").slice(0, 40).join("\n"));
      } catch {
        if (!active) return;
        setTextPreview("");
      } finally {
        if (active) setTextPreviewLoading(false);
      }
    };
    void run();
    return () => {
      active = false;
    };
  }, [fileCategory, sourceUrl]);

  const sidebar = (
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
              pathname.startsWith(item.href)
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

  return (
    <main className="h-screen w-screen overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
      <section className="h-full w-full overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
        <div className="grid h-full md:grid-cols-[290px_1fr]">
          <div className="hidden md:block">{sidebar}</div>
          <div className="relative flex h-full flex-col overflow-y-auto px-3 py-3 md:px-5 md:py-4">
            <TopBar onOpenMenu={() => setDrawerOpen(true)} />

            <div className="mt-3 space-y-4 md:mt-0">
              <button
                type="button"
                onClick={() => router.push("/library")}
                className="inline-flex items-center gap-2 text-sm font-medium text-[var(--electric-blue)] hover:underline"
              >
                ← Back to Library
              </button>

              {loadingMeta ? (
                <div className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-4 py-5 text-sm text-[var(--muted)]">
                  Loading file details...
                </div>
              ) : meta ? (
                <section className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <h1 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                        {String(meta.original_name ?? meta.name ?? "Untitled file")}
                      </h1>
                      <p className="mt-1 text-xs text-[var(--muted)]">
                        {formatDateTime(meta.created_at)} • {formatBytes(Number(meta.size_bytes) || 0)}
                      </p>
                    </div>
                    {sourceUrl ? (
                      <a
                        href={sourceUrl}
                        download
                        className="inline-flex h-9 items-center rounded-full bg-[var(--electric-blue)] px-4 text-xs font-medium text-white"
                      >
                        Download
                      </a>
                    ) : null}
                  </div>

                  <div className="mt-4 rounded-lg border border-[var(--border)] bg-[var(--surface-subtle)] p-3">
                    <h2 className="mb-2 text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      File preview
                    </h2>
                    {fileCategory === "pdf" && sourceUrl ? (
                      <iframe
                        src={sourceUrl}
                        title="PDF preview"
                        className="h-[68vh] w-full rounded-lg border border-[var(--border)] bg-white"
                      />
                    ) : fileCategory === "image" && sourceUrl ? (
                      <div className="overflow-hidden rounded-lg border border-[var(--border)] bg-white p-2">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={sourceUrl}
                          alt={String(meta.original_name ?? meta.name ?? "Uploaded image")}
                          className="mx-auto max-h-[68vh] w-auto object-contain"
                        />
                      </div>
                    ) : fileCategory === "sheet" || fileCategory === "csv" ? (
                      <p className="text-xs text-[var(--muted)]">
                        Spreadsheet preview is shown below in the rows table.
                      </p>
                    ) : fileCategory === "text" ? (
                      textPreviewLoading ? (
                        <p className="text-xs text-[var(--muted)]">Loading text preview...</p>
                      ) : textPreview ? (
                        <pre className="max-h-[68vh] overflow-auto rounded-lg border border-[var(--border)] bg-[var(--surface)] p-3 text-xs text-[var(--foreground)]">
                          {textPreview}
                        </pre>
                      ) : (
                        <p className="text-xs text-[var(--muted)]">
                          Text preview is unavailable. Use download to open this file.
                        </p>
                      )
                    ) : (
                      <p className="text-xs text-[var(--muted)]">
                        Inline preview is unavailable for this file type. Use download to open it.
                      </p>
                    )}
                  </div>

                  {getProjectId(meta) && (fileCategory === "sheet" || fileCategory === "csv") ? (
                    <div className="mt-4 rounded-lg border border-[var(--border)] bg-[var(--surface-subtle)] p-3">
                      <div className="mb-2 flex items-center justify-between gap-2">
                        <h2 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                          Preview rows
                        </h2>
                        <span className="text-xs text-[var(--muted)]">
                          Page {currentPage} of {totalPages}
                        </span>
                      </div>
                      <div className="overflow-x-auto rounded-lg border border-[var(--border)] bg-[var(--surface)]">
                        <table className="min-w-full text-sm">
                          <thead className="bg-[var(--surface-subtle)]">
                            <tr>
                              {(rows.columns.length
                                ? rows.columns
                                : Object.keys(rows.data[0] ?? {})
                              ).map((column) => (
                                <th
                                  key={column}
                                  className="px-3 py-2 text-left text-xs font-semibold text-[var(--muted)]"
                                >
                                  {column}
                                </th>
                              ))}
                            </tr>
                          </thead>
                          <tbody>
                            {loadingRows ? (
                              <tr>
                                <td className="px-3 py-4 text-center text-xs text-[var(--muted)]" colSpan={99}>
                                  Loading rows...
                                </td>
                              </tr>
                            ) : rows.data.length ? (
                              rows.data.map((row, index) => (
                                <tr key={`row-${index}`} className="border-t border-[var(--border)]">
                                  {(rows.columns.length
                                    ? rows.columns
                                    : Object.keys(rows.data[0] ?? {})
                                  ).map((column) => (
                                    <td key={`${index}-${column}`} className="px-3 py-2 text-xs text-[var(--foreground)]">
                                      {typeof row[column] === "object"
                                        ? JSON.stringify(row[column])
                                        : String(row[column] ?? "")}
                                    </td>
                                  ))}
                                </tr>
                              ))
                            ) : (
                              <tr>
                                <td className="px-3 py-4 text-center text-xs text-[var(--muted)]" colSpan={99}>
                                  No rows available.
                                </td>
                              </tr>
                            )}
                          </tbody>
                        </table>
                      </div>
                      <div className="mt-3 flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => void loadRows(Math.max(0, offset - PAGE_SIZE))}
                          disabled={offset <= 0 || loadingRows}
                          className="rounded-md border border-[var(--border)] px-2 py-1 text-xs text-[var(--muted)] disabled:opacity-60"
                        >
                          Prev
                        </button>
                        <button
                          type="button"
                          onClick={() => void loadRows(offset + PAGE_SIZE)}
                          disabled={currentPage >= totalPages || loadingRows}
                          className="rounded-md border border-[var(--border)] px-2 py-1 text-xs text-[var(--muted)] disabled:opacity-60"
                        >
                          Next
                        </button>
                      </div>
                    </div>
                  ) : (
                    <p className="mt-4 text-xs text-[var(--muted)]">
                      This file is not associated with a project yet.
                    </p>
                  )}
                </section>
              ) : (
                <div className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-4 py-5 text-sm text-[var(--muted)]">
                  File not found.
                </div>
              )}

              {error ? (
                <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700 dark:border-red-500/40 dark:bg-red-500/10 dark:text-red-200">
                  {error}
                </div>
              ) : null}
            </div>

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
