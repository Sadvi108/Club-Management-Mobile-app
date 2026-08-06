# System Design — Live Offers, Device Alerts, Academy Chat, Responsive Nav Bar
2026-07-02 · branch `feat/payments-phase1`

## 1. Requirements

**Functional**
1. Home "Featured Offer" section fully live: every offer from the backend, tappable, with a
   detail screen the student can show at the counter (offers are redeem-by-showing).
2. Notifications/alerts on any device: user gets an OS-level alert when new club
   notifications arrive, plus a live unread badge in the app.
3. Chat: students converse with club admin/instructor from inside the app, wired to the
   real API.
4. Bottom tab bar visible and correctly sized on every device (Android gesture nav,
   3-button nav, iOS home indicator, web).

**Constraints discovered by probing `Club.Api` (live, 2026-07-02)**
- Offers: only source is `GET /Reports/HomePageStats → data.myoffers[]`
  (`{code, name, description, expiryDate, attachments[].documentUrl, previewImages[]}`,
  all `id:0` → key by `code`). No dedicated offers/redeem endpoint.
- Notifications: `MyNotifications`, `MyUnreadNotificationCount`,
  `UpdateNotification2Read?id=` all live. **No push-token registration endpoint exists**
  → true server push (FCM/APNs) is impossible without backend changes.
- Chat: the backend's messaging layer IS the notification system.
  - `POST /Profile/Reply2Notification` (Notification body `{id:0, groupId, value, text}`) → 200,
    reply lands on the club admin's side. **The sender's own message is NOT retrievable**
    from any endpoint afterwards.
  - `POST /Profile/Send2ClubHelpDesk {text, value, notificationType}` → 200, same one-way
    behaviour (starts a new conversation on the admin web panel).
  - `GET /Profile/NotificationDetails/{groupId}` returns the **whole broadcast batch,
    including other students' rows** (verified: 32 rows, other students' names + fee
    amounts) → privacy leak; must NOT be shown in the UI.

## 2. High-level design

```
┌────────────────────────── app ──────────────────────────┐
│  NotificationsProvider (poll 60s foreground + on-focus)  │
│    ├── unreadCount → Home bell badge (live)              │
│    ├── new-item diff → local OS notification             │
│    └── background task (15 min, native APK) ─ same diff  │
│                                                          │
│  Home ── offers carousel ──► /offer-detail?code=F0001    │
│      └── View all ──► /events (offers tab, tappable)     │
│                                                          │
│  Quick Access "Chat Academy" ──► /chat (thread list)     │
│      └──► /chat-thread?g={groupId|helpdesk}              │
│             incoming = MY rows of that group             │
│             outgoing = local echo store (AsyncStorage)   │
│             send: Reply2Notification / Send2ClubHelpDesk │
└──────────────────────────────────────────────────────────┘
```

### Offers (live + workable)
- Home: horizontal carousel of ALL `myoffers` (was: only first one, dead "View all" tap
  target on the card). Tap → `app/offer-detail.tsx?code=X` — refetches HomePageStats,
  finds the offer by `code`, renders full image, description, validity, club, and a
  "show at counter" footer with the student name + offer code (that's how these offers
  are redeemed per their own description).
- `events.tsx` offer cards get `onPress` → same detail route.

### Notifications / device alerts
- **Why polling:** no token-registration endpoint → server can't push. Poll
  `MyNotifications` and diff by max `id`; on new items fire a **local** OS notification
  (expo-notifications on Android/iOS, `Notification` API on web). This produces real
  system-tray alerts on any device without backend changes.
- `src/notifications/service.ts` — permissions, Android channel, `presentAlert()`,
  `diffAndAlert()` (persisted `lastSeenId` per user).
- `src/notifications/NotificationsProvider.tsx` — context `{count, refresh}`; polls every
  60 s while app active, refreshes on foreground; tap on an OS notification deep-links to
  `/notifications`. Bell badge + notifications screen consume `refresh()` so mark-read
  updates everywhere.
- Background (closed app, native APK only): `expo-background-task` + `expo-task-manager`,
  min 15-min WorkManager interval; reads persisted session token, compares unread count,
  fires the same local alert. Best-effort (OS may throttle); documented trade-off.
- **Trade-off:** at-most ~60 s latency foreground, ~15 min background vs. zero backend
  work. Revisit: if backend ever adds device-token registration, swap the poller for FCM
  — the provider API (`count/refresh`) doesn't change.

### Chat ("Chat Academy")
- **Model:** conversation = notification `groupId`. Incoming messages = MY notification
  rows for that group (from `MyNotifications` — NOT `NotificationDetails`, which leaks
  other students). Outgoing = `Reply2Notification` + **local echo** persisted per
  user+thread in AsyncStorage (`dclix.chat.sent.v1.{userId}`), because the API never
  returns the sender's own messages.
- Pinned "Club Help Desk" thread (pseudo groupId `helpdesk`) → `Send2ClubHelpDesk`;
  admin replies arrive as new notification groups (poller alerts the student).
- `app/chat.tsx` thread list: Help Desk pinned + groups newest-first, unread dots.
  `app/chat-thread.tsx`: bubble UI, marks unread rows read on open, polls while open,
  optimistic send with failure retry.
- Quick-Access tile `chat` re-routed `/(tabs)/profile` → `/chat`.
- **Limitation (accepted):** own sent history lives on-device only; a re-install or
  second device won't show past sent bubbles (backend keeps no copy for the sender).
  Incoming side is always server-truth.

### Responsive tab bar
- Bug: `tabBarStyle` used fixed heights (`68` Android) with `position:"absolute"` and no
  bottom safe-area inset → Android system nav (3-button/gesture bar) overlaps the tabs
  (user screenshot). Fix: `useSafeAreaInsets()` → `height: 62 + insets.bottom`,
  `paddingBottom: max(insets.bottom, 10)`. Works on notched iOS (insets≈34), Android
  gesture (insets≈24), 3-button (insets≈48), web (0).

### Storage upgrade (enabler)
`src/api/storage.ts` was localStorage-on-web / **in-memory on native** → APK lost the
session and would lose chat echo on every restart. Switch to
`@react-native-async-storage/async-storage` behind the same tiny API (now async);
`auth.tsx` restore awaits it. Web keeps localStorage semantics via AsyncStorage's web impl.

## 3. What I'd revisit as it grows
- Backend adds push-token endpoint → replace poller with FCM (provider API stable).
- Backend adds "my sent messages" endpoint → drop local echo store.
- `NotificationDetails` privacy leak → report to backend owner; server should filter by
  the authenticated user.
