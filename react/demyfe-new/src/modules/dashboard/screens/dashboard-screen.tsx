"use client";

import {
  defaultResultUrl,
  EngineApiError,
  getFinalResult,
  startQuery,
  streamQuery,
  type QueryStreamEventName,
} from "@/shared/api/engine";
import { fetchProjects, resolveProjectId, type ProjectRecord } from "@/shared/api/projects";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

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

type InsightCard = {
  title: string;
  description: string;
  iconSrc: string;
  tone: "navy" | "teal" | "blue" | "gold";
  order: string;
};

const cards: InsightCard[] = [
  {
    title: "Customer Overview Dashboard",
    description:
      "View a summary of all customers, including key demographics and signup trends",
    iconSrc: "/overview.png",
    tone: "navy",
    order: "order-1 md:order-1",
  },
  {
    title: "Advanced Filters",
    description: "Combine multiple conditions to narrow down customer segments",
    iconSrc: "/filters.png",
    tone: "gold",
    order: "order-2 md:order-4",
  },
  {
    title: "Growth Analysis",
    description: "Track customer growth trends and historical signups",
    iconSrc: "/growth.png",
    tone: "blue",
    order: "order-3 md:order-3",
  },
  {
    title: "Key Insights Summary",
    description: "Get processed insights and highlights from your data",
    iconSrc: "/insights.png",
    tone: "teal",
    order: "order-4 md:order-2",
  },
];

const toneStyles: Record<InsightCard["tone"], string> = {
  navy: "bg-[color-mix(in_oklab,var(--deep-navy)_10%,white)] text-[var(--deep-navy)]",
  teal: "bg-[color-mix(in_oklab,var(--cyan-teal)_26%,white)] text-[color-mix(in_oklab,var(--cyan-teal)_70%,var(--deep-navy))]",
  blue: "bg-[color-mix(in_oklab,var(--electric-blue)_16%,white)] text-[var(--electric-blue)]",
  gold: "bg-[color-mix(in_oklab,var(--insight-gold)_30%,white)] text-[color-mix(in_oklab,var(--insight-gold)_90%,var(--charcoal))]",
};

const PROJECT_SELECTION_STORAGE_KEY = "dashboard_selected_project_id";
const CREATE_PROJECT_OPTION = "__create_project__";
const PROJECT_DIVIDER_OPTION = "__project_divider__";
const MAX_FILES_PER_QUERY = 10;
const QUERY_EVENT_ORDER: QueryStreamEventName[] = [
  "query.accepted",
  "upload.started",
  "upload.completed",
  "ingestion.started",
  "dataset.ready",
  "planner.started",
  "planner.completed",
  "query.executing",
  "query.result",
  "answer.chunk",
  "completed",
  "failed",
];

type SelectedUpload = {
  id: string;
  file: File;
  sizeLabel: string;
};

type TimelineEntry = {
  event: QueryStreamEventName;
  label: string;
  status: "pending" | "active" | "done" | "failed";
  detail?: string;
};

const readStoredProjectId = (): string => {
  if (typeof window === "undefined") return "";

  const selected = window.sessionStorage.getItem(PROJECT_SELECTION_STORAGE_KEY);
  if (selected) return selected;

  const sources = [window.localStorage, window.sessionStorage];
  for (const storage of sources) {
    try {
      const raw = storage.getItem("user");
      if (!raw) continue;
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const projectId = parsed.default_project_id ?? parsed.project_id ?? parsed.projectId;
      if (typeof projectId === "string" && projectId.trim()) return projectId;
    } catch {
      // ignore malformed user payload
    }
  }

  return "";
};

