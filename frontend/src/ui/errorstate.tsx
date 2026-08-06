import { View, Text, StyleSheet, TouchableOpacity } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { radius, spacing, useTheme } from "../theme";

/**
 * Inline "this didn't load" banner with a retry.
 *
 * Exists because a failed fetch used to be indistinguishable from a genuinely empty result:
 * screens read `useApi().data` and ignored `.error`, so a dead network rendered "RM 0 due",
 * "No branches assigned." or "Rest Day". Anywhere a screen shows an empty state, it should
 * show this instead when `error` is set.
 */
export function ErrorState({
  message,
  onRetry,
  compact,
  testID,
}: {
  message?: string | null;
  onRetry?: () => void;
  compact?: boolean;
  testID?: string;
}) {
  const { colors } = useTheme();
  if (!message) return null;

  return (
    <View
      testID={testID || "error-state"}
      style={[
        styles.wrap,
        {
          backgroundColor: colors.surfaceAlt,
          borderColor: colors.border,
          paddingVertical: compact ? spacing.md : spacing.xl,
        },
      ]}
    >
      <Ionicons name="cloud-offline-outline" size={compact ? 20 : 28} color={colors.danger} />
      <Text style={[styles.msg, { color: colors.textSecondary, fontSize: compact ? 12 : 13 }]}>
        {message}
      </Text>
      {onRetry ? (
        <TouchableOpacity
          onPress={onRetry}
          activeOpacity={0.85}
          style={[styles.btn, { borderColor: colors.primary }]}
          testID="error-state-retry"
          hitSlop={8}
        >
          <Ionicons name="refresh" size={13} color={colors.primary} />
          <Text style={[styles.btnTxt, { color: colors.primary }]}>Try again</Text>
        </TouchableOpacity>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignItems: "center",
    gap: 8,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.md,
    borderWidth: 1,
  },
  msg: { textAlign: "center", fontWeight: "600", lineHeight: 18 },
  btn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: radius.full,
    borderWidth: 1,
    marginTop: 2,
  },
  btnTxt: { fontSize: 12, fontWeight: "800" },
});
