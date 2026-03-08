"use client";

import { API_BASE_URL } from "@/shared/api/auth";
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

const MODULE_KEYS = [
  { key: "uploads", label: "Uploads", allow: "allow_uploads" },
  { key: "connected_data", label: "Connected data", allow: "allow_connected_data" },
  { key: "engine_queries", label: "Engine queries", allow: "allow_engine_queries" },
  { key: "scientific_analysis", label: "Scientific analysis", allow: "allow_scientific_analysis" },
] as const;

type Member = Record<string, unknown>;
type ProjectDetail = Record<string, unknown>;

type NewMemberState = {
  email: string;
  first_name: string;
  last_name: string;
  allow_uploads: boolean;
  allow_connected_data: boolean;
  allow_engine_queries: boolean;
  allow_scientific_analysis: boolean;
};

const getComparable = (value: unknown): string => {
  if (value == null) return "";
  return String(value);
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

const formatBytes = (value: unknown): string => {
  const num = Number(value);
  if (!Number.isFinite(num)) return "—";
  if (num >= 1e9) return `${(num / 1e9).toFixed(1)} GB`;
  if (num >= 1e6) return `${(num / 1e6).toFixed(1)} MB`;
  if (num >= 1e3) return `${(num / 1e3).toFixed(1)} KB`;
  return `${num} B`;
};

const normalizePermissionFlags = (perms: Record<string, unknown> = {}) => ({
  uploads: Boolean(perms.uploads ?? perms.allow_uploads ?? perms.can_uploads ?? perms.can_upload),
  connected_data: Boolean(perms.connected_data ?? perms.allow_connected_data ?? perms.can_connected_data),
  engine_queries: Boolean(perms.engine_queries ?? perms.allow_engine_queries ?? perms.can_engine_queries),
  scientific_analysis: Boolean(
    perms.scientific_analysis ?? perms.allow_scientific_analysis ?? perms.can_scientific_analysis,
  ),
});

const memberHas = (
  member: Member,
  key: "uploads" | "connected_data" | "engine_queries" | "scientific_analysis",
) => {
  if (member.is_owner) return true;
  const perms = normalizePermissionFlags((member.permissions as Record<string, unknown>) || member);
  return Boolean(perms[key]);
};

const parseApiResponseBody = async (response: Response): Promise<Record<string, unknown>> => {
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return (await response.json().catch(() => ({}))) as Record<string, unknown>;
  }

  const text = await response.text().catch(() => "");
  if (!text) return {};
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return { detail: text };
  }
};

async function requestWithAuth(path: string, init: RequestInit = {}) {
  const token = getValidAccessToken();
  if (!token) throw new Error("Session expired. Please login again.");

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      Authorization: `Bearer ${token}`,
      ...(init.headers || {}),
    },
    cache: "no-store",
  });

  const data = await parseApiResponseBody(response);

  if (!response.ok) {
    const detail = (data as Record<string, unknown>).detail ?? (data as Record<string, unknown>).message;
    const err = new Error(typeof detail === "string" ? detail : `Request failed (${response.status})`) as Error & {
      status?: number;
    };
    err.status = response.status;
    throw err;
  }

  return data;
}

