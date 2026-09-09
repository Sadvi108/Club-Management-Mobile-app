// Dev-only CORS pass-through proxy for the web preview.
//
// Two things make browser calls to Club.Api impossible without it:
//  1. The backend returns 401 to CORS preflight (OPTIONS) on authenticated routes, so
//     browsers block the real request. This proxy answers preflight itself.
//  2. The UAT server (https://apimacuat.zyncbook.com) presents the stock self-signed Plesk
//     certificate, which no browser will accept. The proxy talks to it over HTTPS with
//     certificate verification disabled — a DEV-ONLY concession so QA can test the Boost
//     gateway before a real certificate is installed. Never do this in shipped code.
//
// Native (Android/iOS) builds bypass this entirely and call the API directly.
//
// Environment routing: the app requests `/@<envKey>/<path>` (see src/api/config.ts
// getApiBaseUrl). The prefix is stripped and the request forwarded to that environment's
// origin, so switching servers in the app needs no proxy restart. Requests without a
// prefix go to DEFAULT_KEY.
const http = require("http");
const https = require("https");
const { URL } = require("url");

const ENVIRONMENTS = {
  prod: "http://apimac.zyncbook.com",
  uat: "https://apimacuat.zyncbook.com",
};
// EXPO_PUBLIC_API_URL / PROXY_UPSTREAM can add a third target reachable at /@custom/.
const CUSTOM = (process.env.PROXY_UPSTREAM || process.env.EXPO_PUBLIC_API_URL || "").replace(/\/+$/, "");
if (CUSTOM && !Object.values(ENVIRONMENTS).includes(CUSTOM)) ENVIRONMENTS.custom = CUSTOM;

const DEFAULT_KEY = process.env.PROXY_DEFAULT_ENV || (CUSTOM && ENVIRONMENTS.custom ? "custom" : "uat");
const PORT = Number(process.env.PROXY_PORT || 8082);

/** Split `/@uat/Account/Authenticate` into { upstream, path }. */
function route(reqUrl) {
  const m = /^\/@([a-z0-9_-]+)(\/.*)?$/i.exec(reqUrl);
  if (m && ENVIRONMENTS[m[1]]) return { key: m[1], upstream: ENVIRONMENTS[m[1]], path: m[2] || "/" };
  return { key: DEFAULT_KEY, upstream: ENVIRONMENTS[DEFAULT_KEY], path: reqUrl };
}

const server = http.createServer((req, res) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": req.headers["access-control-request-headers"] || "*",
    "Access-Control-Expose-Headers": "content-disposition,content-type",
    "Access-Control-Max-Age": "86400",
  };

  if (req.method === "OPTIONS") {
    res.writeHead(204, cors);
    res.end();
    return;
  }

  // Buffer the request body (multipart payment slips / profile photos included).
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    const body = Buffer.concat(chunks);
    const { upstream, path } = route(req.url);
    const target = new URL(upstream + path);

    const headers = {};
    for (const [k, v] of Object.entries(req.headers)) {
      const lk = k.toLowerCase();
      if (["host", "origin", "referer", "connection", "content-length", "accept-encoding"].includes(lk)) continue;
      headers[k] = v;
    }
    if (body.length) headers["content-length"] = String(body.length);

    forward(target, req.method, headers, body, res, cors, 0);
  });

  // The API answers plain HTTP with a 301 to HTTPS. Follow that here instead of handing
  // the browser a redirect it would then reject on the certificate.
  function forward(target, method, headers, body, res, cors, depth) {
    const client = target.protocol === "https:" ? https : http;
    const upReq = client.request(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port || (target.protocol === "https:" ? 443 : 80),
        path: target.pathname + target.search,
        method,
        headers,
        // DEV ONLY — the UAT host serves a self-signed Plesk certificate.
        rejectUnauthorized: false,
      },
      (upRes) => {
        const status = upRes.statusCode || 502;
        if ([301, 302, 307, 308].includes(status) && upRes.headers.location && depth < 3) {
          upRes.resume(); // drain
          const next = new URL(upRes.headers.location, target);
          // 301/302 on POST classically degrade to GET; 307/308 preserve the method.
          const keep = status === 307 || status === 308;
          forward(next, keep ? method : method === "POST" ? "GET" : method, headers, keep ? body : Buffer.alloc(0), res, cors, depth + 1);
          return;
        }
        const outHeaders = { ...cors };
        for (const h of ["content-type", "content-disposition", "cache-control"]) {
          if (upRes.headers[h]) outHeaders[h] = upRes.headers[h];
        }
        res.writeHead(status, outHeaders);
        upRes.pipe(res);
      }
    );

    upReq.on("error", (e) => {
      if (!res.headersSent) {
        try {
          res.writeHead(502, { ...cors, "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "proxy_upstream_failed", target: target.href, message: String(e && e.message) }));
        } catch {}
      } else {
        try { res.destroy(e); } catch {}
      }
    });

    if (body.length) upReq.write(body);
    upReq.end();
  }
});

process.on("uncaughtException", (err) => {
  console.error("CORS proxy non-fatal error:", err?.message || err);
});

// Bind to loopback ONLY. `server.listen(PORT)` with no host binds 0.0.0.0, which put this
// dev proxy on every network interface — anyone on the same Wi-Fi could relay requests to
// the live production API through the developer's machine (and it forwards the caller's
// Authorization header upstream). The log line always claimed localhost; now it is true.
const HOST = process.env.PROXY_HOST || "127.0.0.1";
server.listen(PORT, HOST, () => {
  console.log(`CORS proxy listening on http://${HOST}:${PORT}`);
  for (const [k, v] of Object.entries(ENVIRONMENTS)) {
    console.log(`  /@${k}${k === DEFAULT_KEY ? " (default)" : ""} → ${v}`);
  }
});
