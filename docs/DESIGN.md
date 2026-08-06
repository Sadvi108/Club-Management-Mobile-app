# D-CLIX — App Design System (current)

Martial-arts / multi-sport **club-management** mobile app (students + instructors), Expo Router
React Native, wired to the live Club.Api backend. This documents the **shipped** design as of
**v2.5.0**. Everything is token-driven from `frontend/src/theme.ts` via a `useTheme()` context —
screens consume tokens, never hardcode themed colors.

**Theme:** Orange · White · Black. One brand accent (orange); structure is white/black/neutral;
semantic green/amber/red/blue only for status. Light + dark both first-class.

---

## 1. Color tokens

Consumed as `const { colors } = useTheme()` → `colors.primary`, etc. Two palettes, same keys.

### Brand & surfaces
| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#F97316` | `#FB923C` | brand accent, active icons, CTAs |
| `primaryDark` | `#EA580C` | `#F97316` | pressed / deep accent |
| `primaryLight` | `#FB923C` | `#FDBA74` | lighter accent |
| `accent` | `#FB923C` | `#FB923C` | secondary accent |
| `secondary` | `#FDBA74` | `#FDBA74` | soft accent / wash |
| `background` | `#FBFAF9` (warm paper) | `#0B0A0C` (warm black) | page bg |
| `surface` | `#FFFFFF` | `#1A191E` | cards, sheets, tab bar |
| `surfaceAlt` | `#FFF7ED` | `#232228` | tinted rows, chips, icon wells |
| `surfaceAlt2` | `#FFEDD5` | `#2B2A31` | second tint |

### Text
| Token | Light | Dark |
|---|---|---|
| `textPrimary` | `#0F172A` | `#FAFAFA` |
| `textSecondary` | `#5B6472` | `#A8A6AF` |
| `textMuted` | `#9AA1AC` | `#77757E` |
| `textInverse` | `#FFFFFF` | `#0A0A0B` |

### Lines, status, misc
| Token | Light | Dark |
|---|---|---|
| `border` | `#EBEDF0` | `#2E2C34` |
| `borderLight` | `#F4F5F7` | `#232228` |
| `success` | `#10B981` | `#34D399` |
| `warning` | `#F59E0B` | `#FBBF24` |
| `danger` | `#EF4444` | `#F87171` |
| `gold` | `#F59E0B` | `#FBBF24` |
| `overlay` (modal scrim) | `rgba(15,23,42,.5)` | `rgba(0,0,0,.7)` |

### Gradients
- `gradient` (all CTAs, headers, ID cards, FAB): light `#FB923C → #F97316 → #EA580C`, dark `#FDBA74 → #F97316 → #EA580C`. 135° diagonal (`start {0,0} end {1,1}`).
- `gradientSoft` (fees-due / dues card wash): light `#FFF7ED → #FFEDD5`, dark `#232228 → #2B2A31`.

### Liquid glass (frosted chrome)
Real blur via `expo-blur` `BlurView` + a translucent fill. Used on the **tab bar** and the
**QR-scan top bar**; reusable surface at `src/ui/glass.tsx` (`<Glass>`).
| Token | Light | Dark |
|---|---|---|
| `glassBg` | `rgba(255,255,255,.60)` | `rgba(26,25,30,.55)` |
| `glassBgStrong` | `rgba(255,255,255,.80)` | `rgba(26,25,30,.78)` |
| `glassBorder` | `rgba(255,255,255,.65)` | `rgba(255,255,255,.10)` |
| `glassTint` | `light` | `dark` |

---

## 2. Typography (`font`)

System font (no custom family loaded). Scale + weights:
| Style | Size | Weight | Tracking |
|---|---|---|---|
| `h1` | 28 | 800 | -0.5 |
| `h2` | 22 | 700 | -0.3 |
| `h3` | 18 | 700 | — |
| `h4` | 16 | 600 | — |
| `body` | 14 | 500 | — |
| `small` | 12 | 500 | — |
| `tiny` | 11 | 600 | +0.5 |

Eyebrows: 10–11px, weight 800, UPPERCASE, letter-spacing ~1–2.5. Prices/IDs use tabular-ish
bold. Numbers on gradient headers are white 800.

---

## 3. Spacing, radius, elevation, motion

- **Spacing** (`spacing`): xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32. Screen gutters `xl` (20). Card padding 14–16.
- **Radius** (`radius`): sm 10 · md 14 · lg 18 · xl 22 · xxl 28 · full 9999. Cards/sheets = `xl` (22); sheets top corners 28.
- **Shadow** (`makeShadow(colors)` → `shadow.*`): warm-tinted, diffuse "float".
  | Tier | Offset y | Opacity | Radius | Elevation | Use |
  |---|---|---|---|---|---|
  | `soft` | 4 | .07 | 14 | 3 | list rows, small cards |
  | `card` | 8 | .10 | 24 | 5 | standard cards |
  | `shade` | 14 | .16 | 30 | 8 | header-overlapping / hero cards |
  | `strong` | 12 | .30 | 26 | 10 | primary CTAs, FAB (orange-tinted) |
