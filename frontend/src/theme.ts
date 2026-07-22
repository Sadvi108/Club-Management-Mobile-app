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
};

// D-CLIX design system (INTEGRATION.md): Red · Black · White. One accent only — red; structure is
// black/white/neutral. Values mirror the token tables in §3; screens must consume these tokens,
// never hardcode a themed color.
export const lightColors: Palette = {
  background: "#FFFFFF",
  surface: "#FFFFFF",
  surfaceAlt: "#F6F6F7", // --surface-alt (neutral, not a brand wash)
  surfaceAlt2: "#EDEDEF",
  primary: "#E11D2A", // --dclix-red
  primaryDark: "#B10E18",
  primaryLight: "#F5333F",
  accent: "#F5333F",
  secondary: "#FCE9EA", // --primary-wash (pale red wash)
  textPrimary: "#0A0A0A",
  textSecondary: "#5B5B60",
  textMuted: "#9A9AA0",
  textInverse: "#FFFFFF",
  border: "#E6E6E8",
  borderLight: "#F1F1F3",
  success: "#16A34A",
  warning: "#F59E0B",
  danger: "#DC2626",
  gradient: ["#F5333F", "#E11D2A", "#B10E18"] as const,
  gradientSoft: ["#FDECEC", "#FCDDDE"] as const, // fees-due / dues card wash
  gold: "#F59E0B",
  overlay: "rgba(10,10,10,0.5)",
  cardShadowColor: "#141416",
  strongShadowColor: "#E11D2A", // red-tinted lift — CTAs/FAB only
};

export const darkColors: Palette = {
  background: "#000000", // dark bg = black (design rule #2)
  surface: "#141416",
  surfaceAlt: "#1E1E21",
  surfaceAlt2: "#26262A",
  primary: "#F5333F",
  primaryDark: "#E11D2A",
  primaryLight: "#FF5C66",
  accent: "#F5333F",
  secondary: "rgba(245,51,63,0.16)", // --primary-wash (dark)
  textPrimary: "#FFFFFF",
  textSecondary: "#A6A6AD",
  textMuted: "#6E6E76",
  textInverse: "#0A0A0A",
  border: "#2A2A2E",
  borderLight: "#202023",
  success: "#22C55E",
  warning: "#FBBF24",
  danger: "#F87171",
  gradient: ["#FF5C66", "#F5333F", "#B10E18"] as const,
  gradientSoft: ["#241416", "#2A181A"] as const,
  gold: "#FBBF24",
  overlay: "rgba(0,0,0,0.7)",
  cardShadowColor: "#000000",
  strongShadowColor: "#E11D2A",
};

export const radius = { sm: 10, md: 14, lg: 18, xl: 22, xxl: 28, full: 9999 };
export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32 };

export const makeShadow = (c: Palette) => ({
  // Softer, more diffuse elevation → cards feel like they float rather than sit on a hard edge.
  card: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.07,
    shadowRadius: 22,
    elevation: 4,
  },
  soft: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.05,
    shadowRadius: 12,
    elevation: 2,
  },
  strong: {
    shadowColor: c.strongShadowColor,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.26,
    shadowRadius: 24,
    elevation: 9,
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