export function DashboardScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [taskInput, setTaskInput] = useState("");
  const [animatedHint, setAnimatedHint] = useState("");
  const [hintIndex, setHintIndex] = useState(0);
  const [projects, setProjects] = useState<ProjectRecord[]>([]);
  const [projectsLoading, setProjectsLoading] = useState(true);
  const [selectedProjectId, setSelectedProjectId] = useState("");
  const [taskError, setTaskError] = useState("");
  const [taskSuccess, setTaskSuccess] = useState("");
  const [submittingTask, setSubmittingTask] = useState(false);
  const [selectedFiles, setSelectedFiles] = useState<SelectedUpload[]>([]);
  const [timeline, setTimeline] = useState<TimelineEntry[]>(() =>
    QUERY_EVENT_ORDER.filter((event) => event !== "answer.chunk").map((event) => ({
      event,
      label: event.replace(".", " "),
      status: "pending",
    })),
  );
  const [streamedAnswer, setStreamedAnswer] = useState("");
  const [resultPreview, setResultPreview] = useState<Record<string, unknown> | null>(null);
  const [finalResult, setFinalResult] = useState<Record<string, unknown> | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const streamAbortRef = useRef<AbortController | null>(null);

  const hints = useMemo(
    () => [
      "Assign a task or ask anything",
      "Summarize customer growth for this quarter",
      "Find top 10 transacting merchants",
      "Create an insights report for leadership",
    ],
    [],
  );

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
    }
  }, [router]);

  useEffect(() => {
    let active = true;

    const loadProjects = async () => {
      const token = getValidAccessToken();
      if (!token) {
        clearAuthSession();
        router.replace("/login");
        return;
      }

      setProjectsLoading(true);
      try {
        const list = await fetchProjects(token);
        if (!active) return;

        setProjects(list);

        const storedId = readStoredProjectId();
        const ids = new Set(list.map((project) => resolveProjectId(project)).filter(Boolean));
        const fallbackId = resolveProjectId(list[0] ?? {});
        setSelectedProjectId(ids.has(storedId) ? storedId : fallbackId);
      } catch (error) {
        if (!active) return;
        setTaskError(error instanceof Error ? error.message : "Failed to load projects.");
      } finally {
        if (active) setProjectsLoading(false);
      }
    };

    void loadProjects();

    return () => {
      active = false;
    };
  }, [router]);

  useEffect(() => {
    if (taskInput) return;

    const fullText = hints[hintIndex % hints.length];
    let charIndex = 0;
    const resetTimer = setTimeout(() => setAnimatedHint(""), 0);
    let holdTimer: ReturnType<typeof setTimeout> | undefined;

    const typeTimer = setInterval(() => {
      charIndex += 1;
      setAnimatedHint(fullText.slice(0, charIndex));
      if (charIndex >= fullText.length) {
        clearInterval(typeTimer);
        holdTimer = setTimeout(() => {
          setHintIndex((prev) => (prev + 1) % hints.length);
        }, 1200);
      }
    }, 35);

    return () => {
      clearTimeout(resetTimer);
      clearInterval(typeTimer);
      if (holdTimer) clearTimeout(holdTimer);
    };
  }, [hintIndex, hints, taskInput]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    if (!selectedProjectId) return;
    window.sessionStorage.setItem(PROJECT_SELECTION_STORAGE_KEY, selectedProjectId);
  }, [selectedProjectId]);

  const selectedProjectName = useMemo(() => {
    const current = projects.find((project) => resolveProjectId(project) === selectedProjectId);
    return String(current?.name ?? "selected project");
  }, [projects, selectedProjectId]);

  useEffect(() => {
    return () => {
      streamAbortRef.current?.abort();
    };
  }, []);

  const updateTimeline = (
    eventName: QueryStreamEventName,
    status: TimelineEntry["status"],
    detail?: string,
  ) => {
    setTimeline((current) =>
      current.map((entry) =>
        entry.event === eventName
          ? {
              ...entry,
              status,
              detail: detail ?? entry.detail,
            }
          : entry,
      ),
    );
  };

  const resetQueryState = () => {
    setTaskError("");
    setTaskSuccess("");
    setStreamedAnswer("");
    setResultPreview(null);
    setFinalResult(null);
    setTimeline(
      QUERY_EVENT_ORDER.filter((event) => event !== "answer.chunk").map((event) => ({
        event,
        label: event.replace(".", " "),
        status: "pending",
      })),
    );
  };

  const describeFileSize = (file: File) => {
    if (file.size >= 1024 * 1024) return `${(file.size / (1024 * 1024)).toFixed(1)} MB`;
    if (file.size >= 1024) return `${Math.max(1, Math.round(file.size / 1024))} KB`;
    return `${file.size} B`;
  };

  const appendFiles = (incoming: FileList | File[]) => {
    const next = Array.from(incoming ?? []);
    if (!next.length) return;

    setTaskError("");

    setSelectedFiles((current) => {
      const seen = new Set(current.map((item) => `${item.file.name}-${item.file.size}-${item.file.lastModified}`));
      const additions = next.flatMap((file) => {
        const key = `${file.name}-${file.size}-${file.lastModified}`;
        if (seen.has(key)) return [];
        return [
          {
            id:
              typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
                ? crypto.randomUUID()
                : `${Date.now()}-${Math.random().toString(16).slice(2)}`,
            file,
            sizeLabel: describeFileSize(file),
          },
        ];
      });

      const merged = [...current, ...additions];
      if (merged.length > MAX_FILES_PER_QUERY) {
        setTaskError(`You can upload a maximum of ${MAX_FILES_PER_QUERY} files at a time.`);
      }
      return merged.slice(0, MAX_FILES_PER_QUERY);
    });
  };

  const removeSelectedFile = (fileId: string) => {
    setSelectedFiles((current) => current.filter((item) => item.id !== fileId));
  };

  const handleSubmitTask = async () => {
    const query = taskInput.trim();
    if (!query) return;
    if (!selectedFiles.length) {
      setTaskSuccess("");
      setTaskError("Attach at least one file before starting a query.");
      return;
    }

    if (!selectedProjectId) {
      setTaskSuccess("");
      setTaskError("Select a project before creating a task.");
      return;
    }

    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    setSubmittingTask(true);
    resetQueryState();
    streamAbortRef.current?.abort();
    const controller = new AbortController();
    streamAbortRef.current = controller;

    try {
      const response = await startQuery({
        token,
        question: query,
        files: selectedFiles.map((item) => item.file),
        workspaceId: selectedProjectId,
      });

      updateTimeline("query.accepted", "done");

      await streamQuery({
        token,
        streamUrl: response.stream_url,
        signal: controller.signal,
        onEvent: (event) => {
          if (event.event === "answer.chunk") {
            const content = event.payload.content;
            if (typeof content === "string") {
              setStreamedAnswer((current) => current + content);
            }
            return;
          }

          if (event.event === "query.result") {
            setResultPreview(event.payload);
            updateTimeline("query.result", "done");
            return;
          }

          if (event.event === "upload.started") {
            updateTimeline("upload.started", "active");
            return;
          }

          if (event.event === "upload.completed") {
            updateTimeline("upload.started", "done");
            updateTimeline("upload.completed", "done");
            return;
          }

          if (event.event === "ingestion.started") {
            updateTimeline("ingestion.started", "active");
            return;
          }

          if (event.event === "dataset.ready") {
            updateTimeline("ingestion.started", "done");
            updateTimeline("dataset.ready", "done");
            return;
          }

          if (event.event === "planner.started") {
            updateTimeline("planner.started", "active");
            return;
          }

          if (event.event === "planner.completed") {
            updateTimeline("planner.started", "done");
            updateTimeline("planner.completed", "done");
            return;
          }

          if (event.event === "query.executing") {
            updateTimeline("query.executing", "active");
            return;
          }

          if (event.event === "failed") {
            const code = event.payload.code;
            const message = event.payload.message;
            const detail = [code, message].filter((value) => typeof value === "string").join(": ");
            updateTimeline("failed", "failed", detail || "Query failed");
            setTaskError(detail || "Query failed.");
            return;
          }

          if (event.event === "completed") {
            updateTimeline("query.executing", "done");
            updateTimeline("completed", "done");
            return;
          }

          updateTimeline(event.event, "done");
        },
      });

      const canonicalResult = await getFinalResult(
        response.result_url || defaultResultUrl(response.query_session_id),
        token,
      );

      setFinalResult(canonicalResult);
      setTaskInput("");
      setTaskSuccess(`Query completed in ${selectedProjectName}.`);
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") return;
      if (error instanceof EngineApiError && error.status === 401) {
        clearAuthSession();
        router.replace("/login");
        return;
      }
      setTaskError(error instanceof Error ? error.message : "Failed to create query.");
    } finally {
      setSubmittingTask(false);
      streamAbortRef.current = null;
    }
  };

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
      <div className="h-full w-full">
        <section className="h-full w-full overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
          <div className="grid h-full md:grid-cols-[290px_1fr]">
            <div className="hidden md:block">{sidebar}</div>

            <div className="relative flex h-full flex-col overflow-y-auto px-3 py-3 md:px-5 md:py-4">
              <TopBar
                onOpenMenu={() => setDrawerOpen(true)}
                projects={projects}
                projectsLoading={projectsLoading}
                selectedProjectId={selectedProjectId}
                onSelectProject={(projectId) => {
                  if (projectId === CREATE_PROJECT_OPTION) {
                    router.push("/projects/new");
                    return;
                  }

                  setSelectedProjectId(projectId);
                  setTaskError("");
                  setTaskSuccess("");
                }}
              />

              <section className="mx-auto mt-10 w-full max-w-[700px] text-center md:mt-12">
                <h2 className="text-[28px] font-semibold leading-tight tracking-tight text-[var(--deep-navy)] dark:text-[var(--foreground)] md:text-[44px]">
                  Start Anywhere With Demycorp
                </h2>
                <p className="mx-auto mt-2 max-w-[620px] text-xs leading-5 text-[var(--muted)] md:text-sm">
                  Upload data files, connect live sources, and query your data using natural
                  language*. clean, direct, ideal for an action prompt under an AI input box.
                </p>
              </section>

              <section className="mx-auto mt-6 w-full max-w-[700px]">
                <div className="grid grid-cols-2 gap-2">
                  {cards.map((card, index) => (
                    <article
                      key={card.title}
                      className={`${card.order} rounded-lg border border-[var(--border)] bg-[var(--surface)] p-3`}
                    >
                      <div className={`inline-flex h-7 w-7 items-center justify-center rounded-md ${toneStyles[card.tone]}`}>
                        <Image src={card.iconSrc} alt="" width={16} height={16} className="h-4 w-4 object-contain" />
                      </div>
                      <h3 className="mt-2 text-[13px] font-semibold leading-tight text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                        {card.title}
                      </h3>
                      <p className={`mt-1 text-[11px] leading-4 text-[var(--muted)] ${index < 2 ? "hidden md:block" : "hidden md:block"}`}>
                        {card.description}
                      </p>
                    </article>
                  ))}
                </div>
              </section>

              <section className="flex flex-1 items-center justify-center py-8">
                <div className="mx-auto w-full max-w-[700px]">
                  <div className="flex items-center justify-between px-1 pb-2 text-xs text-[var(--muted)]">
                    <span>
                      {selectedProjectId
                        ? `New tasks will be created under ${selectedProjectName}.`
                        : "Select a project to attach this task."}
                    </span>
                    {!projectsLoading && !projects.length ? (
                      <Link href="/projects/new" className="text-[var(--electric-blue)] hover:underline">
                        Create project
                      </Link>
                    ) : null}
                  </div>

                  {taskError ? (
                    <div className="mb-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700 dark:border-red-500/40 dark:bg-red-500/10 dark:text-red-200">
                      {taskError}
                    </div>
                  ) : null}

                  {taskSuccess ? (
                    <div className="mb-2 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700 dark:border-emerald-500/40 dark:bg-emerald-500/10 dark:text-emerald-200">
                      {taskSuccess}
                    </div>
                  ) : null}

                  <div className="w-full rounded-2xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 transition focus-within:border-[var(--electric-blue)] focus-within:shadow-[0_0_0_2px_color-mix(in_oklab,var(--electric-blue)_24%,transparent)] md:px-5">
                    {selectedFiles.length ? (
                      <div className="mb-3 flex flex-wrap gap-1.5 border-b border-[var(--border)] pb-3">
                        {selectedFiles.map((item) => (
                          <div
                            key={item.id}
                            className="flex w-[calc(50%-0.1875rem)] min-w-0 items-center gap-1 rounded-lg border border-[var(--border)] bg-[color-mix(in_oklab,var(--electric-blue)_8%,white)] px-1.5 py-1 text-[var(--deep-navy)] sm:w-[calc(33.333%-0.25rem)] lg:w-[calc(20%-0.3rem)] dark:border-[color-mix(in_oklab,var(--electric-blue)_35%,var(--border))] dark:bg-[color-mix(in_oklab,var(--electric-blue)_18%,var(--charcoal))] dark:text-[var(--foreground)]"
                          >
                            <div className="min-w-0 flex-1">
                              <p
                                className="truncate text-[9px] font-medium leading-tight text-[var(--deep-navy)] dark:text-[var(--foreground)]"
                                title={item.file.name}
                              >
                                {item.file.name}
                              </p>
                              <p className="mt-0.5 text-[8px] leading-tight text-[var(--muted)] dark:text-[var(--foreground-subtle)]">{item.sizeLabel}</p>
                            </div>
                            <button
                              type="button"
                              onClick={() => removeSelectedFile(item.id)}
                              className="inline-flex h-3.5 w-3.5 shrink-0 items-center justify-center rounded-full text-[8px] text-[var(--muted)] transition hover:bg-[color-mix(in_oklab,var(--charcoal)_12%,white)] dark:text-[var(--foreground-subtle)] dark:hover:bg-[color-mix(in_oklab,var(--electric-blue)_18%,white)]"
                              aria-label={`Remove ${item.file.name}`}
                            >
                              ×
                            </button>
                          </div>
                        ))}
                      </div>
                    ) : null}

                    <div className="flex min-h-20 items-end justify-between gap-3 md:min-h-24">
                      <div className="relative flex-1">
                        <textarea
                          rows={3}
                          value={taskInput}
                          onChange={(e) => {
                            setTaskInput(e.target.value);
                            if (taskError) setTaskError("");
                            if (taskSuccess) setTaskSuccess("");
                          }}
                          onKeyDown={(event) => {
                            if (event.key === "Enter" && !event.shiftKey) {
                              event.preventDefault();
                              void handleSubmitTask();
                            }
                          }}
                          aria-label="Task input"
                          className="min-h-[72px] w-full resize-none border-0 bg-transparent pt-2 text-base leading-6 text-[var(--foreground)] outline-none md:min-h-[84px] md:text-lg"
                        />
                        {!taskInput ? (
                          <span className="pointer-events-none absolute left-0 top-2 text-base leading-6 text-[var(--muted)] md:text-lg">
                            {animatedHint}
                            <span className="ml-0.5 inline-block animate-pulse">|</span>
                          </span>
                        ) : null}
                      </div>
                      <div className="flex shrink-0 items-center gap-2">
                        <button
                          type="button"
                          aria-label="Add"
                          onClick={() => fileInputRef.current?.click()}
                          className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--charcoal)_10%,white)] text-sm font-semibold text-[var(--charcoal)] transition hover:scale-105 hover:brightness-95 dark:bg-[color-mix(in_oklab,var(--cool-gray)_12%,var(--charcoal))] dark:text-[var(--foreground)] md:h-8 md:w-8"
                        >
                          +
                        </button>
                        <button
                          type="button"
                          aria-label="Submit"
                          onClick={() => void handleSubmitTask()}
                          disabled={submittingTask || !taskInput.trim() || !selectedProjectId}
                          className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[var(--electric-blue)] text-sm font-semibold text-white transition hover:scale-105 hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-55 md:h-8 md:w-8"
                        >
                          {submittingTask ? "…" : "↑"}
                        </button>
                      </div>
                    </div>
                  </div>

                  <input
                    ref={fileInputRef}
                    type="file"
                    multiple
                    onChange={(event) => {
                      if (event.target.files?.length) {
                        appendFiles(event.target.files);
                        if (taskError) setTaskError("");
                      }
                      event.target.value = "";
                    }}
                    className="hidden"
                  />

                  {(submittingTask || streamedAnswer || resultPreview || finalResult) ? (
                    <section className="mt-4 rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-4">
                      <div className="grid gap-4 lg:grid-cols-[240px_1fr]">
                        <div>
                          <h3 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                            Query progress
                          </h3>
                          <ul className="mt-3 space-y-2">
                            {timeline.map((entry) => (
                              <li
                                key={entry.event}
                                className="rounded-lg border border-[var(--border)] px-3 py-2"
                              >
                                <div className="flex items-center justify-between gap-2">
                                  <span className="text-xs font-medium capitalize text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                                    {entry.label}
                                  </span>
                                  <span
                                    className={`text-[10px] uppercase tracking-[0.08em] ${
                                      entry.status === "done"
                                        ? "text-emerald-600"
                                        : entry.status === "failed"
                                          ? "text-red-600"
                                          : entry.status === "active"
                                            ? "text-[var(--electric-blue)]"
                                            : "text-[var(--muted)]"
                                    }`}
                                  >
                                    {entry.status}
                                  </span>
                                </div>
                                {entry.detail ? (
                                  <p className="mt-1 text-[11px] text-[var(--muted)]">{entry.detail}</p>
                                ) : null}
                              </li>
                            ))}
                          </ul>
                        </div>

                        <div className="space-y-4">
                          <div>
                            <h3 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                              Live answer
                            </h3>
                            <div className="mt-2 min-h-24 rounded-xl border border-[var(--border)] bg-[var(--surface-subtle)] px-3 py-3 text-sm text-[var(--foreground)]">
                              {streamedAnswer || (submittingTask ? "Waiting for streamed answer..." : "No answer yet.")}
                            </div>
                          </div>

                          <div>
                            <h3 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                              Result preview
                            </h3>
                            <pre className="mt-2 max-h-48 overflow-auto rounded-xl border border-[var(--border)] bg-[var(--surface-subtle)] px-3 py-3 text-xs text-[var(--foreground)]">
                              {JSON.stringify(resultPreview ?? finalResult ?? { status: "No result yet" }, null, 2)}
                            </pre>
                          </div>
                        </div>
                      </div>
                    </section>
                  ) : null}
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
      </div>
    </main>
  );
}

