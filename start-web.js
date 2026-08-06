// Launcher for the web preview: starts the CORS proxy (:8082) + Expo web (:8081).
//
// The browser needs the proxy because the backend rejects CORS preflight on authenticated
// routes and the UAT host serves a self-signed certificate. Native builds call the API
// directly and don't need any of this.
//
// Run from the repo root:  node start-web.js
const { spawn } = require("child_process");
const path = require("path");

const frontend = path.join(__dirname, "frontend");
const cli = path.join(frontend, "node_modules", "expo", "bin", "cli");
const proxy = path.join(frontend, "scripts", "cors-proxy.js");

// 1) Local CORS proxy (web preview → live API) on :8082
const proxyProc = spawn(process.execPath, [proxy], { cwd: frontend, stdio: "inherit", env: process.env });

// 2) Expo web dev server on :8081
const expoProc = spawn(process.execPath, [cli, "start", "--web", "--port", "8081"], {
  cwd: frontend,
  stdio: "inherit",
  env: process.env,
});

function shutdown(code) {
  try { proxyProc.kill(); } catch {}
  process.exit(code ?? 0);
}
expoProc.on("exit", shutdown);
process.on("SIGTERM", () => shutdown(0));
process.on("SIGINT", () => shutdown(0));
