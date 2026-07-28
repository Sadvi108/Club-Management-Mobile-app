import { getApiBaseUrl } from "./config";

// Backend envelope: { status, meta: { code }, data }
export type ApiEnvelope<T> = {
  status?: number;
  meta?: { code?: number; message?: string };
  data?: T;
};

export class ApiError extends Error {
  status: number;
  body: unknown;
  constructor(message: string, status: number, body: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.body = body;
  }
}

// Holds the current bearer token. Set by the auth layer on login/restore.
let authToken: string | null = null;
export function setAuthToken(token: string | null) {
  authToken = token;
}
export function getAuthToken() {
  return authToken;
}

// Called by the auth layer when the server rejects the token (401/expired).
let onUnauthorized: (() => void) | null = null;
export function setUnauthorizedHandler(fn: (() => void) | null) {
  onUnauthorized = fn;
}

type Options = { method?: string; body?: unknown; signal?: AbortSignal; auth?: boolean };

// The backend answers HTTP 200 with an error *inside* the envelope
// ({ status: 400, meta: { code: 400, error: "..." } }). Pull that code out so callers
// see the real failure instead of a silently empty result. `status` is sometimes a
// string on non-enveloped routes (e.g. /Bcpg/VerifyPayment → { status: "NotFound" }),
// so only numeric codes count.
function innerErrorCode(parsed: any): number | null {
  const code = typeof parsed?.meta?.code === "number" ? parsed.meta.code : parsed?.status;
  return typeof code === "number" && code >= 400 ? code : null;
}

function innerErrorMessage(parsed: any, code: number): string {
  const msg = parsed?.meta?.error || parsed?.meta?.message || parsed?.message || parsed?.title;
  return String(msg || `Request failed (${code})`).trim();
}

async function request<T>(path: string, opts: Options = {}): Promise<T> {
  const { method = "GET", body, signal, auth = true } = opts;
  const headers: Record<string, string> = { accept: "*/*" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (auth && authToken) headers["Authorization"] = "bearer " + authToken;

  let res: Response;
  try {
    res = await fetch(getApiBaseUrl() + path, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal,
    });
  } catch (e: any) {
    throw new ApiError(`Network error: ${e?.message || "request failed"}`, 0, null);
  }

  const text = await res.text();
  let parsed: any = text;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    /* keep raw text */
  }

  if (res.status === 401) {
    onUnauthorized?.();
    throw new ApiError("Session expired. Please sign in again.", 401, parsed);
  }
  if (!res.ok) {
    const msg = parsed?.meta?.error || parsed?.meta?.message || parsed?.message || `Request failed (${res.status})`;
    throw new ApiError(String(msg).trim(), res.status, parsed);
  }

  // HTTP 200 carrying an in-envelope error.
  const inner = innerErrorCode(parsed);
  if (inner) throw new ApiError(innerErrorMessage(parsed, inner), inner, parsed);

  // Unwrap the standard envelope when present.
  if (parsed && typeof parsed === "object" && "data" in parsed) {
    return (parsed as ApiEnvelope<T>).data as T;
  }
  return parsed as T;
}

export const http = {
  get: <T>(path: string, opts?: Omit<Options, "method" | "body">) =>
    request<T>(path, { ...opts, method: "GET" }),
  post: <T>(path: string, body?: unknown, opts?: Omit<Options, "method" | "body">) =>
    request<T>(path, { ...opts, method: "POST", body }),
  // multipart/form-data POST. Do NOT set Content-Type — fetch adds the boundary.
  // Unwraps the standard { status, meta, data } envelope and returns `data`.
  postForm: async <T>(path: string, form: FormData): Promise<T> => {
    const headers: Record<string, string> = { accept: "*/*" };
    if (authToken) headers["Authorization"] = "bearer " + authToken;
    let res: Response;
    try {
      res = await fetch(getApiBaseUrl() + path, { method: "POST", headers, body: form });
    } catch (e: any) {
      throw new ApiError(`Network error: ${e?.message || "request failed"}`, 0, null);
    }
    const text = await res.text();
    let parsed: any = text;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {}
    if (res.status === 401) {
      onUnauthorized?.();
      throw new ApiError("Session expired. Please sign in again.", 401, parsed);
    }
    // Backend returns HTTP 200 with an inner envelope; surface inner errors too.
    const inner = innerErrorCode(parsed);
    if (!res.ok || inner) {
      const code = inner || res.status;
      throw new ApiError(innerErrorMessage(parsed, code), code, parsed);
    }
    if (parsed && typeof parsed === "object" && "data" in parsed) return parsed.data as T;
    return parsed as T;
  },
  // Returns the full envelope (used by auth, which needs status + data together).
  raw: async (path: string, opts: Options = {}): Promise<ApiEnvelope<any>> => {
    const { method = "GET", body, auth = true } = opts;
    const headers: Record<string, string> = { accept: "*/*" };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (auth && authToken) headers["Authorization"] = "bearer " + authToken;
    const res = await fetch(getApiBaseUrl() + path, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let parsed: any = text;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {}
    if (!res.ok && res.status !== 400) {
      throw new ApiError(parsed?.meta?.message || `Request failed (${res.status})`, res.status, parsed);
    }
    return parsed;
  },
};
