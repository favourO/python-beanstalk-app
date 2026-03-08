import { API_BASE_URL } from "./auth";

export type ProfilePayload = {
  first_name: string | null;
  last_name: string | null;
  country: string | null;
  company: string | null;
  job_title: string | null;
};

export type PreferencesPayload = {
  theme: string;
  time_zone: string;
  default_workspace_view: string;
  email_reports: boolean;
  product_updates: boolean;
  default_project_id: string | null;
};

export type FeedbackPayload = {
  subject: string;
  category: string;
  message: string;
};

const SETTINGS = {
  PROFILE: "/0.1.0/settings/profile",
  PREFERENCES: "/0.1.0/settings/preferences",
  ACCOUNT: "/0.1.0/settings/account",
};

const FEEDBACK_CREATE = "/0.1.0/feedback";

async function request(path: string, token: string, init: RequestInit = {}) {
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
    const detail = (data as Record<string, unknown>).detail ?? (data as Record<string, unknown>).message;
    throw new Error(typeof detail === "string" ? detail : `Request failed (${response.status})`);
  }

  return data;
}

export const settingsApi = {
  getProfile(token: string) {
    return request(SETTINGS.PROFILE, token);
  },
  updateProfile(token: string, payload: ProfilePayload) {
    return request(SETTINGS.PROFILE, token, {
      method: "PATCH",
      body: JSON.stringify(payload),
    });
  },
  getPreferences(token: string) {
    return request(SETTINGS.PREFERENCES, token);
  },
  updatePreferences(token: string, payload: PreferencesPayload) {
    return request(SETTINGS.PREFERENCES, token, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  },
  createFeedback(token: string, payload: FeedbackPayload) {
    return request(FEEDBACK_CREATE, token, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  deleteAccount(token: string) {
    return request(SETTINGS.ACCOUNT, token, {
      method: "DELETE",
      body: JSON.stringify({ confirm: true }),
    });
  },
};
