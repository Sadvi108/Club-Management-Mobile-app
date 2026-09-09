# D-CLIX — Club Management Mobile App

Expo / React Native app for martial-arts academies. Members sign in to check in to class by
QR, see their timetable, book sessions, pay fees, and message the club; instructors get
collections and reports instead.

The app is a **client only**. All data comes from the third-party **Club.Api** backend
(`apimac.zyncbook.com`), which this repository does not own or deploy.

> **Private repository.** The docs record live API contracts and account behaviour.

## Stack

| | |
|---|---|
| App | Expo SDK 54, Expo Router, React Native 0.81, TypeScript |
| Backend | Club.Api (ASP.NET, third-party) — REST + bearer JWT |
| Auth | Token in the OS secure store (Keychain / Keystore) |
| Android | `com.dclix.clubapp` |

## Getting started

```bash
cd frontend
npm install
cp .env.example .env      # public config only: which API host to use
```

### Run the web preview

From the **repository root** — this starts the Expo web server on `:8081` and the local
CORS proxy on `:8082` that the browser needs (the production API is plain HTTP and does not
send CORS headers):

```bash
node start-web.js
```

Then open <http://localhost:8081>. In VS Code, *Run and Debug → "Web preview (app + CORS
proxy)"* does the same thing.

Native builds call the API directly and do not use the proxy.

### Run on a device

```bash
cd frontend
npm run android      # or: npm run ios
```

## Layout

```
frontend/            the app
  app/               screens (Expo Router — file-based routing)
  src/api/           HTTP layer, endpoints, auth, storage
  src/notifications/ polling + local device alerts
  src/theme.ts       colours, spacing, typography
  assets/            icons, splash, notification sound, guide screenshots
  scripts/           dev tooling (see below)
docs/                architecture notes and dated API specs
start-web.js         web preview launcher (Expo + CORS proxy)
```

## Documentation

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — start here. API environments, endpoint
  contracts, and the backend quirks the screens work around. Several are non-obvious and
  documented because they cost real debugging time.
- **[docs/DESIGN.md](docs/DESIGN.md)** — visual language.
- **[docs/superpowers/specs/](docs/superpowers/specs/)** — dated design specs, including the
  security audit.

## Dev tooling

Scripts in `frontend/scripts/`, run from `frontend/`:

| Script | Purpose |
|---|---|
| `generate-icons.js` | Rebuilds launcher, splash and notification icons from `assets/branding/dclix-logo.png` |
| `generate-guide-shots.js` | Recaptures the in-app user-guide screenshots from the running app |
| `cors-proxy.js` | The web-preview proxy (started for you by `start-web.js`) |

## Releases

`.github/workflows/build-apk.yml` builds a release APK on GitHub Actions (Node 20, JDK 17,
`expo prebuild` + `gradlew assembleRelease`) and uploads it as a build artifact.

## Conventions

- TypeScript is strict; `npx tsc --noEmit` and `npm run lint` must both be clean.
- Comments explain *why*, especially where code works around a backend contract — don't
  remove those without checking the spec they reference.
