import { API_BASE_URL } from "./auth";

export type NotificationRead = {
  id: string;
  title: string;
  message: string;
  payload?: Record<string, unknown> | null;
  created_at: string;
  read_at?: string | null;
  invitation_status?: "pending" | "accepted" | "declined" | null;
};

type InvitationAcceptResponse = {
  project_id: string;
  member: Record<string, unknown>;
  message: string;
};

const parseBody = async (response: Response): Promise<Record<string, unknown> | NotificationRead[]> => {
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return (await response.json().catch(() => ({}))) as Record<string, unknown> | NotificationRead[];
  }

  const text = await response.text().catch(() => "");
  if (!text) return {};
  try {
    return JSON.parse(text) as Record<string, unknown> | NotificationRead[];
  } catch {
    return { detail: text };
  }
};

const withAuth = (token: string, init: RequestInit = {}): RequestInit => ({
  ...init,
  headers: {
    Authorization: `Bearer ${token}`,
    ...(init.body ? { "Content-Type": "application/json" } : {}),
    ...(init.headers || {}),
  },
  cache: "no-store",
});

const toError = (data: unknown, status: number): Error => {
  const obj = (data ?? {}) as Record<string, unknown>;
  const detail = obj.detail ?? obj.message ?? obj.error;
  return new Error(typeof detail === "string" ? detail : `Request failed (${status})`);
};

export const notificationsApi = {
  async list(token: string): Promise<NotificationRead[]> {
    const response = await fetch(
      `${API_BASE_URL}/0.1.0/notifications/`,
      withAuth(token),
    );
    const data = await parseBody(response);
    if (!response.ok) throw toError(data, response.status);
    return Array.isArray(data) ? (data as NotificationRead[]) : [];
  },

  async markRead(token: string, notificationId: string): Promise<NotificationRead> {
    const response = await fetch(
      `${API_BASE_URL}/0.1.0/notifications/${encodeURIComponent(notificationId)}/read`,
      withAuth(token, { method: "POST" }),
    );
    const data = await parseBody(response);
    if (!response.ok) throw toError(data, response.status);
    return data as NotificationRead;
  },

  async acceptInvitation(token: string, invitationToken: string): Promise<InvitationAcceptResponse> {
    const response = await fetch(
      `${API_BASE_URL}/0.1.0/projects/invitations/${encodeURIComponent(invitationToken)}/accept`,
      withAuth(token, { method: "POST" }),
    );
    const data = await parseBody(response);
    if (!response.ok) throw toError(data, response.status);
    return data as InvitationAcceptResponse;
  },
};
