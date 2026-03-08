"use client";

import { notificationsApi, type NotificationRead } from "@/shared/api/notifications";
import { clearAuthSession, getValidAccessToken } from "@/shared/auth/session";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

const isProjectInvitation = (notification: NotificationRead): boolean =>
  String(notification.payload?.type ?? "") === "project_invitation";

const getInvitationToken = (notification: NotificationRead): string =>
  String(notification.payload?.invitation_token ?? "");

const formatWhen = (isoDate: string): string => {
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-GB", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
};

export function NotificationBell() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<NotificationRead[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [actionBusyId, setActionBusyId] = useState<string>("");

  const unreadCount = useMemo(
    () => items.filter((item) => !item.read_at).length,
    [items],
  );

  const ensureToken = useCallback((): string | null => {
    const token = getValidAccessToken();
    if (!token) {
      clearAuthSession();
      router.replace("/login");
      return null;
    }
    return token;
  }, [router]);

  const loadNotifications = useCallback(async () => {
    const token = ensureToken();
    if (!token) return;

    setLoading(true);
    setError("");
    try {
      const data = await notificationsApi.list(token);
      setItems(data);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Failed to load notifications.");
    } finally {
      setLoading(false);
    }
  }, [ensureToken]);

  useEffect(() => {
    void loadNotifications();
    const intervalId = window.setInterval(() => {
      void loadNotifications();
    }, 30000);

    return () => window.clearInterval(intervalId);
  }, [loadNotifications]);

  useEffect(() => {
    if (open) {
      void loadNotifications();
    }
  }, [open, loadNotifications]);

  const markAsRead = async (item: NotificationRead) => {
    if (item.read_at) return;
    const token = ensureToken();
    if (!token) return;

    try {
      const updated = await notificationsApi.markRead(token, item.id);
      setItems((prev) => prev.map((entry) => (entry.id === item.id ? updated : entry)));
    } catch {
      // ignore, list will refresh on next poll/open
    }
  };

  const acceptInvitation = async (item: NotificationRead) => {
    const invitationToken = getInvitationToken(item);
    if (!invitationToken) return;

    const token = ensureToken();
    if (!token) return;

    setActionBusyId(item.id);
    setError("");
    try {
      const response = await notificationsApi.acceptInvitation(token, invitationToken);
      const updated = await notificationsApi.markRead(token, item.id);
      setItems((prev) => prev.map((entry) => (entry.id === item.id ? updated : entry)));
      router.push(`/projects/${response.project_id}`);
    } catch (actionError) {
      setError(
        actionError instanceof Error ? actionError.message : "Unable to accept invitation.",
      );
    } finally {
      setActionBusyId("");
    }
  };

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        className="relative inline-flex h-6 w-6 items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--charcoal)_8%,white)] text-[11px] text-[var(--muted)]"
        aria-label="Notifications"
      >
        🔔
        {unreadCount > 0 ? (
          <span className="absolute -right-1 -top-1 inline-flex min-h-4 min-w-4 items-center justify-center rounded-full bg-[#ef4444] px-1 text-[10px] font-semibold text-white">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        ) : null}
      </button>

      {open ? (
        <div className="absolute right-0 z-40 mt-2 w-[320px] rounded-xl border border-[var(--border)] bg-[var(--surface)] p-2 shadow-[0_18px_50px_rgba(0,0,0,0.18)]">
          <div className="mb-2 flex items-center justify-between px-1">
            <p className="text-xs font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
              Notifications
            </p>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="text-xs text-[var(--muted)] hover:text-[var(--deep-navy)] dark:hover:text-[var(--foreground)]"
            >
              Close
            </button>
          </div>

          {error ? (
            <div className="mb-2 rounded-md border border-red-200 bg-red-50 px-2 py-1 text-[11px] text-red-700">
              {error}
            </div>
          ) : null}

          {loading ? (
            <p className="px-2 py-3 text-xs text-[var(--muted)]">Loading...</p>
          ) : items.length === 0 ? (
            <p className="px-2 py-3 text-xs text-[var(--muted)]">No notifications.</p>
          ) : (
            <ul className="max-h-[340px] space-y-1 overflow-y-auto pr-1">
              {items.map((item) => (
                <li
                  key={item.id}
                  className={`rounded-md border px-2 py-2 ${
                    item.read_at
                      ? "border-[var(--border)] bg-[var(--surface)]"
                      : "border-[color-mix(in_oklab,var(--electric-blue)_30%,white)] bg-[color-mix(in_oklab,var(--electric-blue)_8%,white)]"
                  }`}
                >
                  <button
                    type="button"
                    onClick={() => void markAsRead(item)}
                    className="w-full text-left"
                  >
                    <p className="text-xs font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      {item.title}
                    </p>
                    <p className="mt-0.5 text-xs text-[var(--muted)]">{item.message}</p>
                    <p className="mt-1 text-[10px] text-[var(--muted)]">{formatWhen(item.created_at)}</p>
                  </button>

                  {isProjectInvitation(item) ? (
                    <button
                      type="button"
                      onClick={() => void acceptInvitation(item)}
                      disabled={actionBusyId === item.id}
                      className="mt-2 inline-flex rounded-md bg-[var(--electric-blue)] px-2 py-1 text-[11px] font-medium text-white disabled:opacity-60"
                    >
                      {actionBusyId === item.id ? "Accepting..." : "Accept invitation"}
                    </button>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : null}
    </div>
  );
}
