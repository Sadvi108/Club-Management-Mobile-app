# UI/UX Page Design Spec (Desktop-first)

## Global Styles (applies to Login + API Test)
- **Design goals**: professional, minimal, consistent; strong hierarchy; predictable component behavior.
- **Layout system**: Desktop-first using responsive constraints.
  - Flutter guidance: use `LayoutBuilder` + max content width container; center content on wide screens.
  - Suggested breakpoints: Desktop ≥ 1024px, Tablet 768–1023px, Mobile < 768px.
- **Spacing scale**: 4 / 8 / 12 / 16 / 24 / 32.
- **Corner radius**: 12 (cards/inputs), 999 (pills if needed).
- **Elevation**: 0–2 levels only; avoid heavy shadows.
- **Typography** (via Google Fonts already included):
  - H1 28/32 semibold, H2 20/24 semibold, Body 14–16 regular, Caption 12.
- **Color tokens** (names; map to your brand colors):
  - Primary, OnPrimary, Surface, OnSurface, Outline, Error, Success.
- **Buttons**
  - Primary: full-height 48, strong fill, bold label.
  - Secondary: outlined/tonal.
  - States: default / pressed / disabled / loading (spinner inside button, label optional).
- **Text fields**
  - Label above field; helper/error text below.
  - Error state uses `Error` color + icon optional; do not rely on color only.
- **Feedback patterns**
  - Inline errors for form fields.
  - Non-blocking toast/snackbar for request-level outcomes.

---

## Page: Login

### Meta Information
- Title: Login
- Description: Sign in to access the app.
- Open Graph: Not applicable (mobile app screen).

### Page Structure
- Desktop: centered card layout.
  - Max width: 420–520px
  - Background: subtle `Surface` with low-contrast pattern/gradient optional.
- Tablet/Mobile: full-width with safe padding; card becomes flat section.

### Sections & Components
1. **Header (Brand block)**
   - Logo (48–64px) + app name.
   - Short helper text (1 line): “Sign in to continue”.
2. **Form Card**
   - Fields (top to bottom):
     - Email/Username input
     - Password input (with show/hide toggle)
   - Validation behavior:
     - On submit: show errors under fields; scroll to first error.
     - While typing: optionally clear error once corrected.
3. **Primary actions**
   - Primary button: “Log in” (full width).
   - Loading state: disable fields + show spinner.
4. **Error placement**
   - Authentication error appears as a compact inline banner above the button (not as a dialog).

### Interaction & States
- Keyboard: Enter submits.
- Focus ring: visible and consistent.
- Disabled: clear visual difference and prevents taps.

---

## Page: API Test

### Meta Information
- Title: API Test
- Description: Send a request and inspect the response.
- Open Graph: Not applicable.

### Page Structure
- Desktop: 2-column layout.
  - Left: Request builder (fixed width ~420–520px)
  - Right: Response viewer (flexes)
- Tablet/Mobile: stacked layout (Request above Response) with section headers.

### Sections & Components
1. **Top bar / Title row**
   - Page title: “API Test”
   - Optional small subtitle: “Send a request and view the response”.
2. **Request Builder (Card)**
   - Inputs grouped with clear labels:
     - Endpoint URL
     - Method selector (if present)
     - Headers (if present) in a compact key/value list style
     - Body (multiline) with monospace option
   - Helper text examples shown as faint placeholder text.
3. **Actions row**
   - Primary button: “Send request”.
   - Secondary: “Clear” (only if already present; otherwise omit).
   - Loading: show inline progress (button spinner + small “Sending…” text).
4. **Response Viewer (Card)**
   - Status summary row: Status code + duration.
   - Response body area:
     - Uses monospace font, line wrapping, and internal scroll.
     - Error responses are visually distinct (Error color accents) but readable.

### Interaction & States
- Persist last response until next send.
- Copy affordance (if already present): make it a small icon button in the response header.
- Empty state: “No response yet. Send a request to see results.”