- **Motion** (`motion`): fast 150 · base 220 · slow 320 ms. Ease-out enter / ease-in exit, no bounce.
- **Press** (`press`): activeOpacity 0.85 (cards 0.9), scale 0.97. No color-shift on press.

---

## 4. Iconography
- **Set:** Ionicons (`@expo/vector-icons`). Outline = idle, filled = active. Sizes 16 / 18 / 22 / 24; FAB 30.
- **Color:** brand orange on surfaces, white on gradient headers.
- No emoji as structural icons. Scan FAB uses `scan-outline` (smooth viewfinder).

---

## 5. App shell & navigation
- **Phone frame** 375×812 baseline. Bottom **tab bar** is frosted glass (BlurView), 5 slots, sized to the real bottom safe-area inset; a **lifted center QR FAB** (−26px, gradient fill, white ring) sits visually 3rd-of-5 for both roles.
- **Role-aware tabs:**
  - **Student:** Home · Schedule · [Scan] · Payments · Profile.
  - **Instructor:** Home · Collections · [Scan] · Reports · Settings.
- **Gradient header:** orange gradient block, white text, translucent-white chips/icon-buttons/stat rows. Cards below overlap it with a negative top margin + `shade` shadow.
- **Bottom sheets:** slide up, 28px top corners, drag handle, `overlay` scrim; safe-area padded.
- **Grids:** student Quick Access 4-col; instructor Quick Access 3-col colored tiles; Collections 2-col.

---

## 6. Core components (patterns, not a formal library)
- **Cards** — `surface` bg, radius `xl`, `shadow.soft`/`card`/`shade`; dark mode adds a 1px `border` hairline.
- **Primary CTA** — gradient fill + `shadow.strong`, white bold label, optional Ionicon.
- **Stat tiles** — number (h-scale, 800) + label; on gradient headers use translucent-white wells.
- **Status pill** — dot + label; green `success` = Active, red `danger` = Inactive.
- **List rows** — icon well + label + value + chevron; 44pt min touch target.
- **Segmented control** — chips (gradient-active) for login roles; flat solid-primary tabs for Payments.
- **Skeletons** (`src/ui/skeleton.tsx`) — pulse shimmer placeholders shown while the backend is slow (reports, payments, notifications, chat, home stats).
- **Glass** (`src/ui/glass.tsx`) — frosted surface for chrome over content.

---

## 7. Content & voice
Warm, second-person, light martial-arts flavor ("Let's get you back on the mat."). Title Case
section titles; UPPERCASE tracked eyebrows ("WELCOME BACK", "FEES DUE"). Verb-first buttons
("Sign In", "Pay Now", "Check In"). Currency **RM**. No emoji. Domain nouns: Student/Instructor,
Club, Branch, Belt/Grade, Center, Invoice, Receipt, Grading, Tournament, Check-In.

---

## 8. Screens (all live-API driven, no mock data)
Login · Home (student + instructor dashboards) · Schedule + Book a Class · QR Check-In (camera) ·
Payments (Pay / Advance / History) · Profile + Virtual ID + Edit Profile · Notifications · Chat
Academy + Help Desk · Events/Offers + Offer detail · Progress/Belt · Attendance · Purchases ·
Instructor: Collections, Reports (17 report screens on a shared `reportkit` scaffold), New Student
approval · User Guide walkthrough.

---

## 9. Key rules (from prior bug-fixes)
1. **Token discipline** — every themed color is a `colors.*` token so it flips light/dark. Only fixed-on-gradient white (`#fff`, `rgba(255,255,255,…)`) may be literal.
2. **Safe areas** — headers, tab bar, fixed CTA bars all pad by the real inset (`useSafeAreaInsets` / `useBottomTabBarHeight`); scroll content clears fixed bars.
3. **Profile + club photos** — `user.profilePic` (student DP) and `user.clubPic` (club logo) render on home/profile/instructor-home with initials fallback.
4. **Responsive** — widths from `useWindowDimensions` (rotation-safe); verified 360×640 → 375×812 → landscape.
5. **Cross-platform dialogs** — `src/ui/dialogs.ts` (`confirmDialog`/`notify`/`safeBack`) because `Alert.alert` is a no-op on web.

---

*Source of truth: `frontend/src/theme.ts`. Ships in APK v2.5.0.*
