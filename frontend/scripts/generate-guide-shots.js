// Captures the guide screenshots from the RUNNING app, so the guide always shows the
// real current UI rather than a hand-drawn approximation.
//
// PRIVACY: the test account is a real person on the live club system — the profile screen
// renders their name, registration code, phone number and a working member QR. None of
// that may ship inside the app. So the persisted user record is rewritten with demo
// identity BEFORE any screen is captured; the auth token is stored separately and is
// untouched, so the screens still load genuine data from the API.
const puppeteer = require("puppeteer-core");
const path = require("path");
const fs = require("fs");
const CHROME = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
// Writes straight into the bundled guide assets, downscaled for the app bundle.
const OUT = process.argv[2] || "assets/guide";
const SHOT_WIDTH = 480; // 2x the ~240pt the guide renders them at
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const DEMO = {
  name: "ALEX TAN",
  code: "DEMO1/KLG/2025/00042",
  icNo: "DEMOSTUDENT",
  handPhone: "012-345 6789",
  id: 12345, // drives the member QR, so it must be fake too
};

const SCREENS = [
  { key: "login", url: "/login", auth: false },
  { key: "home", url: "/home" },
  { key: "payments", url: "/payments" },
  { key: "schedule", url: "/schedule" },
  { key: "attendance", url: "/attendance" },
  { key: "notifications", url: "/notifications" },
  { key: "notification-settings", url: "/notification-settings" },
  { key: "profile", url: "/profile" },
  { key: "chat", url: "/chat" },
  { key: "more", url: "/more" },
  { key: "book-class", url: "/book-class" },
  // NOTE: /progress, /events and /purchases are deliberately absent. Cold-opening those
  // three fires their API calls before the auth token is restored, takes a 401, and the
  // global 401 handler wipes the session — so the capture lands on the sign-in screen.
  // Add them back once those screens gate their first fetch on `token`, the way
  // app/notifications.tsx already does.
];

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: "new",
    args: ["--no-sandbox", "--disable-gpu"],
  });
  const ctx = browser.defaultBrowserContext();
  await ctx.overridePermissions("http://localhost:8081", ["notifications"]);
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
  page.on("dialog", async (d) => { try { await d.dismiss(); } catch {} });

  // 1. The login shot must be taken before signing in.
  await page.goto("http://localhost:8081/login", { waitUntil: "domcontentloaded", timeout: 90000 });
  await sleep(7000);
  // In __DEV__ the login form prefills the real TEST CREDENTIALS. Those are an input
  // VALUE, not a text node, so the scrubber below cannot reach them — blank them here or
  // the guide ships a working username straight to every user.
  await page.evaluate(() => {
    const id = document.querySelector('[data-testid="login-id-input"]');
    const pw = document.querySelector('[data-testid="login-password-input"]');
    if (id) id.value = "alex.tan@email.com";
    if (pw) pw.value = "";
  });
  await sleep(300);
  await page.screenshot({ path: path.join(OUT, "login.png") });
  const credLeak = await page.evaluate(() =>
    Array.from(document.querySelectorAll("input")).map((i) => i.value).join(" ")
  );
  console.log("captured login" + (/DARSHANMUTHU|1234/.test(credLeak) ? "  !! CREDENTIAL STILL VISIBLE" : "  (credentials blanked)"));

  // 2. Sign in.
  await page.evaluate(() => document.querySelector('[data-testid="login-submit-button"]')?.click());
  await sleep(9000);

  // 3. Swap in demo identity, then reload so every screen renders it.
  const before = await page.evaluate((demo) => {
    const KEY = "dclix.user.v1";
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const u = JSON.parse(raw);
    const original = { name: u.name, code: u.code, phone: u.handPhone, id: u.id };
    Object.assign(u, demo);
    localStorage.setItem(KEY, JSON.stringify(u));
    return original;
  }, DEMO);
  console.log("sanitised identity, was:", JSON.stringify(before));
  if (!before) throw new Error("login did not persist a user record — aborting rather than shipping real data");

  await page.goto("http://localhost:8081/home", { waitUntil: "domcontentloaded", timeout: 60000 });
  await sleep(8000);

  // Patching the stored user is not enough: names also arrive from the API (the payee
  // chips on Payments come from /Profile/MySiblings, chat threads carry sender names).
  // So scrub the rendered TEXT NODES immediately before each capture — that catches every
  // visible occurrence whatever its source — and verify each screen individually.
  const rules = [
    [before.name, DEMO.name],
    [before.name.replace(/\s+/g, " "), DEMO.name],
    ["MUTHUSIGAMANI", "TAN"],
    ["DARSHAN", "ALEX"],
    [String(before.phone), DEMO.handPhone],
    [before.code, DEMO.code],
  ].filter(([from]) => from && String(from).length > 2);

  const scrub = (rs) =>
    page.evaluate((rules) => {
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      let n, hits = 0;
      while ((n = walker.nextNode())) {
        let t = n.nodeValue;
        for (const [from, to] of rules) {
          if (t.includes(from)) { t = t.split(from).join(to); hits++; }
        }
        if (t !== n.nodeValue) n.nodeValue = t;
      }
      return hits;
    }, rs);

  let leaks = 0;
  for (const s of SCREENS) {
    if (s.auth === false) continue;
    await page.goto("http://localhost:8081" + s.url, { waitUntil: "domcontentloaded", timeout: 60000 });
    await sleep(6500);
    const scrubbed = await scrub(rules);
    await sleep(300);
    await page.screenshot({ path: path.join(OUT, `${s.key}.png`) });

    // Per-screen verification — the whole point is that NOTHING real ships.
    const left = await page.evaluate((rules) => {
      const t = document.body.innerText;
      return rules.map(([from]) => from).filter((f) => t.includes(f));
    }, rules);
    if (left.length) { leaks++; console.log(`  !! ${s.key}: STILL LEAKING ${JSON.stringify(left)}`); }
    // A screen that redirected to the sign-in gate captured the wrong thing entirely.
    const bounced = page.url().includes("/login") || (await page.evaluate(() => /Sign In/i.test(document.body.innerText)));
    console.log(`captured ${s.key}${scrubbed ? `  (scrubbed ${scrubbed})` : ""}${bounced ? "  !! BOUNCED TO LOGIN" : ""}`);
  }
  console.log(leaks ? `FAILED: ${leaks} screen(s) still contain real data` : "leak check clean on ALL screens");
  if (leaks) process.exitCode = 1;
  await browser.close();

  // Downscale in place: captured at deviceScaleFactor 2 for sharpness, shipped at the
  // size the guide actually renders so the app bundle does not carry 12 full-res phones.
  const Jimp = require("jimp-compact");
  const { PNG } = require("pngjs");
  let total = 0;
  for (const f of fs.readdirSync(OUT).filter((f) => f.endsWith(".png"))) {
    const img = await Jimp.read(path.join(OUT, f));
    if (img.bitmap.width <= SHOT_WIDTH) { total += fs.statSync(path.join(OUT, f)).size; continue; }
    const h = Math.round((SHOT_WIDTH * img.bitmap.height) / img.bitmap.width);
    img.resize(SHOT_WIDTH, h, Jimp.RESIZE_BICUBIC);
    const png = new PNG({ width: SHOT_WIDTH, height: h });
    img.bitmap.data.copy(png.data);
    const buf = PNG.sync.write(png, { inputColorType: 6, inputHasAlpha: true, colorType: 2, deflateLevel: 9, filterType: -1 });
    fs.writeFileSync(path.join(OUT, f), buf);
    total += buf.length;
  }
  console.log(`guide assets: ${(total / 1024).toFixed(0)} KB total in ${OUT}`);
})();
