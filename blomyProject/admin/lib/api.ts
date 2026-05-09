const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";
const PREFIX = "/api/v1";

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return sessionStorage.getItem("vyla_admin_token");
}

export function setToken(token: string): void {
  sessionStorage.setItem("vyla_admin_token", token);
}

export function clearToken(): void {
  sessionStorage.removeItem("vyla_admin_token");
}

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

async function request<T>(path: string, token: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(`${BASE}${PREFIX}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(options.headers ?? {}),
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new ApiError(res.status, text);
  }
  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string, token: string) => request<T>(path, token),
  post: <T>(path: string, token: string, body?: unknown) =>
    request<T>(path, token, { method: "POST", body: body ? JSON.stringify(body) : undefined }),
};

export async function adminLogin(email: string, password: string): Promise<string> {
  const res = await fetch(`${BASE}${PREFIX}/admin/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "Login failed");
    throw new ApiError(res.status, text);
  }
  const data = await res.json();
  const token: string = data.access_token ?? data.token;
  if (!token) throw new ApiError(401, "No access token in response");
  return token;
}

// ---- typed response helpers ----

export type OverviewData = {
  total_users: number; active_users: number; deleted_users: number; anonymous_users: number;
  premium_users: number; free_users: number; trialing_users: number;
  wearable_connected_users: number; onboarding_completed_users: number;
  signups_today: number; signups_this_week: number;
  ai_threads_total: number; daily_logs_today: number; predictions_today: number;
  total_invoiced_gbp: number;
  flutterwave_errors_30d: number; stripe_errors_30d: number;
  referrals_total: number; referrals_qualified: number; active_premium_grants: number;
};

export type UserItem = {
  id: string; email: string | null; account_mode: string; email_verified: boolean;
  is_admin: boolean; deleted_at: string | null; created_at: string;
  full_name: string | null; wearable_type: string | null;
  subscription_tier: string | null; subscription_status: string | null; subscription_provider: string | null;
  onboarding_completed: boolean;
};

export type UserListOut = { items: UserItem[]; total: number; page: number; page_size: number };

export type UserDetailOut = {
  id: string; email: string | null; account_mode: string; email_verified: boolean;
  is_admin: boolean; deleted_at: string | null; created_at: string;
  full_name: string | null; date_of_birth: string | null; goal: string | null;
  wearable_type: string | null; timezone: string | null;
  onboarding_completed: boolean; onboarding_step: number | null;
  subscription_tier: string | null; subscription_status: string | null;
  subscription_provider: string | null; subscription_period_end: string | null;
  cycle_records_count: number; daily_logs_count: number; ai_threads_count: number;
};

export type SubItem = {
  id: string; user_id: string; user_email: string | null; tier: string; status: string;
  provider: string | null; billing_interval: string | null; amount: number | null;
  currency: string | null; current_period_end: string | null; created_at: string;
};
export type SubListOut = { items: SubItem[]; total: number; page: number; page_size: number };

export type InvoiceItem = {
  id: string; subscription_id: string | null; user_email: string | null;
  provider_invoice_id: string | null; provider_customer_id: string | null;
  total: number; currency: string; status: string; provider: string | null; created_at: string;
};
export type InvoiceListOut = { items: InvoiceItem[]; total: number; page: number; page_size: number };

export type FlwError = {
  id: string; event_type: string | null; transaction_id: string | null; tx_ref: string | null;
  provider_customer_id: string | null; user_id: string | null;
  error_message: string; signature_present: boolean; legacy_hash_present: boolean; created_at: string;
};
export type FlwErrorListOut = { items: FlwError[]; total: number };

export type StripeError = {
  id: string; stripe_event_id: string | null; event_type: string | null;
  payment_intent_id: string | null; subscription_id: string | null; customer_id: string | null;
  error_message: string; error_category: string; signature_present: boolean; created_at: string;
};
export type StripeErrorListOut = { items: StripeError[]; total: number };

export type AuditEvent = {
  id: string; actor_user_id: string | null; action: string; payload: Record<string, unknown>; created_at: string;
};
export type AuditEventListOut = { items: AuditEvent[]; total: number; page: number; page_size: number };
export type PredictionItem = {
  id: string; user_id: string; user_email: string | null; current_phase: string;
  confidence: number; warning_flags: unknown[]; models_used: unknown[];
  model_version: string | null; source: string; generated_at: string;
};
export type PredictionListOut = { items: PredictionItem[]; total: number; page: number; page_size: number };

export type WearableUserItem = {
  user_id: string; user_email: string | null; wearable_type: string;
  latest_sync: string | null; metrics_count: number;
};
export type WearableListOut = { items: WearableUserItem[]; total: number };

export type NotificationItem = {
  id: string; user_id: string; notification_type: string; category: string;
  channel: string; title: string; status: string; priority: string;
  delivery_attempts: number; scheduled_for: string; delivered_at: string | null;
};
export type NotificationListOut = { items: NotificationItem[]; total: number; page: number; page_size: number };

export type ReferralItem = {
  id: string; inviter_user_id: string; inviter_email: string | null;
  invited_user_id: string | null; referral_code: string; source: string | null;
  status: string; created_at: string; qualified_at: string | null;
};
export type ReferralListOut = { items: ReferralItem[]; total: number; page: number; page_size: number };

export type GrantItem = {
  id: string; user_id: string; user_email: string | null; tier: string;
  source_type: string; days_granted: number; starts_at: string; ends_at: string;
  active: boolean; created_at: string;
};
export type GrantListOut = { items: GrantItem[]; total: number; page: number; page_size: number };

export type AiThreadItem = {
  id: string; user_id: string; user_email: string | null; title: string | null;
  message_count: number; created_at: string; updated_at: string;
};
export type AiThreadListOut = { items: AiThreadItem[]; total: number; page: number; page_size: number };

export type ContactMessageItem = {
  id: string; name: string; email: string; subject: string; message: string;
  read: boolean; created_at: string;
};
export type ContactListOut = { items: ContactMessageItem[]; total: number; unread: number };
