import { Platform } from "react-native";
import { storage } from "./storage";

// ─────────────────────────────────────────────────────────────────────────────
// API environments
//
// The same build can talk to more than one Club.Api server. Production is the
// live academy data; UAT/staging is the identical API (same 69 routes, byte-for-byte
// identical schemas) plus the new Boost payment gateway routes under /Bcpg.
//
// The environment is picked at runtime (persisted), so QA can flip a single build
// between servers without a rebuild. EXPO_PUBLIC_API_ENV / EXPO_PUBLIC_API_URL set
// the default for a build.
// ─────────────────────────────────────────────────────────────────────────────

export type ApiEnvKey = "prod" | "uat" | "custom";

export type ApiEnvironment = {
  key: ApiEnvKey;
  label: string;
  /** Real origin of the API (what native talks to, and what the web proxy forwards to). */
  baseUrl: string;
  hint: string;
  /** Server exposes the /Bcpg Boost gateway routes. */
  hasBoostGateway: boolean;
  /**
   * TLS certificate is not trusted by default clients. UAT serves the stock
   * self-signed Plesk certificate (CN=Plesk, no SAN for the host), so browsers and
   * Android/iOS reject it unless the cert is explicitly trusted. See
   * `frontend/plugins/withUatCertificate.js` (Android) and `scripts/cors-proxy.js` (web).
   */
  selfSignedCert: boolean;
};

const PROD: ApiEnvironment = {
  key: "prod",
  label: "Production",
  baseUrl: "http://apimac.zyncbook.com",
  hint: "Live academy data",
  hasBoostGateway: false,
  selfSignedCert: false,
};

const UAT: ApiEnvironment = {
  key: "uat",
  label: "UAT / Staging",
  baseUrl: "https://apimacuat.zyncbook.com",
  hint: "Same endpoints + Boost gateway (/Bcpg)",
  hasBoostGateway: true,
  selfSignedCert: true,
};

// EXPO_PUBLIC_API_URL still works: if it points at a server we don't know, it becomes
// a third "Custom" environment and is used as the default.
const CUSTOM_URL = (process.env.EXPO_PUBLIC_API_URL as string | undefined)?.replace(/\/+$/, "") || "";
const CUSTOM: ApiEnvironment | null =
  CUSTOM_URL && CUSTOM_URL !== PROD.baseUrl && CUSTOM_URL !== UAT.baseUrl
    ? {
        key: "custom",
        label: "Custom",
        baseUrl: CUSTOM_URL,
        hint: CUSTOM_URL,
        hasBoostGateway: true, // unknown — try /Bcpg and fall back if the route is missing
        selfSignedCert: CUSTOM_URL.startsWith("https://"),
      }
    : null;

export const API_ENVIRONMENTS: ApiEnvironment[] = [PROD, UAT, ...(CUSTOM ? [CUSTOM] : [])];

function envByKey(key: string | null | undefined): ApiEnvironment | null {
  return API_ENVIRONMENTS.find((e) => e.key === key) || null;
}

// Build-time default: EXPO_PUBLIC_API_ENV wins, then a custom EXPO_PUBLIC_API_URL,
// then an EXPO_PUBLIC_API_URL that matches a known server, then UAT.
// NOTE: flip DEFAULT_ENV back to PROD (or set EXPO_PUBLIC_API_ENV=prod) before a
// production release — this build defaults to UAT for Boost gateway testing.
const DEFAULT_ENV: ApiEnvironment =
  envByKey(process.env.EXPO_PUBLIC_API_ENV as string | undefined) ||
  CUSTOM ||
  API_ENVIRONMENTS.find((e) => e.baseUrl === CUSTOM_URL) ||
  UAT;

// The backend rejects CORS preflight (OPTIONS) on authenticated routes, so browser
// requests with an Authorization header are blocked, and the UAT certificate isn't
// browser-trusted either. Native apps have no CORS and call the API directly. For the
// web preview we route through a local pass-through proxy (see scripts/cors-proxy.js)
// that answers preflight, adds permissive CORS headers, and tolerates the UAT cert.
const WEB_PROXY = (process.env.EXPO_PUBLIC_WEB_API_PROXY as string | undefined)?.replace(/\/+$/, "");

const ENV_STORAGE_KEY = "dclix.apiEnv.v1";

let current: ApiEnvironment = DEFAULT_ENV;
const listeners = new Set<(env: ApiEnvironment) => void>();

export function getApiEnv(): ApiEnvironment {
  return current;
}

/** Real API origin (never the proxy) — used by the proxy and for display. */
export function getApiOrigin(): string {
  return current.baseUrl;
}

/**
 * Origin every request should be sent to. On web with a proxy configured this is
 * `<proxy>/@<envKey>` — the proxy strips the `/@key` prefix and forwards to that
 * environment's real origin, so switching environments needs no proxy restart.
 */
export function getApiBaseUrl(): string {
  if (Platform.OS === "web" && WEB_PROXY) return `${WEB_PROXY}/@${current.key}`;
  return current.baseUrl;
}

/** True when browser requests are going through the local dev proxy. */
export function isUsingWebProxy(): boolean {
  return Platform.OS === "web" && !!WEB_PROXY;
}

export function onApiEnvChange(fn: (env: ApiEnvironment) => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/** Switch environments at runtime and remember the choice. Callers must clear the session. */
export async function setApiEnv(key: ApiEnvKey): Promise<ApiEnvironment> {
  const next = envByKey(key);
  if (!next || next.key === current.key) return current;
  current = next;
  await storage.set(ENV_STORAGE_KEY, next.key);
  listeners.forEach((fn) => fn(next));
  return next;
}

/** Restore the persisted environment choice. Called once on app start, before any request. */
export async function restoreApiEnv(): Promise<ApiEnvironment> {
  try {
    const saved = envByKey(await storage.get(ENV_STORAGE_KEY));
    if (saved) {
      current = saved;
      listeners.forEach((fn) => fn(saved));
    }
  } catch {}
  return current;
}

/** @deprecated Environments are switchable at runtime — call getApiBaseUrl() instead. */
export const API_BASE_URL = getApiBaseUrl();
