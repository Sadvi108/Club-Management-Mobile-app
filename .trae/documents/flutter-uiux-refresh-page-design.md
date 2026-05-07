# Flutter UI/UX Refresh — Page Design Spec (desktop-first)

## Global Styles
**Layout**: Desktop-first with centered content on wide screens.
- Desktop: max content width 1080–1200; use 12-col feel via padding + card grids.
- Tablet: 2-col where possible; reduce side padding.
- Mobile: single-column; bottom tabs always visible; safe-area padding.

**Design tokens (use consistently)**
- Spacing: 4/8/12/16/20/24/32 (map to `Gaps.*`).
- Radius: 10/14/18/22/28 (map to `Radii.*`).
- Elevation: prefer border + subtle shadow (`Shadows.card`) only for cards.

**Typography** (Poppins)
- Display: 28–32 / 800 (screen titles)
- H2: 18–20 / 700 (section titles)
- Body: 14–15 / 500–600
- Caption: 10–12 / 600
Rules: avoid ALL CAPS paragraphs; reserve caps for small labels with letterSpacing.

**Color usage (professional, less “noisy”)**
- Keep brand orange as primary, but restrict gradients to: Splash + key hero cards + primary CTAs.
- Use `surface`/`surfaceAlt` for most cards; ensure contrast in dark mode.

## Navigation & Core Components
- **AppHeader**: consistent top row (title left, optional action right). Use 42×42 circular icon buttons.
- **Bottom Tabs**: active state = filled icon + primary color + subtle indicator; labels at 10–11.
- **Center QR FAB**: one clear meaning (“Check-in”). Provide tooltip/label on desktop.
- **Card**: surface + radius (lg/xl) + border in dark mode.
- **Primary button**: 44–48 height, full-width in forms, gradient only for primary CTA.
- **Secondary button**: surfaceAlt background; never looks like disabled.
- **Empty state**: icon + short title + 1-line helper text.
- **Bottom sheet**: rounded top (28), drag handle, clear primary action.

---

## Page: Splash
**Meta**: Title “D-CLIX”.
**Structure**: full-screen gradient backdrop → centered logo animation → tagline + small loading text.
**Notes**: keep animation subtle; avoid multiple competing motion elements.

## Page: Login
**Meta**: Title “Login”.
**Structure**: header row (logo + theme toggle) → welcome text → auth card → alternative methods row.
**Key components**:
- Role segmented control (Student/Instructor) with clear selected state.
- Inputs: consistent label style, 44+ tap height, visible focus.
- Feedback: snackbars only for global errors; inline hints for field issues.

## Page: Main Tabs Shell
**Structure**: body content + BottomAppBar + center FAB.
**Rules**:
- Keep tab icon size consistent (22). Ensure label alignment and balanced spacing around notch.

## Page: Home
**Structure**: gradient header (avatar + membership + notifications) → overlapping quick bar → content sections.
**Sections**:
- “Fees due” CTA card: primary action clearly separated.
- “Today’s class” card: time/title/trainer + secondary “Check in”.
- “Quick access” grid: consistent 4-up on desktop, 2-up on mobile.

## Page: Training
**Structure**: header → streak hero card → program list cards → add program CTA.
**Rules**: program card actions align; info icon uses same 44×44 touch target.

## Page: Schedule
**Structure**: header → horizontal day picker → session list → holidays callout.
**States**:
- Rest day: centered empty state.
- Session card: clear primary info (title/time) + compact actions.

## Page: Payments
**Structure**: header → due hero card → quick pay row → payment history list.
**Pay bottom sheet**:
- Method list rows: icon + label + radio; selected row uses border+surfaceAlt.
- Primary action: “Confirm & Pay Securely” fixed at bottom of sheet content.

## Page: Profile
**Structure**: gradient header → overlapping virtual ID card → theme toggle card → logout.
**Rules**: logout is a destructive action style (danger color) with clear affordance.

## Page: Attendance
**Structure**: back header (with QR shortcut) → attendance hero gauge → calendar card → scan CTA → missed list.
**Accessibility**: present/missed/off statuses must be distinguishable beyond color (borders/icons).

## Page: Progress
**Structure**: back header → fitness hero → belt journey timeline card → skill breakdown card → achievements row → feedback list.
**Rules**: keep text density low; increase line-height for quotes.

## Page: Events
**Structure**: back header → segmented tabs → list (events or certificates).
**Event card**: image with gradient overlay; ensure title and key metadata remain readable.

## Page: QR Scan
**Structure**: full-screen camera (or fallback) + overlay + frame corners + laser → success state.
**States**:
- Scanning: instruction + torch action.
- Camera unavailable: show fallback message but keep same layout.
- Success: show check icon, scanned label, and single “Done” CTA.
