# ADR-001: App Hardening Audit

**Status:** Accepted (logging + test actioned; HTTPS blocked on backend; rest deferred)
**Date:** 2026-06-03
**Deciders:** App owner

## Context

Full-app pass after the feature work. Audited the Flutter client
(`club_management_app/lib`, 22 screens, ~14.5k LOC) for security,
correctness, and maintainability. Findings, by severity:

1. **Network logging leaked PII in release.** `api_service.dart` had 17
   bare `print()` calls dumping request URLs and **full response bodies**
   (IC numbers, names, payment/invoice data, contact numbers) to logcat —
   active in release builds. The bearer token was only partially redacted.
2. **Cleartext transport.** `baseUrl = http://apimac.zyncbook.com` — token
   + PII travel unencrypted. Probed `https://` → `SEC_E_WRONG_PRINCIPAL`
   (server TLS cert does not match the hostname). HTTPS is **not usable
   from the client** until the backend fixes its certificate.
3. **One analyzer error.** `test/widget_test.dart` still referenced the
   Flutter counter template (`MyApp`, counter `0`/`1`) — `MyApp` doesn't
   exist (entry class is `DClixApp`). 172 analyzer issues total; this was
   the only `error`, the rest are warnings/info (deprecations, unused).
4. **Large files.** `home_screen.dart` (1251), `payments_screen.dart`
   (1247), `user_session.dart` (1154) exceed a comfortable single-file
   size.
5. **`withOpacity` deprecation.** 25 files use `withOpacity` (deprecated
   for `withValues` in Flutter ≥3.27) — cosmetic, no runtime impact yet.

## Decision

Action the two safe, high-value items now; document the rest.

- **Gate all network logging behind `kDebugMode`.** Added `ApiService._log`
  that no-ops in release; replaced all 18 `print()`s. Release builds emit
  no request/response data.
- **Replace the broken template test** with foundation smoke tests
  (theme builds + a themed scaffold renders). Clears the lone analyzer
  error; CI stays green.
- **HTTPS:** raise with the backend — the server must serve a valid cert
  for `apimac.zyncbook.com`. One-line client change (`http`→`https`) once
  it does. Not actionable client-side now.

## Options Considered

### Logging
| Option | Assessment |
|---|---|
| A. Gate behind `kDebugMode` (chosen) | Low complexity, removes leak, keeps debug visibility |
| B. Remove logs entirely | Loses debug aid |
| C. Structured logger pkg | Over-engineered for this app |

### HTTPS
| Option | Assessment |
|---|---|
| A. Switch to `https://` now | **Breaks** — cert principal mismatch |
| B. Pin/allow bad cert client-side | Insecure, defeats the point — rejected |
| C. Backend fixes cert, then flip (chosen) | Correct; blocked on server |

## Trade-off Analysis

Logging + test are isolated, reversible, and unblock release safety with
zero feature risk. HTTPS is the highest-severity finding but is a
**server** defect; forcing it client-side would either break the app or
require disabling cert validation (worse than the status quo). File splits
and the `withOpacity` sweep are churn with no user-visible benefit; defer
until a screen is being reworked anyway.

## Consequences

- Easier: release builds no longer leak PII to device logs.
- Easier: CI/`flutter test` no longer carries a guaranteed failure.
- Harder/unchanged: transport stays cleartext until the backend cert is
  fixed — track as an external dependency.
- Revisit: split the 3 large files opportunistically; run a
  `withOpacity → withValues` codemod when bumping Flutter.

## Action Items

1. [x] Gate `api_service` logging behind `kDebugMode`.
2. [x] Replace `widget_test.dart` template with real smoke tests.
3. [ ] Backend: serve a valid TLS cert for `apimac.zyncbook.com`, then
   change `baseUrl` to `https://` (1 line).
4. [ ] Opportunistic: split `home_screen` / `payments_screen` /
   `user_session` when next edited.
5. [ ] Flutter-bump chore: `withOpacity` → `withValues` across 25 files.