export function ProjectDetailScreen({ projectId }: { projectId: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);

  const [project, setProject] = useState<ProjectDetail | null>(null);
  const [projectForm, setProjectForm] = useState({ name: "", industry_type: "", description: "" });
  const [projectLoading, setProjectLoading] = useState(true);
  const [projectSaving, setProjectSaving] = useState(false);
  const [projectError, setProjectError] = useState("");
  const [currentRole, setCurrentRole] = useState("");

  const [members, setMembers] = useState<Member[]>([]);
  const [membersLoading, setMembersLoading] = useState(true);
  const [membersError, setMembersError] = useState("");
  const [memberSubmitting, setMemberSubmitting] = useState(false);
  const [memberActionError, setMemberActionError] = useState("");
  const [memberActionSuccess, setMemberActionSuccess] = useState("");
  const [inviteRetryPayload, setInviteRetryPayload] = useState<NewMemberState | null>(null);

  const [newMember, setNewMember] = useState<NewMemberState>({
    email: "",
    first_name: "",
    last_name: "",
    allow_uploads: false,
    allow_connected_data: false,
    allow_engine_queries: false,
    allow_scientific_analysis: false,
  });

  const canManageMembers = useMemo(() => currentRole === "owner", [currentRole]);
  const canEditProjectDetails = useMemo(() => currentRole === "owner", [currentRole]);

  const loadProject = useCallback(async () => {
    setProjectLoading(true);
    setProjectError("");
    try {
      const data = (await requestWithAuth(`/0.1.0/projects/${encodeURIComponent(projectId)}`)) as ProjectDetail;
      setProject(data);
      setProjectForm({
        name: String(data.name ?? ""),
        industry_type: String(data.industry_type ?? ""),
        description: String(data.description ?? ""),
      });
      setCurrentRole(String(data.current_role ?? ""));

      const embeddedMembers = Array.isArray(data.members) ? (data.members as Member[]) : [];
      if (embeddedMembers.length > 0) {
        setMembers(embeddedMembers);
        setMembersLoading(false);
      }
    } catch (error) {
      setProjectError(error instanceof Error ? error.message : "Failed to load project.");
    } finally {
      setProjectLoading(false);
    }
  }, [projectId]);

  const loadMembers = useCallback(async () => {
    if (!canManageMembers) {
      setMembersLoading(false);
      return;
    }

    setMembersLoading(true);
    setMembersError("");
    try {
      const data = await requestWithAuth(`/0.1.0/projects/${encodeURIComponent(projectId)}/members`);
      setMembers(Array.isArray(data) ? (data as Member[]) : []);
    } catch (error) {
      setMembersError(error instanceof Error ? error.message : "Failed to load members.");
    } finally {
      setMembersLoading(false);
    }
  }, [canManageMembers, projectId]);

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
    }
  }, [router]);

  useEffect(() => {
    void loadProject();
  }, [loadProject]);

  useEffect(() => {
    void loadMembers();
  }, [loadMembers]);

  const handleProjectField = (key: "name" | "industry_type" | "description", value: string) => {
    setProjectForm((prev) => ({ ...prev, [key]: value }));
  };

  const saveProjectDetails = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!canEditProjectDetails) return;

    setProjectSaving(true);
    setProjectError("");

    try {
      await requestWithAuth(`/0.1.0/projects/${encodeURIComponent(projectId)}`, {
        method: "PATCH",
        body: JSON.stringify({
          name: projectForm.name.trim(),
          industry_type: projectForm.industry_type.trim(),
          description: projectForm.description.trim(),
        }),
      });
      await loadProject();
      setMemberActionSuccess("Project details updated.");
      setTimeout(() => setMemberActionSuccess(""), 2500);
    } catch (error) {
      setProjectError(error instanceof Error ? error.message : "Failed to update project.");
    } finally {
      setProjectSaving(false);
    }
  };

  const updateMemberField = (key: keyof NewMemberState, value: string | boolean) => {
    setNewMember((prev) => ({ ...prev, [key]: value }));
  };

  const submitNewMember = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMemberSubmitting(true);
    setMemberActionError("");
    setMemberActionSuccess("");
    setInviteRetryPayload(null);

    try {
      const payload: NewMemberState = {
        ...newMember,
        email: newMember.email.trim(),
        first_name: newMember.first_name.trim(),
        last_name: newMember.last_name.trim(),
      };

      const email = payload.email;
      if (!email || !email.includes("@")) {
        throw new Error("Enter a valid collaborator email.");
      }

      const token = getValidAccessToken();
      if (!token) {
        clearAuthSession();
        router.replace("/login");
        return;
      }

      const fullPayload = {
        email,
        first_name: payload.first_name,
        last_name: payload.last_name,
        role: "collaborator",
        allow_uploads: payload.allow_uploads,
        allow_connected_data: payload.allow_connected_data,
        allow_engine_queries: payload.allow_engine_queries,
        allow_scientific_analysis: payload.allow_scientific_analysis,
      };

      const response = await fetch(
        `${API_BASE_URL}/0.1.0/projects/${encodeURIComponent(projectId)}/members`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(fullPayload),
        },
      );
      const data = await parseApiResponseBody(response);
      const detail =
        typeof data.detail === "string"
          ? data.detail
          : typeof data.message === "string"
            ? data.message
            : "";

      if (response.status === 201) {
        setNewMember({
          email: "",
          first_name: "",
          last_name: "",
          allow_uploads: false,
          allow_connected_data: false,
          allow_engine_queries: false,
          allow_scientific_analysis: false,
        });
        // Treat 201 as success even if notification/email is delayed.
        setMemberActionSuccess("Invitation sent.");
        await loadMembers();
        return;
      }

      if (response.status === 400) {
        setMemberActionError(detail || "Missing required fields for new account.");
        return;
      }
      if (response.status === 403) {
        setMemberActionError(detail || "Plan limit reached. Upgrade required.");
        return;
      }
      if (response.status === 409) {
        setMemberActionError(detail || "User already collaborator.");
        return;
      }
      if (response.status === 500) {
        setMemberActionError(
          "Unexpected server error. Please retry. If this persists, contact support.",
        );
        setInviteRetryPayload(payload);
        return;
      }

      setMemberActionError(detail || `Invite failed (status ${response.status}).`);
    } catch (error) {
      setMemberActionError(error instanceof Error ? error.message : "Failed to invite collaborator.");
    } finally {
      setMemberSubmitting(false);
    }
  };

  const retryInvite = async () => {
    if (!inviteRetryPayload || memberSubmitting) return;
    setNewMember(inviteRetryPayload);
    const syntheticEvent = { preventDefault: () => {} } as React.FormEvent<HTMLFormElement>;
    await submitNewMember(syntheticEvent);
  };

  const updateMember = async (memberId: string, changes: Record<string, unknown>) => {
    if (!canManageMembers) return;
    setMemberActionError("");
    setMemberActionSuccess("");

    const rolePayload = "role" in changes ? { role: changes.role } : null;
    const modulePayload: Record<string, unknown> = {};

    for (const mod of MODULE_KEYS) {
      if (Object.prototype.hasOwnProperty.call(changes, mod.key)) {
        modulePayload[mod.allow] = Boolean(changes[mod.key]);
      }
    }

    try {
      if (rolePayload) {
        await requestWithAuth(
          `/0.1.0/projects/${encodeURIComponent(projectId)}/members/${encodeURIComponent(memberId)}`,
          {
            method: "PATCH",
            body: JSON.stringify(rolePayload),
          },
        );
      }

      if (Object.keys(modulePayload).length > 0) {
        await requestWithAuth(
          `/0.1.0/projects/${encodeURIComponent(projectId)}/members/${encodeURIComponent(memberId)}/modules`,
          {
            method: "PATCH",
            body: JSON.stringify(modulePayload),
          },
        );
      }

      setMemberActionSuccess("Collaborator updated.");
      await loadMembers();
    } catch (error) {
      setMemberActionError(error instanceof Error ? error.message : "Unable to update collaborator.");
    }
  };

  const removeMember = async (memberId: string) => {
    if (!canManageMembers) return;
    const ok = window.confirm("Remove this member? They will immediately lose access.");
    if (!ok) return;

    setMemberActionError("");
    setMemberActionSuccess("");
    try {
      await requestWithAuth(
        `/0.1.0/projects/${encodeURIComponent(projectId)}/members/${encodeURIComponent(memberId)}`,
        { method: "DELETE" },
      );
      setMemberActionSuccess("Collaborator removed.");
      await loadMembers();
    } catch (error) {
      setMemberActionError(error instanceof Error ? error.message : "Unable to remove collaborator.");
    }
  };

  const linkedUploads = Array.isArray(project?.uploads) ? (project?.uploads as Record<string, unknown>[]) : [];
  const linkedQueries = Array.isArray(project?.engine_queries)
    ? (project?.engine_queries as Record<string, unknown>[])
    : [];
  const linkedSources = Array.isArray(project?.connected_sources)
    ? (project?.connected_sources as Record<string, unknown>[])
    : [];

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

            <div className="mt-3 space-y-6 md:mt-0">
              <button
                type="button"
                onClick={() => router.push("/projects")}
                className="inline-flex items-center gap-2 text-sm font-medium text-[var(--electric-blue)] hover:underline"
              >
                ← Back to Projects
              </button>

              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h1 className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                    {String(project?.name ?? "Project")}
                  </h1>
                  {project?.industry_type ? (
                    <p className="text-sm text-[var(--muted)]">
                      {String(project.industry_type)} • Created {formatDateTime(project?.created_at)}
                    </p>
                  ) : null}
                  {currentRole ? (
                    <p className="text-xs uppercase tracking-wide text-[var(--electric-blue)]">
                      Your role: {currentRole}
                    </p>
                  ) : null}
                </div>
                <button
                  type="button"
                  onClick={() => {
                    void loadProject();
                    void loadMembers();
                  }}
                  className="inline-flex items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-medium text-[var(--muted)] hover:bg-[var(--surface-subtle)]"
                >
                  ↻ Refresh
                </button>
              </div>

              <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
                <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5">
                  <header className="mb-4">
                    <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      Project details
                    </h2>
                    <p className="text-sm text-[var(--muted)]">
                      {canEditProjectDetails
                        ? "Update the basics visible to all collaborators."
                        : "You do not have permission to edit this project."}
                    </p>
                  </header>

                  {projectError ? (
                    <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                      {projectError}
                    </div>
                  ) : null}

                  <form onSubmit={saveProjectDetails} className="grid gap-4 md:grid-cols-2">
                    <div className="md:col-span-2">
                      <label className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                        Project name
                      </label>
                      <input
                        type="text"
                        value={projectForm.name}
                        onChange={(event) => handleProjectField("name", event.target.value)}
                        disabled={projectLoading || !canEditProjectDetails}
                        className="mt-1 w-full rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)] disabled:cursor-not-allowed disabled:opacity-60"
                      />
                    </div>

                    <div>
                      <label className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                        Industry
                      </label>
                      <input
                        type="text"
                        value={projectForm.industry_type}
                        onChange={(event) => handleProjectField("industry_type", event.target.value)}
                        disabled={projectLoading || !canEditProjectDetails}
                        className="mt-1 w-full rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)] disabled:cursor-not-allowed disabled:opacity-60"
                      />
                    </div>

                    <div className="md:col-span-2">
                      <label className="text-sm font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                        Description
                      </label>
                      <textarea
                        rows={3}
                        value={projectForm.description}
                        onChange={(event) => handleProjectField("description", event.target.value)}
                        disabled={projectLoading || !canEditProjectDetails}
                        className="mt-1 w-full rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)] disabled:cursor-not-allowed disabled:opacity-60"
                      />
                    </div>

                    <div className="md:col-span-2 flex justify-end">
                      <button
                        type="submit"
                        disabled={projectLoading || projectSaving || !canEditProjectDetails}
                        className="inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        {projectSaving ? "Saving..." : "Save changes"}
                      </button>
                    </div>
                  </form>
                </section>

                <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5">
                  <header className="mb-4">
                    <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      File uploads
                    </h2>
                    <p className="text-sm text-[var(--muted)]">Linked files available for this project.</p>
                  </header>

                  {linkedUploads.length ? (
                    <div className="space-y-3">
                      {linkedUploads.map((upload, index) => {
                        const uploadId = String(upload.upload_id ?? upload.id ?? "");
                        return (
                          <div key={`${uploadId}-${index}`} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3">
                            <div className="flex items-start justify-between gap-2">
                              <div className="min-w-0">
                                <p className="truncate text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                                  {String(upload.original_name ?? upload.name ?? "Untitled upload")}
                                </p>
                                <p className="text-xs text-[var(--muted)]">
                                  {formatDateTime(upload.created_at)} • {formatBytes(upload.size_bytes)}
                                </p>
                              </div>
                              <span className="text-[11px] font-semibold uppercase text-[var(--muted)]">
                                {String(upload.ext ?? "").replace(/^\./, "")}
                              </span>
                            </div>
                            {uploadId ? (
                              <div className="mt-2 flex justify-end">
                                <button
                                  type="button"
                                  onClick={() => router.push(`/files/${encodeURIComponent(uploadId)}`)}
                                  className="text-xs font-medium text-[var(--electric-blue)] hover:underline"
                                >
                                  Open file
                                </button>
                              </div>
                            ) : null}
                          </div>
                        );
                      })}
                    </div>
                  ) : (
                    <p className="text-sm text-[var(--muted)]">No uploads linked yet.</p>
                  )}
                </section>
              </div>

              <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5">
                <header className="mb-4">
                  <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                    Collaborators
                  </h2>
                  <p className="text-sm text-[var(--muted)]">
                    {canManageMembers
                      ? "Invite teammates and manage their permissions."
                      : "You can view collaborators but not manage access."}
                  </p>
                </header>

                {membersError ? (
                  <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                    {membersError}
                  </div>
                ) : null}
                {memberActionError ? (
                  <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                    {memberActionError}
                    {inviteRetryPayload ? (
                      <button
                        type="button"
                        onClick={() => void retryInvite()}
                        className="ml-2 inline-flex rounded border border-red-300 bg-white px-2 py-0.5 text-xs font-medium text-red-700 hover:bg-red-100"
                      >
                        Retry
                      </button>
                    ) : null}
                  </div>
                ) : null}
                {memberActionSuccess ? (
                  <div className="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
                    {memberActionSuccess}
                  </div>
                ) : null}

                {canManageMembers ? (
                  <form onSubmit={submitNewMember} className="grid gap-3 rounded-xl border border-dashed border-[var(--border-strong)] bg-[color-mix(in_oklab,var(--surface)_80%,white)] p-4 md:grid-cols-5">
                    <div className="md:col-span-2">
                      <label className="text-xs font-medium uppercase tracking-wide text-[var(--muted)]">Email</label>
                      <input
                        type="email"
                        value={newMember.email}
                        onChange={(event) => updateMemberField("email", event.target.value)}
                        placeholder="collab@example.com"
                        className="mt-1 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)]"
                      />
                    </div>
                    <div>
                      <label className="text-xs font-medium uppercase tracking-wide text-[var(--muted)]">First name</label>
                      <input
                        type="text"
                        value={newMember.first_name}
                        onChange={(event) => updateMemberField("first_name", event.target.value)}
                        className="mt-1 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)]"
                      />
                    </div>
                    <div>
                      <label className="text-xs font-medium uppercase tracking-wide text-[var(--muted)]">Last name</label>
                      <input
                        type="text"
                        value={newMember.last_name}
                        onChange={(event) => updateMemberField("last_name", event.target.value)}
                        className="mt-1 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)]"
                      />
                    </div>
                    <div className="md:col-span-5 grid gap-2 rounded-lg bg-[var(--surface)] p-3 text-xs text-[var(--muted)] md:grid-cols-3">
                      <label className="inline-flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={newMember.allow_uploads}
                          onChange={(event) => updateMemberField("allow_uploads", event.target.checked)}
                        />
                        Allow uploads
                      </label>
                      <label className="inline-flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={newMember.allow_connected_data}
                          onChange={(event) => updateMemberField("allow_connected_data", event.target.checked)}
                        />
                        Connected data
                      </label>
                      <label className="inline-flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={newMember.allow_engine_queries}
                          onChange={(event) => updateMemberField("allow_engine_queries", event.target.checked)}
                        />
                        Engine queries
                      </label>
                      <label className="inline-flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={newMember.allow_scientific_analysis}
                          onChange={(event) =>
                            updateMemberField("allow_scientific_analysis", event.target.checked)
                          }
                        />
                        Scientific analysis
                      </label>
                    </div>

                    <div className="md:col-span-5 flex justify-end">
                      <button
                        type="submit"
                        disabled={memberSubmitting}
                        className="inline-flex items-center gap-2 rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
                      >
                        {memberSubmitting ? "Inviting..." : "Invite collaborator"}
                      </button>
                    </div>
                  </form>
                ) : null}

                {membersLoading ? (
                  <p className="mt-4 text-sm text-[var(--muted)]">Loading collaborators...</p>
                ) : members.length ? (
                  <div className="mt-6 space-y-3">
                    {members.map((member, index) => {
                      const memberId = getComparable(member.user_id ?? member.id ?? member.member_id);
                      const isOwner = Boolean(member.is_owner);
                      const roleValue = isOwner ? "owner" : "collaborator";

                      return (
                        <div key={`${memberId}-${index}`} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4">
                          <div className="flex flex-col items-start justify-between gap-3 md:flex-row md:items-center">
                            <div>
                              <p className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                                {String(member.first_name ?? "")} {String(member.last_name ?? "")}
                                {isOwner ? (
                                  <span className="ml-2 rounded-full bg-[color-mix(in_oklab,var(--electric-blue)_14%,white)] px-2 py-0.5 text-[10px] uppercase text-[var(--electric-blue)]">
                                    Owner
                                  </span>
                                ) : null}
                              </p>
                              <p className="text-xs text-[var(--muted)]">{String(member.email ?? "")}</p>
                            </div>

                            {canManageMembers ? (
                              <div className="flex items-center gap-2">
                                <select
                                  value={roleValue}
                                  onChange={(event) => {
                                    if (!memberId) return;
                                    void updateMember(memberId, { role: event.target.value });
                                  }}
                                  className="rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)]"
                                >
                                  <option value="owner">Owner</option>
                                  <option value="collaborator">Collaborator</option>
                                </select>
                                <button
                                  type="button"
                                  onClick={() => {
                                    if (!memberId) return;
                                    void removeMember(memberId);
                                  }}
                                  className="rounded-lg border border-red-200 px-3 py-2 text-sm text-red-600"
                                >
                                  Remove
                                </button>
                              </div>
                            ) : null}
                          </div>

                          <div className="mt-3 grid gap-3 md:grid-cols-2">
                            <div className="rounded-lg border border-[var(--border)] p-3">
                              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">Available modules</p>
                              <div className="space-y-2 text-xs text-[var(--muted)]">
                                {MODULE_KEYS.filter((m) => !memberHas(member, m.key)).map((m) => (
                                  <label key={m.key} className="flex items-center gap-2">
                                    <input
                                      type="checkbox"
                                      onChange={(event) => {
                                        if (!memberId) return;
                                        void updateMember(memberId, { [m.key]: event.target.checked });
                                      }}
                                      disabled={!canManageMembers || isOwner}
                                    />
                                    {m.label}
                                  </label>
                                ))}
                              </div>
                            </div>

                            <div className="rounded-lg border border-[var(--border)] p-3">
                              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">Granted modules</p>
                              <div className="flex flex-wrap gap-2">
                                {MODULE_KEYS.filter((m) => memberHas(member, m.key)).map((m) => (
                                  <span key={m.key} className="inline-flex items-center gap-2 rounded-full border border-[var(--electric-blue)]/30 px-2 py-1 text-[11px] text-[var(--electric-blue)]">
                                    {m.label}
                                    <button
                                      type="button"
                                      onClick={() => {
                                        if (!memberId) return;
                                        void updateMember(memberId, { [m.key]: false });
                                      }}
                                      disabled={!canManageMembers || isOwner}
                                      className="rounded px-1"
                                    >
                                      ×
                                    </button>
                                  </span>
                                ))}
                              </div>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <p className="mt-4 text-sm text-[var(--muted)]">No collaborators found.</p>
                )}
              </section>

              <section className="grid gap-4 md:grid-cols-2">
                <ProjectResourceCard title="Engine queries" items={linkedQueries} emptyMessage="No engine activity yet." countOnly />
                <ProjectResourceCard title="Connected sources" items={linkedSources} emptyMessage="No data sources connected." />
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
                <div className="relative z-10 h-full w-[74%] max-w-[290px]">{sidebar}</div>
              </div>
            ) : null}
          </div>
        </div>
      </section>
    </main>
  );
}