function TopBar({
  onOpenMenu,
  onSelectProject,
  projects,
  projectsLoading,
  selectedProjectId,
}: {
  onOpenMenu: () => void;
  onSelectProject: (projectId: string) => void;
  projects: ProjectRecord[];
  projectsLoading: boolean;
  selectedProjectId: string;
}) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-[var(--border)] pb-3 md:border-b-0 md:pb-0">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={onOpenMenu}
          className="inline-flex h-7 w-7 items-center justify-center rounded border border-[var(--border)] text-[var(--deep-navy)] dark:text-[var(--foreground)] md:hidden"
          aria-label="Open menu"
        >
          ☰
        </button>
        <select
          value={selectedProjectId}
          onChange={(event) => onSelectProject(event.target.value)}
          disabled={projectsLoading}
          aria-label="Select project"
          className="inline-flex h-8 min-w-[150px] items-center rounded-full border border-[var(--border)] bg-[var(--surface)] px-3 text-[11px] text-[var(--deep-navy)] outline-none disabled:opacity-60 dark:text-[var(--foreground)] md:min-w-[200px]"
        >
          <option value="">{projectsLoading ? "Loading projects..." : "Select project"}</option>
          <option value={CREATE_PROJECT_OPTION}>+ Create project</option>
          <option value={PROJECT_DIVIDER_OPTION} disabled>
            ----------------
          </option>
          {projects.map((project) => {
            const projectId = resolveProjectId(project);
            return (
              <option key={projectId || String(project.name ?? "project")} value={projectId}>
                {String(project.name ?? projectId)}
              </option>
            );
          })}
        </select>
      </div>

      <div className="hidden items-center gap-1.5 md:flex">
        <span className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--electric-blue)]">
          Free Plan
        </span>
        <span className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--muted)]">
          Upgrade
        </span>
      </div>

      <div className="flex items-center gap-2">
        <button className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--electric-blue)] md:hidden">
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
