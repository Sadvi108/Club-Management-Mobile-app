import React, { useEffect, useMemo, useRef } from "react";
import { Animated, Easing, View, StyleSheet, type ViewStyle, type DimensionValue } from "react-native";
import { radius as R, spacing, useTheme } from "../theme";

// Shimmer skeletons shown while the backend is slow. One shared opacity pulse (0.5↔1) drives every
// placeholder so the whole screen breathes in sync — cheaper and calmer than per-box animations.
// Native-driver opacity → runs off the JS thread, so it stays smooth even while a request is inflight.

function usePulse() {
  const v = useRef(new Animated.Value(0.5)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(v, { toValue: 1, duration: 700, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(v, { toValue: 0.5, duration: 700, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [v]);
  return v;
}

// Base building block — a pulsing rounded rectangle.
export function Skeleton({
  width = "100%",
  height = 14,
  radius = 8,
  style,
}: {
  width?: DimensionValue;
  height?: number;
  radius?: number;
  style?: ViewStyle;
}) {
  const { colors, mode } = useTheme();
  const opacity = usePulse();
  return (
    <Animated.View
      style={[
        { width, height, borderRadius: radius, backgroundColor: mode === "dark" ? colors.surfaceAlt2 : colors.border, opacity },
        style,
      ]}
    />
  );
}

// A card-shaped placeholder that mirrors the app's real list rows (icon dot + two text lines + trailing).
export function SkeletonRow({ lines = 2 }: { lines?: number }) {
  const { colors, shadow, mode } = useTheme();
  const s = useMemo(() => rowStyles(colors, shadow, mode), [colors, shadow, mode]);
  return (
    <View style={s.card}>
      <Skeleton width={40} height={40} radius={20} />
      <View style={{ flex: 1, gap: 8 }}>
        <Skeleton width="62%" height={13} />
        {lines > 1 && <Skeleton width="88%" height={11} />}
        {lines > 2 && <Skeleton width="45%" height={11} />}
      </View>
      <Skeleton width={46} height={16} radius={6} />
    </View>
  );
}

// Drop-in replacement for a full-screen spinner: N stacked card rows.
export function SkeletonList({ rows = 6, lines = 2, style }: { rows?: number; lines?: number; style?: ViewStyle }) {
  return (
    <View style={[{ padding: spacing.xl, gap: 10 }, style]} testID="skeleton-list">
      {Array.from({ length: rows }).map((_, i) => (
        <SkeletonRow key={i} lines={lines} />
      ))}
    </View>
  );
}

// Header stat placeholder (three numbers) — used on Home while HomePageStats loads.
export function SkeletonStatRow() {
  return (
    <View style={{ flexDirection: "row", justifyContent: "space-between", gap: 16 }} testID="skeleton-stats">
      {[0, 1, 2].map((i) => (
        <View key={i} style={{ flex: 1, alignItems: "center", gap: 6 }}>
          <Skeleton width={34} height={20} radius={6} style={{ backgroundColor: "rgba(255,255,255,0.35)" }} />
          <Skeleton width={52} height={9} radius={4} style={{ backgroundColor: "rgba(255,255,255,0.25)" }} />
        </View>
      ))}
    </View>
  );
}

function rowStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    card: {
      flexDirection: "row",
      alignItems: "center",
      gap: 12,
      backgroundColor: colors.surface,
      borderRadius: R.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
  });
}
