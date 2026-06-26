// Dev-only CORS pass-through proxy for the web preview.
// The Club.Api backend returns 401 to CORS preflight (OPTIONS) on authenticated routes,
// which makes browsers block the real request. This proxy answers preflight itself and
// forwards everything else to the upstream API, echoing back permissive CORS headers.
// Native (Android/iOS) builds bypass this entirely and call the API directly.
const http = require("http");

const UPSTREAM = process.env.PROXY_UPSTREAM || "http://apimac.zyncbook.com";
const PORT = Number(process.env.PROXY_PORT || 8082);

const server = http.createServer(async (req, res) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": req.headers["access-control-request-headers"] || "*",
    "Access-Control-Max-Age": "86400",
  };

  if (req.method === "OPTIONS") {
    res.writeHead(204, cors);
    res.end();
    return;
  }

  // Buffer the request body.
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", async () => {
    const body = Buffer.concat(chunks);
    const target = UPSTREAM + req.url;
    const headers = {};
    for (const [k, v] of Object.entries(req.headers)) {
      const lk = k.toLowerCase();
      if (["host", "origin", "referer", "connection", "content-length"].includes(lk)) continue;
      headers[k] = v;
    }
    try {
      const upstream = await fetch(target, {
        method: req.method,
        headers,
        body: ["GET", "HEAD"].includes(req.method) ? undefined : body,
      });
      const buf = Buffer.from(await upstream.arrayBuffer());
      const outHeaders = { ...cors };
      const ct = upstream.headers.get("content-type");
      if (ct) outHeaders["Content-Type"] = ct;
      res.writeHead(upstream.status, outHeaders);
      res.end(buf);
    } catch (e) {
      res.writeHead(502, { ...cors, "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "proxy_upstream_failed", message: String(e && e.message) }));
    }
  });
});

server.listen(PORT, () => {
  console.log(`CORS proxy listening on http://localhost:${PORT} → ${UPSTREAM}`);
});
