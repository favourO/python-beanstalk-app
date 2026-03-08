"use client";

import { API_BASE_URL } from "@/shared/api/auth";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChangeEvent, FormEvent, useMemo, useState } from "react";

const industryOptions = [
  "retail",
  "finance",
  "technology",
  "healthcare",
  "manufacturing",
  "education",
  "media",
];

const MODULE_KEYS = [
  { key: "allow_uploads", label: "Allow uploads" },
  { key: "allow_connected_data", label: "Connected data" },
  { key: "allow_engine_queries", label: "Engine queries" },
  { key: "allow_scientific_analysis", label: "Scientific analysis" },
] as const;

type Collaborator = {
  email: string;
  first_name: string;
  last_name: string;
  role: "collaborator";
  allow_uploads: boolean;
  allow_connected_data: boolean;
  allow_engine_queries: boolean;
  allow_scientific_analysis: boolean;
};

type Me = {
  plan?: string;
  subscription_plan?: string;
  billing_plan?: string;
  current_plan?: string;
  plan_name?: string;
  collaborator_limit?: number | string;
};

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

const resolveProjectId = (payload: unknown): string => {
  if (!payload || typeof payload !== "object") return "";
  const data = payload as Record<string, unknown>;
  if (typeof data.project_id === "string") return data.project_id;
  if (typeof data.id === "string") return data.id;
  if (data.project && typeof data.project === "object") {
    const project = data.project as Record<string, unknown>;
    if (typeof project.project_id === "string") return project.project_id;
    if (typeof project.id === "string") return project.id;
  }
  return "";
};

const getErrorMessage = (error: unknown, fallback: string): string => {
  if (!error || typeof error !== "object") return fallback;
  const record = error as Record<string, unknown>;
  const detail = record.detail ?? record.message ?? record.error;
  if (typeof detail === "string" && detail.trim()) return detail;
  return fallback;
};

const isValidEmail = (value: string): boolean => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

