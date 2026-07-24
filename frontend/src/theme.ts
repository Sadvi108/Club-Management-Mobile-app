import React, { createContext, useContext, useMemo, useState } from "react";

type Palette = {
  background: string;
  surface: string;
  surfaceAlt: string;
  surfaceAlt2: string;
  primary: string;
  primaryDark: string;
  primaryLight: string;
  accent: string;
  secondary: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  textInverse: string;
  border: string;
  borderLight: string;
  success: string;
  warning: string;
  danger: string;
  gradient: readonly [string, string, string];
  gradientSoft: readonly [string, string];
  gold: string;
  overlay: string;
  cardShadowColor: string;
  strongShadowColor: string;
  // Liquid-glass (frosted chrome): translucent fills + BlurView tint for tab bar, sheets,
  // and cards that overlap the gradient header.
  glassBg: string;
  glassBgStrong: string;
  glassBorder: string;
  glassTint: "light" | "dark" | "default";
};

// Internal color grading: brand orange (primary + gradient) is UNCHANGED. What's graded is the
// neutral ramp around it — a barely-warm page tint so white cards lift off the background, and
// slightly stronger borders so surfaces separate without heavier shadows. Same theme, more depth.
export const lightColors: Palette = {
  background: "#FBFAF9", // warm paper white (was pure #FFF) → white surfaces now read as elevated
  surface: "#FFFFFF",
  surfaceAlt: "#FFF7ED",
  surfaceAlt2: "#FFEDD5",
  primary: "#F97316",
  primaryDark: "#EA580C",
  primaryLight: "#FB923C",
  accent: "#FB923C",
  secondary: "#FDBA74",
  textPrimary: "#0F172A",
  textSecondary: "#5B6472", // nudged darker for crisper AA contrast on white
  textMuted: "#9AA1AC",
  textInverse: "#FFFFFF",
  border: "#EBEDF0", // a touch stronger than #F1F5F9 so card edges are visible on the warm bg
  borderLight: "#F4F5F7",
  success: "#10B981",
  warning: "#F59E0B",
  danger: "#EF4444",
  gradient: ["#FB923C", "#F97316", "#EA580C"] as const,
  gradientSoft: ["#FFF7ED", "#FFEDD5"] as const,
  gold: "#F59E0B",
  overlay: "rgba(15,23,42,0.5)",
  cardShadowColor: "#1E1B18", // warm-tinted shadow (was cold slate) so elevation matches the brand
  strongShadowColor: "#F97316",
  glassBg: "rgba(255,255,255,0.60)",
  glassBgStrong: "rgba(255,255,255,0.80)",
  glassBorder: "rgba(255,255,255,0.65)",
  glassTint: "light",
};

export const darkColors: Palette = {
  background: "#0B0A0C", // faint warm cast (was neutral #0A0A0B) to match the orange brand
  surface: "#1A191E", // lifted a step so cards separate from the background
  surfaceAlt: "#232228",
  surfaceAlt2: "#2B2A31",
  primary: "#FB923C",
  primaryDark: "#F97316",
  primaryLight: "#FDBA74",
  accent: "#FB923C",
  secondary: "#FDBA74",
  textPrimary: "#FAFAFA",
  textSecondary: "#A8A6AF",
  textMuted: "#77757E",
  textInverse: "#0A0A0B",
  border: "#2E2C34", // more visible dividers in dark mode
  borderLight: "#232228",
  success: "#34D399",
  warning: "#FBBF24",
  danger: "#F87171",
  gradient: ["#FDBA74", "#F97316", "#EA580C"] as const,
  gradientSoft: ["#232228", "#2B2A31"] as const,
  gold: "#FBBF24",
  overlay: "rgba(0,0,0,0.7)",
  cardShadowColor: "#000000",
  strongShadowColor: "#F97316",
  glassBg: "rgba(26,25,30,0.55)",
  glassBgStrong: "rgba(26,25,30,0.78)",
  glassBorder: "rgba(255,255,255,0.10)",
  glassTint: "dark",
};

export const radius = { sm: 10, md: 14, lg: 18, xl: 22, xxl: 28, full: 9999 };
export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32 };

export const makeShadow = (c: Palette) => ({
  // Diffuse elevation → cards float rather than sit on a hard edge. Deepened for more "shade".
  card: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.1,
    shadowRadius: 24,
    elevation: 5,
  },
  soft: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.07,
    shadowRadius: 14,
    elevation: 3,
  },
  // Deeper ambient shade for hero/elevated surfaces that need real presence.
  shade: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 14 },
    shadowOpacity: 0.16,
    shadowRadius: 30,
    elevation: 8,
  },
  strong: {
    shadowColor: c.strongShadowColor,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.3,
    shadowRadius: 26,
    elevation: 10,
  },
});

// Motion + press tokens — one rhythm for the whole app so interactions feel unified and smooth.
// Durations in ms (Material micro-interaction range). Use with Animated / LayoutAnimation.
export const motion = {
  fast: 150,
  base: 220,
  slow: 320,
};

// Standard press feedback for tappable cards/buttons: a slightly stronger dim + a subtle
// scale-down that reads as "pressed" without shifting surrounding layout.
export const press = {
  activeOpacity: 0.85,
  cardActiveOpacity: 0.9,
  scale: 0.97,
};

export const font = {
  h1: { fontSize: 28, fontWeight: "800" as const, letterSpacing: -0.5 },
  h2: { fontSize: 22, fontWeight: "700" as const, letterSpacing: -0.3 },
  h3: { fontSize: 18, fontWeight: "700" as const },
  h4: { fontSize: 16, fontWeight: "600" as const },
  body: { fontSize: 14, fontWeight: "500" as const },
  small: { fontSize: 12, fontWeight: "500" as const },
  tiny: { fontSize: 11, fontWeight: "600" as const, letterSpacing: 0.5 },
};

// Back-compat: static light colors / shadow for any call site not yet migrated
export const colors = lightColors;
export const shadow = makeShadow(lightColors);

export const LOGO_URL =
  "https://customer-assets.emergentagent.com/job_training-portal-126/artifacts/d0r3ioz1_dclix%20logo%202026.png";

// ── Theme Context ──────────────────────────────────────────────────────────
type ThemeMode = "light" | "dark";
type ThemeCtx = {
  mode: ThemeMode;
  colors: Palette;
  shadow: ReturnType<typeof makeShadow>;
  toggle: () => void;
  setMode: (m: ThemeMode) => void;
};

const Ctx = createContext<ThemeCtx | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setMode] = useState<ThemeMode>("light");
  const value = useMemo<ThemeCtx>(() => {
    const palette = mode === "light" ? lightColors : darkColors;
    return {
      mode,
      colors: palette,
      shadow: makeShadow(palette),
      toggle: () => setMode((m) => (m === "light" ? "dark" : "light")),
      setMode,
    };
  }, [mode]);
  return React.createElement(Ctx.Provider, { value }, children);
}

export function useTheme(): ThemeCtx {
  const v = useContext(Ctx);
  if (!v) {
    // Safe fallback (shouldn't happen in app tree)
    return {
      mode: "light",
      colors: lightColors,
      shadow: makeShadow(lightColors),
      toggle: () => {},
      setMode: () => {},
    };
  }
  return v;
}