function ProjectResourceCard({
  title,
  items,
  emptyMessage,
  countOnly = false,
}: {
  title: string;
  items: Record<string, unknown>[];
  emptyMessage: string;
  countOnly?: boolean;
}) {
  const list = Array.isArray(items) ? items : [];
  const count = list.length;

  return (
    <div className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">{title}</h3>
        {countOnly ? (
          <span className="inline-flex items-center rounded-full border border-[var(--border)] px-2 py-0.5 text-xs text-[var(--muted)]">{count}</span>
        ) : null}
      </div>

      {countOnly ? (
        <p className="mt-3 text-xs text-[var(--muted)]">{count ? `${count} total` : emptyMessage}</p>
      ) : list.length ? (
        <ul className="mt-3 space-y-2 text-sm text-[var(--muted)]">
          {list.slice(0, 5).map((item, index) => (
            <li key={`${String(item.id ?? item.name ?? index)}`} className="truncate">
              {String(item.name ?? item.title ?? item.original_name ?? "(no title)")}
            </li>
          ))}
          {list.length > 5 ? (
            <li className="text-xs text-[var(--muted)]">+{list.length - 5} more</li>
          ) : null}
        </ul>
      ) : (
        <p className="mt-3 text-xs text-[var(--muted)]">{emptyMessage}</p>
      )}
    </div>
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
