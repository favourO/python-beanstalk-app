import { API_BASE_URL } from "./auth";

const UPLOADS_ENDPOINTS = {
  LIST: (userId: string) => `/0.1.0/uploads/${encodeURIComponent(userId)}`,
  UPLOAD: "/0.1.0/uploads",
  DETAIL_ITEM: (uploadId: string) => `/0.1.0/uploads/item/${encodeURIComponent(uploadId)}`,
  ROWS: (uploadId: string, projectId: string, offset = 0, limit = 100) => {
    const params = new URLSearchParams({
      offset: String(offset),
      limit: String(limit),
    });
    if (projectId) params.append("project_id", projectId);
    return `/0.1.0/uploads/item/${encodeURIComponent(uploadId)}/rows?${params.toString()}`;
  },
  DELETE: (uploadId: string) => `/0.1.0/uploads/item/${encodeURIComponent(uploadId)}`,
  USAGE_SUMMARY: "/0.1.0/uploads/usage/summary",
} as const;

export type UploadRecord = {
  upload_id?: string;
  uploadId?: string;
  file_id?: string;
  id?: string;
  original_name?: string;
  name?: string;
  content_type?: string;
  ext?: string;
  size_bytes?: number;
  status?: string;
  created_at?: string;
  [key: string]: unknown;
};

export type UploadUsageSummary = {
  total_size_bytes: number;
  upload_count: number;
  plan_remaining_bytes?: number | null;
  plan_max_bytes?: number | null;
};

export type UploadRowsResponse = {
  data: Record<string, unknown>[];
  columns: string[];
  total_rows: number;
  source_key?: string;
};

export class UploadsApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "UploadsApiError";
    this.status = status;
  }
}

const parsePayload = async (response: Response): Promise<Record<string, unknown> | unknown[]> => {
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

const errorFrom = (status: number, payload: unknown, fallback: string): UploadsApiError => {
  const data = (payload ?? {}) as Record<string, unknown>;
  const detail = data.detail ?? data.message ?? data.error;
  const message = typeof detail === "string" ? detail : fallback;
  return new UploadsApiError(status, message);
};

const normalizeUploadsList = (payload: unknown): UploadRecord[] => {
  if (Array.isArray(payload)) return payload as UploadRecord[];
  if (!payload || typeof payload !== "object") return [];
  const obj = payload as Record<string, unknown>;
  const candidates = [obj.items, obj.results, obj.data, obj.uploads];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) return candidate as UploadRecord[];
  }
  return [];
};

const readPlanHeaderNumber = (headers: Headers, key: string): number | null => {
  const raw = headers.get(key) ?? headers.get(key.toLowerCase());
  if (!raw) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
};

export const resolveUploadsScopeId = (): string => {
  if (typeof window === "undefined") return "";
  const sources = [window.localStorage, window.sessionStorage];
  const keys = ["user_id", "id", "userId", "uuid", "uid"];
  for (const storage of sources) {
    try {
      const raw = storage.getItem("user");
      if (!raw) continue;
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      for (const key of keys) {
        const value = parsed[key];
        if (typeof value === "string" && value.trim()) return value.trim();
      }
    } catch {
      // ignore malformed storage
    }
  }
  return "";
};

export const uploadsApi = {
  async list(token: string, userId: string): Promise<UploadRecord[]> {
    const response = await fetch(`${API_BASE_URL}${UPLOADS_ENDPOINTS.LIST(userId)}`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    const payload = await parsePayload(response);
    if (!response.ok) {
      throw errorFrom(response.status, payload, `Failed to load uploads (${response.status})`);
    }
    return normalizeUploadsList(payload);
  },

  async usageSummary(token: string): Promise<UploadUsageSummary> {
    const response = await fetch(`${API_BASE_URL}${UPLOADS_ENDPOINTS.USAGE_SUMMARY}`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    const payload = await parsePayload(response);
    if (!response.ok) {
      throw errorFrom(response.status, payload, `Failed to load usage (${response.status})`);
    }
    const data = (payload ?? {}) as Record<string, unknown>;
    return {
      total_size_bytes: Number(data.total_size_bytes) || 0,
      upload_count: Number(data.upload_count) || 0,
      plan_remaining_bytes: readPlanHeaderNumber(response.headers, "x-plan-remaining-upload-bytes"),
      plan_max_bytes: readPlanHeaderNumber(response.headers, "x-plan-max-upload-bytes"),
    };
  },

  async uploadFiles(
    token: string,
    projectId: string,
    files: File[],
    onProgress?: (loaded: number, total: number) => void,
  ): Promise<Record<string, unknown>> {
    const form = new FormData();
    files.forEach((file) => form.append("files", file));

    const url = `${API_BASE_URL}${UPLOADS_ENDPOINTS.UPLOAD}?project_id=${encodeURIComponent(projectId)}`;

    return await new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("POST", url, true);
      xhr.setRequestHeader("Authorization", `Bearer ${token}`);

      xhr.upload.onprogress = (event) => {
        if (!event.lengthComputable) return;
        onProgress?.(event.loaded, event.total);
      };

      xhr.onload = () => {
        const text = xhr.responseText || "";
        let parsed: Record<string, unknown> = {};
        if (text) {
          try {
            parsed = JSON.parse(text) as Record<string, unknown>;
          } catch {
            parsed = { detail: text };
          }
        }
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(parsed);
          return;
        }
        reject(errorFrom(xhr.status, parsed, `Upload failed (${xhr.status})`));
      };

      xhr.onerror = () => {
        reject(new UploadsApiError(0, "Upload failed due to a network error."));
      };

      xhr.send(form);
    });
  },

  async deleteUpload(token: string, uploadId: string): Promise<void> {
    const response = await fetch(`${API_BASE_URL}${UPLOADS_ENDPOINTS.DELETE(uploadId)}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    const payload = await parsePayload(response);
    if (!response.ok) {
      throw errorFrom(response.status, payload, `Failed to delete upload (${response.status})`);
    }
  },

  async detail(token: string, uploadId: string): Promise<UploadRecord> {
    const response = await fetch(`${API_BASE_URL}${UPLOADS_ENDPOINTS.DETAIL_ITEM(uploadId)}`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    const payload = await parsePayload(response);
    if (!response.ok) {
      throw errorFrom(response.status, payload, `Failed to load file details (${response.status})`);
    }
    return (payload ?? {}) as UploadRecord;
  },

  async rows(
    token: string,
    uploadId: string,
    projectId: string,
    offset = 0,
    limit = 100,
  ): Promise<UploadRowsResponse> {
    const response = await fetch(
      `${API_BASE_URL}${UPLOADS_ENDPOINTS.ROWS(uploadId, projectId, offset, limit)}`,
      {
        headers: { Authorization: `Bearer ${token}` },
        cache: "no-store",
      },
    );
    const payload = await parsePayload(response);
    if (!response.ok) {
      throw errorFrom(response.status, payload, `Failed to load file rows (${response.status})`);
    }
    const data = (payload ?? {}) as Record<string, unknown>;
    return {
      data: Array.isArray(data.data) ? (data.data as Record<string, unknown>[]) : [],
      columns: Array.isArray(data.columns) ? (data.columns as string[]) : [],
      total_rows: Number(data.total_rows) || 0,
      source_key: typeof data.source_key === "string" ? data.source_key : undefined,
    };
  },
};
