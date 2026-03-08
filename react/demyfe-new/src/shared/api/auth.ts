const DEFAULT_API_BASE_URL = "https://api.demycorp.com/api";

const sanitizeBaseUrl = (url: string) => url.replace(/\/+$/, "");

export const API_BASE_URL = sanitizeBaseUrl(
  process.env.NEXT_PUBLIC_API_BASE_URL ?? DEFAULT_API_BASE_URL,
);

export const AUTH_ENDPOINTS = {
  SIGNUP: "/0.1.0/auth/signup",
  VERIFY: "/0.1.0/auth/verify",
  LOGIN: "/0.1.0/auth/login",
  SOCIAL_LOGIN: "/0.1.0/auth/social-login",
  GOOGLE_LOGIN: "/0.1.0/auth/google-login",
  ONBOARDING: "/0.1.0/auth/onboarding",
} as const;

export type LoginPayload = {
  email: string;
  password: string;
};

export type SignupPayload = {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  country: string;
  account_type: "business" | "individual";
};

export type VerifyPayload = {
  email: string;
  code: string;
};

export type AuthUser = Record<string, unknown>;

export type AuthResponse = {
  access_token?: string;
  user?: AuthUser;
  message?: string;
  [key: string]: unknown;
};

export type OnboardingPayload = {
  user_type: "company" | "individual";
  company_name?: string;
  role: string;
  intended_use: string;
  individual_profile?: string;
  business_type?: string;
  industry_type: string;
};

export type OnboardingResponse = Partial<OnboardingPayload> & {
  [key: string]: unknown;
};

export class AuthApiError extends Error {
  status: number;
  detail: string;

  constructor(status: number, detail: string) {
    super(detail);
    this.name = "AuthApiError";
    this.status = status;
    this.detail = detail;
  }
}

const createJsonHeaders = () => ({
  "Content-Type": "application/json",
});

async function parseApiBody(response: Response): Promise<Record<string, unknown>> {
  return (await response.json().catch(() => ({}))) as Record<string, unknown>;
}

async function postAuth<TPayload>(path: string, payload: TPayload): Promise<AuthResponse> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: createJsonHeaders(),
    body: JSON.stringify(payload),
  });

  const data = await parseApiBody(response);

  if (!response.ok) {
    const detail = data.detail ?? data.message ?? data.error;
    const message = typeof detail === "string" ? detail : `Request failed (${response.status})`;
    throw new AuthApiError(response.status, message);
  }

  return data as AuthResponse;
}

async function onboardingRequest<T>(
  token: string,
  init: RequestInit,
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${AUTH_ENDPOINTS.ONBOARDING}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body ? createJsonHeaders() : {}),
      ...(init.headers || {}),
    },
    cache: "no-store",
  });

  const data = await parseApiBody(response);
  if (!response.ok) {
    const detail = data.detail ?? data.message ?? data.error;
    const message = typeof detail === "string" ? detail : `Request failed (${response.status})`;
    throw new AuthApiError(response.status, message);
  }
  return data as T;
}

export const authApi = {
  login(payload: LoginPayload) {
    return postAuth(AUTH_ENDPOINTS.LOGIN, payload);
  },
  signup(payload: SignupPayload) {
    return postAuth(AUTH_ENDPOINTS.SIGNUP, payload);
  },
  verify(payload: VerifyPayload) {
    return postAuth(AUTH_ENDPOINTS.VERIFY, payload);
  },
  getOnboarding(token: string) {
    return onboardingRequest<OnboardingResponse>(token, { method: "GET" });
  },
  saveOnboarding(token: string, payload: OnboardingPayload) {
    return onboardingRequest<OnboardingResponse>(token, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  },
  getGoogleSigninUrl() {
    return `${API_BASE_URL}${AUTH_ENDPOINTS.GOOGLE_LOGIN}`;
  },
};
