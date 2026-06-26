import { Platform } from "react-native";

// Base URL for the live Club.Api backend.
// Override with EXPO_PUBLIC_API_URL in frontend/.env (Expo inlines EXPO_PUBLIC_* at build time).
// NOTE: backend is plain HTTP. Fine for web preview + Android. iOS release builds need an
// ATS exception (NSAppTransportSecurity) or an HTTPS origin.
const DIRECT_URL =
  (process.env.EXPO_PUBLIC_API_URL as string | undefined)?.replace(/\/+$/, "") ||
  "http://apimac.zyncbook.com";

// The backend rejects CORS preflight (OPTIONS) on authenticated routes, so browser
// requests with an Authorization header are blocked. Native apps have no CORS and call
// the API directly. For the web preview we route through a local pass-through proxy that
// answers preflight and adds permissive CORS headers (see frontend/scripts/cors-proxy.js).
const WEB_PROXY = (process.env.EXPO_PUBLIC_WEB_API_PROXY as string | undefined)?.replace(/\/+$/, "");

export const API_BASE_URL = Platform.OS === "web" && WEB_PROXY ? WEB_PROXY : DIRECT_URL;
