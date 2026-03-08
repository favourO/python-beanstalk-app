"use client";

import { fetchProjects, resolveProjectId, type ProjectRecord } from "@/shared/api/projects";
import {
  clearAuthSession,
  getValidAccessToken,
  hasValidAuthSession,
} from "@/shared/auth/session";
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

const formatDateLong = (value: string): string => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
};

export function ProjectsScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [projects, setProjects] = useState<ProjectRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
    }
  }, [router]);

  const loadProjects = useCallback(async () => {
    setRefreshing(true);
    setError("");

    try {
      const token = getValidAccessToken();
      if (!token) {
        clearAuthSession();
        router.replace("/login");
        return;
      }

      const list = await fetchProjects(token);
      setProjects(list);
    } catch (requestError) {
      setError(
        requestError instanceof Error ? requestError.message : "Failed to load projects.",
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [router]);

  useEffect(() => {
    void loadProjects();
  }, [loadProjects]);

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

            <header className="mt-3 flex flex-col gap-3 sm:mt-0 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h1 className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Projects
                </h1>
                <p className="text-sm text-[var(--muted)]">
                  Organise uploads, queries, and dashboards around your initiatives.
                </p>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => void loadProjects()}
                  disabled={refreshing}
                  className="inline-flex items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-medium text-[var(--muted)] hover:bg-[var(--surface-subtle)] disabled:opacity-60"
                >
                  <span className={refreshing ? "animate-spin" : ""}>↻</span>
                  Refresh
                </button>
                <Link
                  href="/projects/new"
                  className="inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white hover:brightness-95"
                >
                  <span>+</span>
                  New project
                </Link>
              </div>
            </header>

            {error ? (
              <div className="mt-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-500/40 dark:bg-red-500/10 dark:text-red-200">
                {error}
              </div>
            ) : null}

            <section className="mt-5 pb-8">
              {loading ? (
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  {[...Array(6)].map((_, idx) => (
                    <div
                      key={`project-skeleton-${idx}`}
                      className="animate-pulse rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5"
                    >
                      <div className="h-4 w-2/3 rounded bg-[color-mix(in_oklab,var(--charcoal)_12%,white)]" />
                      <div className="mt-3 h-3 w-full rounded bg-[color-mix(in_oklab,var(--charcoal)_10%,white)]" />
                      <div className="mt-2 h-3 w-5/6 rounded bg-[color-mix(in_oklab,var(--charcoal)_10%,white)]" />
                    </div>
                  ))}
                </div>
              ) : projects.length ? (
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  {projects.map((project) => {
                    const projectId = resolveProjectId(project);
                    const name = String(project.name ?? "Untitled project");
                    const description = String(project.description ?? "");
                    const industry = String(project.industry_type ?? "");
                    const role = String(project.current_role ?? "");
                    const created =
                      typeof project.created_at === "string"
                        ? formatDateLong(project.created_at)
                        : "";

                    return (
                      <article
                        key={projectId || name}
                        role="button"
                        tabIndex={0}
                        onClick={() => projectId && router.push(`/projects/${projectId}`)}
                        onKeyDown={(event) => {
                          if ((event.key === "Enter" || event.key === " ") && projectId) {
                            event.preventDefault();
                            router.push(`/projects/${projectId}`);
                          }
                        }}
                        className="group relative flex h-full cursor-pointer flex-col rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-[var(--electric-blue)]"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                              {name}
                            </h2>
                            {industry ? (
                              <p className="mt-1 text-xs uppercase tracking-wide text-[var(--electric-blue)]">
                                {industry}
                              </p>
                            ) : null}
                            {role ? (
                              <p className="mt-1 text-xs text-[var(--muted)]">Your role: {role}</p>
                            ) : null}
                          </div>
                          <span className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--electric-blue)_12%,white)] text-[var(--electric-blue)]">
                            →
                          </span>
                        </div>
                        {description ? (
                          <p className="mt-3 line-clamp-3 text-sm text-[var(--muted)]">{description}</p>
                        ) : null}
                        {created ? (
                          <p className="mt-auto pt-4 text-xs text-[var(--muted)]">Created {created}</p>
                        ) : null}
                      </article>
                    );
                  })}
                </div>
              ) : (
                <div className="rounded-2xl border border-dashed border-[var(--border-strong)] bg-[var(--surface)] p-8 text-center text-sm text-[var(--muted)]">
                  <p className="font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                    No projects yet
                  </p>
                  <p className="mt-1">
                    Create your first project to link uploads, insights, and stakeholders.
                  </p>
                  <Link
                    href="/projects/new"
                    className="mt-4 inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white hover:brightness-95"
                  >
                    <span>+</span>
                    Create a project
                  </Link>
                </div>
              )}
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
