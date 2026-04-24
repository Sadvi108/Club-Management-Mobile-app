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

export const lightColors: Palette = {
  background: "#FFFFFF",
  surface: "#FFFFFF",
  surfaceAlt: "#FFF7ED",
  surfaceAlt2: "#FFEDD5",
  primary: "#F97316",
  primaryDark: "#EA580C",
  primaryLight: "#FB923C",
  accent: "#FB923C",
  secondary: "#FDBA74",
  textPrimary: "#0F172A",
  textSecondary: "#64748B",
  textMuted: "#94A3B8",
  textInverse: "#FFFFFF",
  border: "#F1F5F9",
  borderLight: "#F8FAFC",
  success: "#10B981",
  warning: "#F59E0B",
  danger: "#EF4444",
  gradient: ["#FB923C", "#F97316", "#EA580C"] as const,
  gradientSoft: ["#FFF7ED", "#FFEDD5"] as const,
  gold: "#F59E0B",
  overlay: "rgba(15,23,42,0.5)",
  cardShadowColor: "#0F172A",
  strongShadowColor: "#F97316",
};

export const darkColors: Palette = {
  background: "#0A0A0B",
  surface: "#17171A",
  surfaceAlt: "#1F1F23",
  surfaceAlt2: "#27272A",
  primary: "#FB923C",
  primaryDark: "#F97316",
  primaryLight: "#FDBA74",
  accent: "#FB923C",
  secondary: "#FDBA74",
  textPrimary: "#FAFAFA",
  textSecondary: "#A1A1AA",
  textMuted: "#71717A",
  textInverse: "#0A0A0B",
  border: "#27272A",
  borderLight: "#1F1F23",
  success: "#34D399",
  warning: "#FBBF24",
  danger: "#F87171",
  gradient: ["#FDBA74", "#F97316", "#EA580C"] as const,
  gradientSoft: ["#1F1F23", "#27272A"] as const,
  gold: "#FBBF24",
  overlay: "rgba(0,0,0,0.7)",
  cardShadowColor: "#000000",
  strongShadowColor: "#F97316",
};

export const radius = { sm: 10, md: 14, lg: 18, xl: 22, xxl: 28, full: 9999 };
export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32 };

export const makeShadow = (c: Palette) => ({
  card: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 16,
    elevation: 3,
  },
  soft: {
    shadowColor: c.cardShadowColor,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  strong: {
    shadowColor: c.strongShadowColor,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 18,
    elevation: 8,
  },
});

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
