import { API_BASE_URL } from "./auth";

const ENGINE_QUERY_PATH = "/v1/engine/query";
const QUERY_RESULT_PATH = "/v1/query-sessions";

export type QueryMode = "auto" | "fast" | "deep";

export type StartQueryInput = {
  token: string;
  question: string;
  files: File[];
  workspaceId?: string;
  mode?: QueryMode;
  persist?: boolean;
  conversationId?: string;
};

export type StartQueryResponse = {
  query_session_id: string;
  status: "accepted";
  stream_url: string;
  result_url: string;
};

export type QueryStreamEventName =
  | "query.accepted"
  | "upload.started"
  | "upload.completed"
  | "ingestion.started"
  | "dataset.ready"
  | "planner.started"
  | "planner.completed"
  | "query.executing"
  | "query.result"
  | "answer.chunk"
  | "completed"
  | "failed";

export type QueryStreamEvent = {
  event: QueryStreamEventName;
  payload: Record<string, unknown>;
};

export class EngineApiError extends Error {
  status: number;
  url: string;
  responseText: string;

  constructor(status: number, message: string, url: string, responseText: string) {
    super(message);
    this.name = "EngineApiError";
    this.status = status;
    this.url = url;
    this.responseText = responseText;
  }
}

export type StreamQueryOptions = {
  token: string;
  streamUrl: string;
  signal?: AbortSignal;
  onEvent: (event: QueryStreamEvent) => void;
};

const resolveApiUrl = (path: string): string => {
  if (/^https?:\/\//i.test(path)) return path;
  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
};

const parseJson = async (response: Response): Promise<Record<string, unknown>> =>
  (await response.json().catch(() => ({}))) as Record<string, unknown>;

const ensureToken = (token: string) => {
  if (!token?.trim()) {
    throw new EngineApiError(401, "Missing access token. Please log in again.", "", "");
  }
};

const parseErrorMessage = (status: number, text: string, fallback: string) => {
  if (!text) return fallback;
  try {
    const parsed = JSON.parse(text) as Record<string, unknown>;
    const detail = parsed.detail ?? parsed.message ?? parsed.error;
    if (typeof detail === "string" && detail.trim()) return detail;
  } catch {
    // keep plain text fallback below
  }
  return text.trim() || fallback;
};

export const startQuery = async ({
  token,
  question,
  files,
  workspaceId,
  mode = "auto",
  persist = true,
  conversationId,
}: StartQueryInput): Promise<StartQueryResponse> => {
  ensureToken(token);
  const form = new FormData();
  form.append("question", question);
  form.append("mode", mode);
  form.append("persist", String(persist));
  if (workspaceId) form.append("workspace_id", workspaceId);
  if (conversationId) form.append("conversation_id", conversationId);
  files.forEach((file) => form.append("files", file));

  const url = resolveApiUrl(ENGINE_QUERY_PATH);
  let response: Response;

  try {
    response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: form,
      cache: "no-store",
    });
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? `Network error while calling ${url}: ${error.message}`
        : `Network error while calling ${url}`,
    );
  }

  if (!response.ok) {
    const responseText = await response.text().catch(() => "");
    const message = parseErrorMessage(
      response.status,
      responseText,
      `Query request failed (${response.status})`,
    );
    console.error("query failed", response.status, responseText);
    throw new EngineApiError(response.status, message, url, responseText);
  }

  return (await response.json()) as StartQueryResponse;
};

const readEventBlocks = (
  buffer: string,
  onBlock: (block: string) => void,
): string => {
  let remaining = buffer.replace(/\r\n/g, "\n");
  let boundary = remaining.indexOf("\n\n");

  while (boundary >= 0) {
    const block = remaining.slice(0, boundary).trim();
    remaining = remaining.slice(boundary + 2);
    if (block) onBlock(block);
    boundary = remaining.indexOf("\n\n");
  }

  return remaining;
};

const parseEventBlock = (block: string): QueryStreamEvent | null => {
  const lines = block.split(/\r?\n/);
  let eventName = "";
  const dataLines: string[] = [];

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();
    if (line.startsWith("event:")) {
      eventName = line.slice(6).trim();
    } else if (line.startsWith("data:")) {
      dataLines.push(line.slice(5).trim());
    }
  }

  if (!eventName) return null;

  const payloadText = dataLines.join("\n");
  let payload: Record<string, unknown> = {};

  if (payloadText) {
    try {
      payload = JSON.parse(payloadText) as Record<string, unknown>;
    } catch {
      payload = { message: payloadText };
    }
  }

  return {
    event: eventName as QueryStreamEventName,
    payload,
  };
};

export const streamQuery = async ({
  token,
  streamUrl,
  signal,
  onEvent,
}: StreamQueryOptions): Promise<void> => {
  ensureToken(token);
  const url = resolveApiUrl(streamUrl);
  let response: Response;

  try {
    response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "text/event-stream",
      },
      signal,
      cache: "no-store",
    });
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? `Network error while streaming ${url}: ${error.message}`
        : `Network error while streaming ${url}`,
    );
  }

  if (!response.ok) {
    const responseText = await response.text().catch(() => "");
    const message = parseErrorMessage(
      response.status,
      responseText,
      `Unable to stream query (${response.status})`,
    );
    console.error("query stream failed", response.status, responseText);
    throw new EngineApiError(response.status, message, url, responseText);
  }

  if (!response.body) {
    throw new Error("Streaming response body is unavailable.");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    buffer = readEventBlocks(buffer, (block) => {
      const event = parseEventBlock(block);
      if (event) onEvent(event);
    });
  }

  const trailing = buffer.trim();
  if (trailing) {
    const event = parseEventBlock(trailing);
    if (event) onEvent(event);
  }
};

export const getFinalResult = async (
  resultUrl: string,
  token: string,
): Promise<Record<string, unknown>> => {
  ensureToken(token);
  const url = resolveApiUrl(resultUrl);
  let response: Response;

  try {
    response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
      cache: "no-store",
    });
  } catch (error) {
    throw new Error(
      error instanceof Error
        ? `Network error while loading ${url}: ${error.message}`
        : `Network error while loading ${url}`,
    );
  }

  if (!response.ok) {
    const responseText = await response.text().catch(() => "");
    const message = parseErrorMessage(
      response.status,
      responseText,
      `Failed to load result (${response.status})`,
    );
    console.error("query result failed", response.status, responseText);
    throw new EngineApiError(response.status, message, url, responseText);
  }

  return parseJson(response);
};

export const defaultResultUrl = (querySessionId: string): string =>
  `${QUERY_RESULT_PATH}/${encodeURIComponent(querySessionId)}/result`;
