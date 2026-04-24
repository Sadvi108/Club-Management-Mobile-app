export const colors = {
  background: "#F8FAFC",
  surface: "#FFFFFF",
  surfaceAlt: "#F1F5F9",
  primary: "#4F46E5",
  primaryDark: "#4338CA",
  purple: "#9333EA",
  secondary: "#38BDF8",
  accent: "#F59E0B",
  textPrimary: "#0F172A",
  textSecondary: "#64748B",
  textMuted: "#94A3B8",
  textInverse: "#FFFFFF",
  border: "#E2E8F0",
  borderLight: "#F1F5F9",
  success: "#10B981",
  warning: "#F59E0B",
  danger: "#EF4444",
  gradient: ["#4F46E5", "#7C3AED", "#9333EA"] as const,
  gradientSoft: ["#EEF2FF", "#F5F3FF"] as const,
  gold: "#EAB308",
};

export const radius = {
  sm: 10,
  md: 14,
  lg: 18,
  xl: 22,
  xxl: 28,
  full: 9999,
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
};

export const shadow = {
  card: {
    shadowColor: "#0F172A",
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.06,
    shadowRadius: 16,
    elevation: 3,
  },
  soft: {
    shadowColor: "#0F172A",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 8,
    elevation: 2,
  },
  strong: {
    shadowColor: "#4F46E5",
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.25,
    shadowRadius: 18,
    elevation: 8,
  },
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
