import { API_BASE_URL } from "./auth";

export const BILLING_ENDPOINTS = {
  PLANS: "/0.1.0/billing/plans",
  ME: "/0.1.0/billing/me",
  CREATE_CHECKOUT: "/0.1.0/billing/create-checkout-session",
  CUSTOMER_PORTAL: "/0.1.0/billing/customer-portal",
  CANCEL: "/0.1.0/billing/cancel",
  PREMIUM_SCREEN_DISMISS: "/0.1.0/auth/premium-screen/dismiss",
} as const;

export class BillingApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "BillingApiError";
    this.status = status;
  }
}

const parseBody = async (response: Response): Promise<Record<string, unknown> | unknown[]> => {
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return (await response.json().catch(() => ({}))) as Record<string, unknown> | unknown[];
  }
  const text = await response.text().catch(() => "");
  if (!text) return {};
  try {
    return JSON.parse(text) as Record<string, unknown> | unknown[];
  } catch {
    return { detail: text };
  }
};

const toError = (status: number, payload: unknown, fallback: string): BillingApiError => {
  const obj = (payload ?? {}) as Record<string, unknown>;
  const detail = obj.detail ?? obj.message ?? obj.error;
  return new BillingApiError(status, typeof detail === "string" ? detail : fallback);
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

const requestJson = async <T>(token: string, path: string, init: RequestInit = {}): Promise<T> => {
  const response = await fetch(`${API_BASE_URL}${path}`, withAuth(token, init));
  const body = await parseBody(response);
  if (!response.ok) {
    throw toError(response.status, body, `Request failed (${response.status})`);
  }
  return body as T;
};

export type BillingPlan = {
  name?: string;
  price?: string;
  features?: string[];
  [key: string]: unknown;
};

export type BillingMe = Record<string, unknown>;

export type CheckoutSessionResponse = {
  session_id?: string;
  [key: string]: unknown;
};

export const billingApi = {
  getPlans(token: string) {
    return requestJson<BillingPlan[]>(token, BILLING_ENDPOINTS.PLANS);
  },
  getMe(token: string) {
    return requestJson<BillingMe>(token, BILLING_ENDPOINTS.ME);
  },
  createCheckout(
    token: string,
    payload: { plan: "basic" | "premium"; success_url?: string; cancel_url?: string },
  ) {
    return requestJson<CheckoutSessionResponse>(token, BILLING_ENDPOINTS.CREATE_CHECKOUT, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  openCustomerPortal(token: string, payload: { return_url?: string } = {}) {
    return requestJson<{ url?: string }>(token, BILLING_ENDPOINTS.CUSTOMER_PORTAL, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  cancelSubscription(token: string, payload: { at_period_end?: boolean } = { at_period_end: false }) {
    return requestJson<Record<string, unknown>>(token, BILLING_ENDPOINTS.CANCEL, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  dismissPremiumScreen(token: string) {
    return requestJson<Record<string, unknown>>(token, BILLING_ENDPOINTS.PREMIUM_SCREEN_DISMISS, {
      method: "POST",
    });
  },
};
