import { API_BASE_URL } from "./config";

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

async function request<T>(path: string, opts: Options = {}): Promise<T> {
  const { method = "GET", body, signal, auth = true } = opts;
  const headers: Record<string, string> = { accept: "*/*" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (auth && authToken) headers["Authorization"] = "bearer " + authToken;

  let res: Response;
  try {
    res = await fetch(API_BASE_URL + path, {
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
    const msg = parsed?.meta?.message || parsed?.message || `Request failed (${res.status})`;
    throw new ApiError(msg, res.status, parsed);
  }

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
  // Returns the full envelope (used by auth, which needs status + data together).
  raw: async (path: string, opts: Options = {}): Promise<ApiEnvelope<any>> => {
    const { method = "GET", body, auth = true } = opts;
    const headers: Record<string, string> = { accept: "*/*" };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (auth && authToken) headers["Authorization"] = "bearer " + authToken;
    const res = await fetch(API_BASE_URL + path, {
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
