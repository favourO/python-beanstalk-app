"use client";

import { settingsApi } from "@/shared/api/settings";
import { clearAuthSession, getValidAccessToken, hasValidAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { type FormEvent, useEffect, useMemo, useState } from "react";

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

const defaultProfile = {
  first_name: "",
  last_name: "",
  email: "",
  country: "",
  company: "",
  job_title: "",
};

const defaultPreferences = {
  theme: "system",
  time_zone: "UTC",
  default_workspace_view: "projects",
  email_reports: true,
  product_updates: true,
  default_project_id: "",
};

const defaultFeedback = {
  subject: "",
  category: "general",
  message: "",
};

const feedbackCategories = [
  { value: "general", label: "General" },
  { value: "bug", label: "Bug report" },
  { value: "feature", label: "Feature request" },
  { value: "billing", label: "Billing" },
];

const readStoredUser = (): Record<string, unknown> | null => {
  if (typeof window === "undefined") return null;
  const sources = [window.localStorage, window.sessionStorage];
  for (const storage of sources) {
    try {
      const raw = storage.getItem("user");
      if (!raw) continue;
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object") return parsed as Record<string, unknown>;
    } catch {
      // ignore malformed data
    }
  }
  return null;
};

const syncStoredUser = (patch: Record<string, unknown>) => {
  if (typeof window === "undefined") return;
  const sources = [window.localStorage, window.sessionStorage];
  for (const storage of sources) {
    try {
      const raw = storage.getItem("user");
      if (!raw) continue;
      const current = JSON.parse(raw);
      if (!current || typeof current !== "object") continue;
      storage.setItem("user", JSON.stringify({ ...(current as Record<string, unknown>), ...patch }));
    } catch {
      // ignore malformed data
    }
  }
};

export function SettingsScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);

  const [profile, setProfile] = useState(defaultProfile);
  const [profileLoading, setProfileLoading] = useState(true);
  const [profileSaving, setProfileSaving] = useState(false);

  const [preferences, setPreferences] = useState(defaultPreferences);
  const [options, setOptions] = useState({ themes: [], time_zones: [], workspace_views: [] } as {
    themes: string[];
    time_zones: string[];
    workspace_views: string[];
  });
  const [preferencesLoading, setPreferencesLoading] = useState(true);
  const [preferencesSaving, setPreferencesSaving] = useState(false);

  const [feedbackForm, setFeedbackForm] = useState(defaultFeedback);
  const [feedbackSubmitting, setFeedbackSubmitting] = useState(false);

  const [deleteConfirm, setDeleteConfirm] = useState("");
  const [deleteLoading, setDeleteLoading] = useState(false);

  const [statusError, setStatusError] = useState("");
  const [statusSuccess, setStatusSuccess] = useState("");

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
      return;
    }

    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    let active = true;

    const loadProfile = async () => {
      setProfileLoading(true);
      try {
        const data = (await settingsApi.getProfile(token)) as Record<string, unknown>;
        if (!active) return;
        setProfile({
          ...defaultProfile,
          first_name: String(data.first_name ?? ""),
          last_name: String(data.last_name ?? ""),
          email: String(data.email ?? readStoredUser()?.email ?? ""),
          country: String(data.country ?? ""),
          company: String(data.company ?? ""),
          job_title: String(data.job_title ?? ""),
        });
      } catch (error) {
        if (!active) return;
        setStatusError(error instanceof Error ? error.message : "Unable to load profile settings.");
      } finally {
        if (active) setProfileLoading(false);
      }
    };

    const loadPreferences = async () => {
      setPreferencesLoading(true);
      try {
        const data = (await settingsApi.getPreferences(token)) as Record<string, unknown>;
        if (!active) return;

        const prefsRaw = (data.preferences as Record<string, unknown>) || data;
        const optsRaw = (data.options as Record<string, unknown>) || {};

        setPreferences({
          ...defaultPreferences,
          theme: String(prefsRaw.theme ?? defaultPreferences.theme),
          time_zone: String(prefsRaw.time_zone ?? defaultPreferences.time_zone),
          default_workspace_view: String(
            prefsRaw.default_workspace_view ?? defaultPreferences.default_workspace_view,
          ),
          email_reports:
            typeof prefsRaw.email_reports === "boolean"
              ? prefsRaw.email_reports
              : defaultPreferences.email_reports,
          product_updates:
            typeof prefsRaw.product_updates === "boolean"
              ? prefsRaw.product_updates
              : defaultPreferences.product_updates,
          default_project_id: String(prefsRaw.default_project_id ?? ""),
        });

        setOptions({
          themes: Array.isArray(optsRaw.themes)
            ? (optsRaw.themes as unknown[]).map((v) => String(v))
            : ["light", "dark", "system"],
          time_zones: Array.isArray(optsRaw.time_zones)
            ? (optsRaw.time_zones as unknown[]).map((v) => String(v))
            : ["UTC"],
          workspace_views: Array.isArray(optsRaw.workspace_views)
            ? (optsRaw.workspace_views as unknown[]).map((v) => String(v))
            : ["projects"],
        });
      } catch (error) {
        if (!active) return;
        setStatusError(error instanceof Error ? error.message : "Unable to load preferences.");
      } finally {
        if (active) setPreferencesLoading(false);
      }
    };

    void loadProfile();
    void loadPreferences();

    return () => {
      active = false;
    };
  }, [router]);

  const canSubmitDeletion = deleteConfirm.trim().toLowerCase() === "delete";
  const canSubmitFeedback =
    feedbackForm.subject.trim().length >= 3 && feedbackForm.message.trim().length >= 10;

  const onProfileSave = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    setProfileSaving(true);
    setStatusError("");
    setStatusSuccess("");

    try {
      await settingsApi.updateProfile(token, {
        first_name: profile.first_name.trim() || null,
        last_name: profile.last_name.trim() || null,
        country: profile.country.trim() || null,
        company: profile.company.trim() || null,
        job_title: profile.job_title.trim() || null,
      });
      syncStoredUser({
        first_name: profile.first_name.trim(),
        last_name: profile.last_name.trim(),
        country: profile.country.trim(),
        company: profile.company.trim(),
        job_title: profile.job_title.trim(),
      });
      setStatusSuccess("Profile updated.");
    } catch (error) {
      setStatusError(error instanceof Error ? error.message : "Unable to update profile.");
    } finally {
      setProfileSaving(false);
    }
  };

  const onPreferencesSave = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    setPreferencesSaving(true);
    setStatusError("");
    setStatusSuccess("");

    try {
      await settingsApi.updatePreferences(token, {
        theme: preferences.theme,
        time_zone: preferences.time_zone,
        default_workspace_view: preferences.default_workspace_view,
        email_reports: preferences.email_reports,
        product_updates: preferences.product_updates,
        default_project_id: preferences.default_project_id.trim() || null,
      });
      setStatusSuccess("Preferences saved.");
    } catch (error) {
      setStatusError(error instanceof Error ? error.message : "Unable to update preferences.");
    } finally {
      setPreferencesSaving(false);
    }
  };

  const onFeedbackSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!canSubmitFeedback || feedbackSubmitting) return;

    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    setFeedbackSubmitting(true);
    setStatusError("");
    setStatusSuccess("");

    try {
      await settingsApi.createFeedback(token, {
        subject: feedbackForm.subject.trim(),
        category: feedbackForm.category,
        message: feedbackForm.message.trim(),
      });
      setFeedbackForm(defaultFeedback);
      setStatusSuccess("Thanks! Your feedback was sent to the Demy team.");
    } catch (error) {
      setStatusError(error instanceof Error ? error.message : "Unable to send feedback.");
    } finally {
      setFeedbackSubmitting(false);
    }
  };

  const onAccountDelete = async () => {
    if (!canSubmitDeletion) return;

    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return;
    }

    setDeleteLoading(true);
    setStatusError("");
    setStatusSuccess("");

    try {
      await settingsApi.deleteAccount(token);
      clearAuthSession();
      router.replace("/login");
    } catch (error) {
      setStatusError(error instanceof Error ? error.message : "Unable to delete account.");
    } finally {
      setDeleteLoading(false);
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
              className={`flex items-center gap-2 rounded-md px-2 py-1.5 text-[13px] ${
                pathname === item.href
                  ? "bg-[var(--surface)] text-[var(--electric-blue)]"
                  : "text-[var(--muted)] hover:bg-[var(--surface)]"
              }`}
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

            <div className="mx-auto w-full max-w-5xl space-y-8 pb-8 pt-3 md:pt-0">
              <header>
                <h1 className="text-2xl font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Account settings
                </h1>
                <p className="mt-1 text-sm text-[var(--muted)]">
                  Manage your profile, preferences, and account lifecycle options.
                </p>
                <div className="mt-3">
                  <Link
                    href="/billing/manage"
                    className="inline-flex rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-medium text-[var(--electric-blue)] hover:bg-[var(--surface-subtle)]"
                  >
                    Manage subscription
                  </Link>
                </div>
              </header>

              {statusError ? (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {statusError}
                </div>
              ) : null}
              {statusSuccess ? (
                <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
                  {statusSuccess}
                </div>
              ) : null}

              <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 shadow-sm">
                <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Profile
                </h2>
                <p className="mt-1 text-sm text-[var(--muted)]">
                  Update the details your teammates see when collaborating with you.
                </p>

                <form onSubmit={onProfileSave} className="mt-4 grid gap-4 sm:grid-cols-2">
                    <FormInput
                      label="First name"
                      value={profile.first_name}
                      onChange={(value) => setProfile((prev) => ({ ...prev, first_name: value }))}
                      disabled={profileLoading || profileSaving}
                    />
                    <FormInput
                      label="Last name"
                      value={profile.last_name}
                      onChange={(value) => setProfile((prev) => ({ ...prev, last_name: value }))}
                      disabled={profileLoading || profileSaving}
                    />
                  <FormInput
                    label="Email"
                    value={profile.email}
                    type="email"
                    disabled
                    className="sm:col-span-2"
                  />
                    <FormInput
                      label="Country"
                      value={profile.country}
                      onChange={(value) => setProfile((prev) => ({ ...prev, country: value }))}
                      disabled={profileLoading || profileSaving}
                    />
                    <FormInput
                      label="Company"
                      value={profile.company}
                      onChange={(value) => setProfile((prev) => ({ ...prev, company: value }))}
                      disabled={profileLoading || profileSaving}
                    />
                    <FormInput
                      label="Job title"
                      value={profile.job_title}
                      onChange={(value) => setProfile((prev) => ({ ...prev, job_title: value }))}
                      className="sm:col-span-2"
                      disabled={profileLoading || profileSaving}
                    />

                  <div className="sm:col-span-2 flex justify-end pt-2">
                    <button
                      type="submit"
                      disabled={profileSaving || profileLoading}
                      className="inline-flex items-center rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {profileSaving ? "Saving..." : "Save profile"}
                    </button>
                  </div>
                </form>
              </section>

              <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 shadow-sm">
                <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Preferences
                </h2>
                <p className="mt-1 text-sm text-[var(--muted)]">
                  Tune how Demy behaves by default. These settings apply across devices.
                </p>

                <form onSubmit={onPreferencesSave} className="mt-4 grid gap-4 sm:grid-cols-2">
                  <FormSelect
                    label="Theme"
                    value={preferences.theme}
                    onChange={(value) => setPreferences((prev) => ({ ...prev, theme: value }))}
                    disabled={preferencesLoading || preferencesSaving}
                    options={(options.themes.length ? options.themes : ["light", "dark", "system"]).map((theme) => ({
                      value: theme,
                      label: theme.charAt(0).toUpperCase() + theme.slice(1),
                    }))}
                  />

                  <FormSelect
                    label="Time zone"
                    value={preferences.time_zone}
                    onChange={(value) => setPreferences((prev) => ({ ...prev, time_zone: value }))}
                    disabled={preferencesLoading || preferencesSaving}
                    options={(options.time_zones.length ? options.time_zones : ["UTC"]).map((tz) => ({
                      value: tz,
                      label: tz,
                    }))}
                  />

                  <FormSelect
                    label="Default workspace view"
                    value={preferences.default_workspace_view}
                    onChange={(value) => setPreferences((prev) => ({ ...prev, default_workspace_view: value }))}
                    disabled={preferencesLoading || preferencesSaving}
                    options={
                      (options.workspace_views.length ? options.workspace_views : ["projects"]).map((view) => ({
                        value: view,
                        label: view.charAt(0).toUpperCase() + view.slice(1),
                      }))
                    }
                  />

                  <FormInput
                    label="Default project ID (optional)"
                    value={preferences.default_project_id}
                    onChange={(value) => setPreferences((prev) => ({ ...prev, default_project_id: value }))}
                    className="sm:col-span-2"
                    disabled={preferencesLoading || preferencesSaving}
                  />

                  <Toggle
                    label="Email scheduled reports"
                    checked={preferences.email_reports}
                    onChange={(checked) => setPreferences((prev) => ({ ...prev, email_reports: checked }))}
                    disabled={preferencesLoading || preferencesSaving}
                  />
                  <Toggle
                    label="Product updates"
                    checked={preferences.product_updates}
                    onChange={(checked) => setPreferences((prev) => ({ ...prev, product_updates: checked }))}
                    disabled={preferencesLoading || preferencesSaving}
                  />

                  <div className="sm:col-span-2 flex justify-end pt-2">
                    <button
                      type="submit"
                      disabled={preferencesSaving || preferencesLoading}
                      className="inline-flex items-center rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {preferencesSaving ? "Saving..." : "Save preferences"}
                    </button>
                  </div>
                </form>
              </section>

              <section className="rounded-2xl border border-indigo-100 bg-[var(--surface)] p-6 shadow-sm dark:border-indigo-500/40">
                <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                  Share feedback
                </h2>
                <p className="mt-1 text-sm text-[var(--muted)]">
                  Tell us what is working well and which workflows you would like us to build next.
                </p>

                <form onSubmit={onFeedbackSubmit} className="mt-4 space-y-4">
                  <div className="grid gap-4 sm:grid-cols-2">
                    <FormInput
                      label="Subject"
                      value={feedbackForm.subject}
                      onChange={(value) => setFeedbackForm((prev) => ({ ...prev, subject: value }))}
                      placeholder="Summarize your idea"
                      disabled={feedbackSubmitting}
                    />

                    <FormSelect
                      label="Category"
                      value={feedbackForm.category}
                      onChange={(value) => setFeedbackForm((prev) => ({ ...prev, category: value }))}
                      disabled={feedbackSubmitting}
                      options={feedbackCategories}
                    />
                  </div>

                  <label className="flex flex-col text-sm">
                    <span className="font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">Message</span>
                    <textarea
                      rows={5}
                      value={feedbackForm.message}
                      onChange={(event) =>
                        setFeedbackForm((prev) => ({ ...prev, message: event.target.value }))
                      }
                      placeholder="Share as much detail as possible so we can reproduce issues or scope the request."
                      className="mt-1 rounded-lg border border-[var(--border)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)]"
                      disabled={feedbackSubmitting}
                    />
                    <span className="mt-1 text-xs text-[var(--muted)]">Minimum 10 characters.</span>
                  </label>

                  <div className="flex justify-end">
                    <button
                      type="submit"
                      disabled={!canSubmitFeedback || feedbackSubmitting}
                      className="inline-flex items-center rounded-lg bg-[var(--electric-blue)] px-4 py-2 text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {feedbackSubmitting ? "Sending..." : "Send feedback"}
                    </button>
                  </div>
                </form>
              </section>

              <section className="rounded-2xl border border-red-200 bg-[var(--surface)] p-6 shadow-sm dark:border-red-500/40">
                <h2 className="text-lg font-semibold text-red-600 dark:text-red-400">Danger zone</h2>
                <p className="mt-1 text-sm text-red-600/80 dark:text-red-300">
                  Deleting your account removes your personal data and shared assets. This action cannot be undone.
                </p>

                <div className="mt-4 grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto]">
                  <input
                    type="text"
                    placeholder="Type DELETE to confirm"
                    value={deleteConfirm}
                    onChange={(event) => setDeleteConfirm(event.target.value)}
                    className="rounded-lg border border-red-200 px-3 py-2 text-sm text-red-700 outline-none focus:border-red-500"
                  />

                  <button
                    type="button"
                    onClick={onAccountDelete}
                    disabled={!canSubmitDeletion || deleteLoading}
                    className="inline-flex items-center justify-center rounded-lg border border-red-500 px-4 py-2 text-sm font-semibold text-red-600 transition hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {deleteLoading ? "Deleting..." : "Delete account"}
                  </button>
                </div>
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

function FormInput({
  label,
  value,
  onChange,
  placeholder,
  disabled,
  type = "text",
  className,
}: {
  label: string;
  value: string;
  onChange?: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
  type?: string;
  className?: string;
}) {
  return (
    <label className={`flex flex-col text-sm ${className ?? ""}`}>
      <span className="font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(event) => onChange?.(event.target.value)}
        placeholder={placeholder}
        disabled={disabled}
        className="mt-1 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)] disabled:cursor-not-allowed disabled:opacity-60"
      />
    </label>
  );
}

function FormSelect({
  label,
  value,
  onChange,
  options,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  disabled?: boolean;
}) {
  return (
    <label className="flex flex-col text-sm">
      <span className="font-medium text-[var(--deep-navy)] dark:text-[var(--foreground)]">{label}</span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        disabled={disabled}
        className="mt-1 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--electric-blue)]"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function Toggle({
  label,
  checked,
  onChange,
  disabled,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <label className="flex items-center gap-2 text-sm text-[var(--deep-navy)] dark:text-[var(--foreground)]">
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
        disabled={disabled}
        className="rounded border-[var(--border)] disabled:cursor-not-allowed disabled:opacity-60"
      />
      {label}
    </label>
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