export function ProjectNewScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [form, setForm] = useState({
    name: "",
    industry_type: "",
    description: "",
  });
  const [collaborators, setCollaborators] = useState<Collaborator[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const me = useMemo<Me | null>(() => {
    if (typeof window === "undefined") return null;
    try {
      const raw = window.localStorage.getItem("user") ?? window.sessionStorage.getItem("user");
      return raw ? (JSON.parse(raw) as Me) : null;
    } catch {
      return null;
    }
  }, []);

  const rawPlan = useMemo(() => {
    return (
      (me?.plan ||
        me?.subscription_plan ||
        me?.billing_plan ||
        me?.current_plan ||
        me?.plan_name ||
        "") + ""
    )
      .toLowerCase()
      .trim();
  }, [me]);

  const collaboratorLimit = useMemo(() => {
    const parsed = Number(me?.collaborator_limit);
    if (Number.isFinite(parsed)) return parsed;
    if (rawPlan === "premium") return 15;
    if (rawPlan === "basic") return 5;
    return 0;
  }, [me, rawPlan]);

  const collaboratorsLocked = collaboratorLimit <= 0;
  const collaboratorLimitReached = collaboratorLimit > 0 && collaborators.length >= collaboratorLimit;
  const collaboratorInviteDisabled = collaboratorsLocked || collaboratorLimitReached;

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

  const updateField =
    (key: "name" | "industry_type" | "description") =>
    (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
      setForm((prev) => ({ ...prev, [key]: event.target.value }));
      if (error) setError("");
    };

  const addCollaboratorRow = () => {
    if (collaboratorInviteDisabled) return;
    setCollaborators((prev) => [
      ...prev,
      {
        email: "",
        first_name: "",
        last_name: "",
        role: "collaborator",
        allow_uploads: false,
        allow_connected_data: false,
        allow_engine_queries: false,
        allow_scientific_analysis: false,
      },
    ]);
  };

  const updateCollaborator =
    (index: number, key: keyof Collaborator) =>
    (event: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
      const value = event.target.value;
      setCollaborators((prev) =>
        prev.map((item, idx) =>
          idx === index
            ? ({
                ...item,
                [key]: key === "role" ? "collaborator" : value,
              } as Collaborator)
            : item,
        ),
      );
      if (error) setError("");
    };

  const toggleCollaboratorPermission =
    (index: number, key: (typeof MODULE_KEYS)[number]["key"]) => () => {
      setCollaborators((prev) =>
        prev.map((item, idx) =>
          idx === index ? { ...item, [key]: !item[key] } : item,
        ),
      );
    };

  const removeCollaboratorRow = (index: number) => {
    setCollaborators((prev) => prev.filter((_, idx) => idx !== index));
  };

  const requestWithAuth = async (path: string, init: RequestInit = {}) => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      throw new Error("Missing auth token.");
    }

    const response = await fetch(`${API_BASE_URL}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(init.body ? { "Content-Type": "application/json" } : {}),
        ...(init.headers || {}),
      },
      cache: "no-store",
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(getErrorMessage(data, `Request failed (${response.status})`));
    }
    return data as Record<string, unknown>;
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (submitting) return;
    setError("");

    if (!hasValidAuthSession()) {
      router.replace("/login");
      return;
    }

    if (!form.name.trim()) {
      setError("Project name is required.");
      return;
    }
    if (!form.industry_type.trim()) {
      setError("Please select an industry.");
      return;
    }

    const preparedCollaborators = collaboratorsLocked
      ? []
      : collaborators
          .map((item) => ({
            ...item,
            email: item.email.trim(),
            first_name: item.first_name.trim(),
            last_name: item.last_name.trim(),
          }))
          .filter((item) => item.email);

    if (preparedCollaborators.some((item) => !isValidEmail(item.email))) {
      setError("Please provide a valid email address for each collaborator.");
      return;
    }

    if (
      preparedCollaborators.some((item) => !item.first_name || !item.last_name)
    ) {
      setError("Collaborators require both first and last names.");
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        name: form.name.trim(),
        industry_type: form.industry_type.trim(),
        description: form.description.trim() || undefined,
      };
      const created = await requestWithAuth("/0.1.0/projects", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      const projectId = resolveProjectId(created);

      if (projectId && preparedCollaborators.length) {
        const results = await Promise.allSettled(
          preparedCollaborators.map((collaborator) =>
            requestWithAuth(`/0.1.0/projects/${encodeURIComponent(projectId)}/members`, {
              method: "POST",
              body: JSON.stringify({
                email: collaborator.email,
                role: "collaborator",
                first_name: collaborator.first_name,
                last_name: collaborator.last_name,
                allow_uploads: collaborator.allow_uploads,
                allow_connected_data: collaborator.allow_connected_data,
                allow_engine_queries: collaborator.allow_engine_queries,
                allow_scientific_analysis: collaborator.allow_scientific_analysis,
              }),
            }),
          ),
        );
        const hasFailures = results.some((result) => result.status === "rejected");
        if (hasFailures) {
          setError("Project created, but some collaborators could not be added.");
        }
      }

      router.push(projectId ? `/projects/${projectId}` : "/projects");
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : "Failed to create project.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="h-screen w-screen overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
      <section className="h-full w-full overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
        <div className="grid h-full md:grid-cols-[290px_1fr]">
          <div className="hidden md:block">{sidebar}</div>

          <div className="relative flex h-full flex-col overflow-y-auto px-3 py-3 md:px-5 md:py-4">
            <TopBar onOpenMenu={() => setDrawerOpen(true)} />

            <div className="mx-auto mt-3 w-full max-w-3xl space-y-6 sm:mt-0">
              <button
                type="button"
                onClick={() => router.push("/projects")}
                className="inline-flex items-center gap-2 text-sm font-medium text-[var(--electric-blue)] hover:underline"
              >
                ← Back to Projects
              </button>

              <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 shadow-sm">
                <header className="mb-6">
                  <h1 className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                    Create a new project
                  </h1>
                  <p className="mt-1 text-sm text-[var(--muted)]">
                    Group uploads, dashboards, and insights for a specific initiative.
                  </p>
                </header>

                {error ? (
                  <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700 dark:border-red-500/40 dark:bg-red-500/10 dark:text-red-200">
                    {error}
                  </div>
                ) : null}

                <form onSubmit={handleSubmit} className="space-y-5">
                  <div>
                    <label htmlFor="project-name" className="block text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      Project name
                    </label>
                    <input
                      id="project-name"
                      type="text"
                      value={form.name}
                      onChange={updateField("name")}
                      placeholder="Financial Metrics"
                      className="mt-1 w-full rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] shadow-sm focus:border-[var(--electric-blue)] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_24%,transparent)]"
                    />
                  </div>

                  <div>
                    <label htmlFor="project-industry" className="block text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      Industry
                    </label>
                    <select
                      id="project-industry"
                      value={form.industry_type}
                      onChange={updateField("industry_type")}
                      className="mt-1 w-full rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] shadow-sm focus:border-[var(--electric-blue)] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_24%,transparent)]"
                    >
                      <option value="">Select industry...</option>
                      {industryOptions.map((option) => (
                        <option key={option} value={option}>
                          {option}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label htmlFor="project-description" className="block text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      Description <span className="text-[var(--muted)]">(optional)</span>
                    </label>
                    <textarea
                      id="project-description"
                      rows={4}
                      value={form.description}
                      onChange={updateField("description")}
                      placeholder="Weekly KPIs and analyses for the executive team..."
                      className="mt-1 w-full rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] shadow-sm focus:border-[var(--electric-blue)] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_24%,transparent)]"
                    />
                  </div>

                  <div className="relative rounded-2xl border border-dashed border-[var(--border)] bg-[color-mix(in_oklab,var(--surface)_94%,#eef3f8)] p-4">
                    {collaboratorsLocked ? (
                      <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 rounded-2xl bg-[color-mix(in_oklab,var(--surface)_86%,white)] px-6 text-center backdrop-blur-sm">
                        <div>
                          <h3 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                            Collaborators are a paid feature
                          </h3>
                          <p className="mt-1 text-xs text-[var(--muted)]">
                            Upgrade to Basic (5 seats) or Premium (15 seats) to invite teammates.
                          </p>
                        </div>
                        <Link
                          href="/premium"
                          className="inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-xs font-semibold text-white hover:brightness-95"
                        >
                          Upgrade
                        </Link>
                      </div>
                    ) : null}

                    <div className={collaboratorsLocked ? "pointer-events-none select-none blur-sm opacity-70" : ""}>
                      <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                        <div>
                          <h2 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                            Add collaborators (optional)
                          </h2>
                          <p className="text-xs text-[var(--muted)]">
                            Collaborators receive access as soon as you save the project.
                          </p>
                          {collaboratorLimit > 0 ? (
                            <p className="text-xs text-[var(--muted)]">
                              Using {Math.min(collaborators.length, collaboratorLimit)} of {collaboratorLimit} collaborator seats.
                            </p>
                          ) : null}
                        </div>
                        <button
                          type="button"
                          onClick={addCollaboratorRow}
                          disabled={collaboratorInviteDisabled}
                          className={`inline-flex items-center gap-2 rounded-lg border border-[var(--border-strong)] bg-[var(--surface)] px-3 py-1.5 text-xs font-medium text-[var(--electric-blue)] ${
                            collaboratorInviteDisabled ? "cursor-not-allowed opacity-60" : "hover:bg-[var(--surface-subtle)]"
                          }`}
                        >
                          + Add collaborator
                        </button>
                      </div>

                      {collaboratorLimitReached ? (
                        <div className="mt-3 rounded-lg border border-[var(--border-strong)] bg-[color-mix(in_oklab,var(--electric-blue)_10%,white)] px-3 py-2 text-xs text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                          You&apos;ve used every collaborator seat included in your plan.
                        </div>
                      ) : null}

                      {collaborators.length ? (
                        <div className="mt-4 space-y-3">
                          {collaborators.map((collaborator, index) => (
                            <div
                              key={`collaborator_${index}`}
                              className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4 shadow-sm"
                            >
                              <div className="grid gap-3 md:grid-cols-2">
                                <div className="md:col-span-2">
                                  <label className="block text-xs font-medium uppercase tracking-wide text-[var(--muted)]" htmlFor={`collaborator-email-${index}`}>
                                    Email
                                  </label>
                                  <input
                                    id={`collaborator-email-${index}`}
                                    type="email"
                                    value={collaborator.email}
                                    onChange={updateCollaborator(index, "email")}
                                    placeholder="collab@example.com"
                                    className="mt-1 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] focus:border-[var(--electric-blue)] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_24%,transparent)]"
                                  />
                                </div>
                                <div>
                                  <label className="block text-xs font-medium uppercase tracking-wide text-[var(--muted)]" htmlFor={`collaborator-first-${index}`}>
                                    First name
                                  </label>
                                  <input
                                    id={`collaborator-first-${index}`}
                                    type="text"
                                    value={collaborator.first_name}
                                    onChange={updateCollaborator(index, "first_name")}
                                    placeholder="Jane"
                                    className="mt-1 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] focus:border-[var(--electric-blue)] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_24%,transparent)]"
                                  />
                                </div>
                                <div>
                                  <label className="block text-xs font-medium uppercase tracking-wide text-[var(--muted)]" htmlFor={`collaborator-last-${index}`}>
                                    Last name
                                  </label>
                                  <input
                                    id={`collaborator-last-${index}`}
                                    type="text"
                                    value={collaborator.last_name}
                                    onChange={updateCollaborator(index, "last_name")}
                                    placeholder="Doe"
                                    className="mt-1 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] focus:border-[var(--electric-blue)] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--electric-blue)_24%,transparent)]"
                                  />
                                </div>
                              </div>

                              <div className="mt-3 grid gap-2 text-xs text-[var(--muted)] md:grid-cols-2">
                                {MODULE_KEYS.map((moduleKey) => (
                                  <label key={moduleKey.key} className="inline-flex items-center gap-2">
                                    <input
                                      type="checkbox"
                                      checked={Boolean(collaborator[moduleKey.key])}
                                      onChange={toggleCollaboratorPermission(index, moduleKey.key)}
                                      className="rounded border-[var(--border)] text-[var(--electric-blue)] focus:ring-[var(--electric-blue)]"
                                    />
                                    {moduleKey.label}
                                  </label>
                                ))}
                              </div>

                              <div className="mt-3 flex justify-end">
                                <button
                                  type="button"
                                  onClick={() => removeCollaboratorRow(index)}
                                  className="inline-flex items-center gap-2 rounded-lg border border-red-200 px-3 py-1.5 text-xs font-medium text-red-600 hover:bg-red-50 dark:border-red-500/40 dark:text-red-300 dark:hover:bg-red-500/10"
                                >
                                  Remove
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <p className="mt-3 text-xs text-[var(--muted)]">
                          No collaborators added yet. Invite teammates to share uploads and analyses.
                        </p>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center justify-end gap-3">
                    <button
                      type="button"
                      onClick={() => router.push("/projects")}
                      className="rounded-lg border border-[var(--border)] px-4 py-2 text-sm font-medium text-[var(--muted)] hover:bg-[var(--surface-subtle)]"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={submitting}
                      className="inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {submitting ? "Saving..." : "Create project"}
                    </button>
                  </div>
                </form>
              </section>
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
