import { Platform } from "react-native";
import { getApiBaseUrl, getApiEnv, getBoostBaseUrl, getBoostEnv } from "./config";

/** `/Bcpg/*` may live on a different host than the rest of the API — see config.boostVia. */
function isBoostPath(path: string): boolean {
  return path.startsWith("/Bcpg");
}

function baseUrlFor(path: string): string {
  if (isBoostPath(path)) return getBoostBaseUrl() ?? getApiBaseUrl();
  return getApiBaseUrl();
}

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

/**
 * A failed fetch on a device is almost always the UAT certificate, not the network.
 *
 * That host serves the stock self-signed Plesk certificate: it is issued by itself AND it
 * carries no SAN entry for `apimacuat.zyncbook.com` (CN is literally "Plesk"). Trusting the
 * certificate isn't enough — Android and iOS also verify the hostname against the SAN, so the
 * connection is refused before any request goes out. `plugins/withUatCertificate.js` covers the
 * trust half only. Nothing in the app can fix the hostname half; the host needs a real
 * certificate. Say that instead of "Network error".
 */
function networkErrorMessage(raw: string, path?: string): string {
  // A Boost call can be aimed at a different host than the rest of the API, so blame the
  // host the request actually went to rather than the signed-in environment.
  const boost = !!path && isBoostPath(path);
  const env = boost ? (getBoostEnv() ?? getApiEnv()) : getApiEnv();
  if (Platform.OS !== "web" && env.selfSignedCert) {
    const host = new URL(env.baseUrl).host;
    if (boost) {
      return (
        `Online payment isn't available on this device yet. The payment gateway is served from ` +
        `${host}, whose certificate phones refuse to accept — it works in a browser but not in ` +
        `the app. This is a server-side fix: the gateway needs to ship to the production API, or ` +
        `${host} needs a valid certificate.`
      );
    }
    return (
      `Can't reach ${env.label} securely. ${host} is using a self-signed certificate that phones ` +
      `refuse to accept. This is a server-side fix — that host needs a valid certificate installed.`
    );
  }
  return `Network error: ${raw || "request failed"}`;
}

// The backend answers HTTP 200 with an error *inside* the envelope. Pull that code out so
// callers see the real failure instead of a silently empty result. `status` is sometimes a
// string on non-enveloped routes (e.g. /Bcpg/VerifyPayment → { status: "NotFound" }), so only
// numeric codes count.
//
// Both slots have to be inspected, not just the first one that happens to be a number. A
// failed report answers `{ status: 400, meta: { code: 0, error: "..." } }` — `meta.code` is a
// perfectly good number (0) that is not an error code, and preferring it hid the 400 behind
// it. The request then "succeeded" with the error envelope as its payload, which is what
// handed screens an object where they expected an array (`rows.forEach is not a function`).
function innerErrorCode(parsed: any): number | null {
  const codes = [parsed?.meta?.code, parsed?.status].filter(
    (c): c is number => typeof c === "number" && c >= 400
  );
  return codes.length ? Math.max(...codes) : null;
}

/**
 * Does this response carry the standard `{ status, meta, data }` envelope?
 *
 * `data` is omitted entirely when a route has nothing to return (e.g.
 * `GET /Listing/DropdownListByType/6` → `{"status":200,"meta":{"code":200}}`), so keying off
 * `"data" in parsed` alone made those calls resolve with the envelope itself — an object handed
 * to callers expecting a list. Anything carrying a `meta` block is an envelope; its absent
 * `data` unwraps to null. Non-enveloped payloads (`/Bcpg/VerifyPayment` → `{ status: "NotFound" }`)
 * have no `meta` and are still returned untouched.
 */
function isEnvelope(parsed: any): boolean {
  if (!parsed || typeof parsed !== "object") return false;
  return "data" in parsed || (!!parsed.meta && typeof parsed.meta === "object");
}

/**
 * Server error text that must never reach a user's screen.
 *
 * Club.Api returns raw persistence-layer errors in `meta.error` — e.g.
 * `"Error converting data type nvarchar to int."` from /Reports/Reimbursement, and
 * ADO.NET / stack-shaped strings elsewhere. Those name internal types, columns and
 * frameworks, which is information disclosure and means nothing to a member. Anything
 * matching here is replaced with a generic message; the original is still attached to the
 * thrown ApiError (`.payload`) for logging and debugging.
 */
const INTERNAL_ERROR_SIGNATURE =
  /(nvarchar|varchar|sql|sqlexception|ado\.net|stack trace|at [A-Za-z0-9_.]+\.[A-Za-z0-9_]+\(|System\.|Microsoft\.|Npgsql|ORA-\d|constraint|column name|object reference not set|inner exception|\.cs:line)/i;

function innerErrorMessage(parsed: any, code: number): string {
  const raw = parsed?.meta?.error || parsed?.meta?.message || parsed?.message || parsed?.title;
  const msg = String(raw || "").trim();
  if (!msg) return `Request failed (${code})`;
  // Leaked internals, or a wall of text that is plainly not a user-facing sentence.
  if (INTERNAL_ERROR_SIGNATURE.test(msg) || msg.length > 200) {
    return code >= 500
      ? "The club server had a problem with that request. Please try again shortly."
      : "That request couldn't be completed. Please check your details and try again.";
  }
  return msg;
}

async function request<T>(path: string, opts: Options = {}): Promise<T> {
  const { method = "GET", body, signal, auth = true } = opts;
  const headers: Record<string, string> = { accept: "*/*" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (auth && authToken) headers["Authorization"] = "bearer " + authToken;

  let res: Response;
  try {
    res = await fetch(baseUrlFor(path) + path, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal,
    });
  } catch (e: any) {
    throw new ApiError(networkErrorMessage(e?.message, path), 0, null);
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
  if (isEnvelope(parsed)) return ((parsed as ApiEnvelope<T>).data ?? null) as T;
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
      res = await fetch(baseUrlFor(path) + path, { method: "POST", headers, body: form });
    } catch (e: any) {
      throw new ApiError(networkErrorMessage(e?.message, path), 0, null);
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
    if (isEnvelope(parsed)) return (parsed.data ?? null) as T;
    return parsed as T;
  },
  // Returns the full envelope (used by auth, which needs status + data together).
  raw: async (path: string, opts: Options = {}): Promise<ApiEnvelope<any>> => {
    const { method = "GET", body, auth = true } = opts;
    const headers: Record<string, string> = { accept: "*/*" };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (auth && authToken) headers["Authorization"] = "bearer " + authToken;
    let res: Response;
    try {
      res = await fetch(baseUrlFor(path) + path, {
        method,
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
    } catch (e: any) {
      // Login goes through here — this is where the certificate problem surfaces first.
      throw new ApiError(networkErrorMessage(e?.message, path), 0, null);
    }
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
