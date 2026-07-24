import React from "react";
import { View, StyleSheet, Platform, type ViewStyle } from "react-native";
import { BlurView } from "expo-blur";
import { useTheme, radius as R } from "../theme";

// Liquid-glass surface: real frosted blur (expo-blur) + a translucent brand-tinted fill and a
// hairline highlight border. Use for floating chrome that overlaps content or the gradient —
// tab bar, sticky bars, bottom sheets, and cards that sit over the header.
export function Glass({
  children,
  style,
  intensity = 40,
  strong = false,
  radius = R.xl,
}: {
  children?: React.ReactNode;
  style?: ViewStyle;
  intensity?: number;
  strong?: boolean;
  radius?: number;
}) {
  const { colors, mode } = useTheme();
  const fill = strong ? colors.glassBgStrong : colors.glassBg;

  // react-native-web's BlurView maps to backdrop-filter; on native it's a true blur layer.
  return (
    <View style={[{ borderRadius: radius, overflow: "hidden", borderWidth: 1, borderColor: colors.glassBorder }, style]}>
      <BlurView
        intensity={intensity}
        tint={mode === "dark" ? "dark" : "light"}
        style={StyleSheet.absoluteFill}
      />
      {/* tint + subtle top highlight over the blur */}
      <View style={[StyleSheet.absoluteFill, { backgroundColor: fill }]} pointerEvents="none" />
      {Platform.OS !== "android" && (
        <View
          pointerEvents="none"
          style={[
            StyleSheet.absoluteFill,
            { borderTopWidth: 1, borderTopColor: mode === "dark" ? "rgba(255,255,255,0.12)" : "rgba(255,255,255,0.7)", borderRadius: radius },
          ]}
        />
      )}
      <View style={{ position: "relative" }}>{children}</View>
    </View>
  );
}
