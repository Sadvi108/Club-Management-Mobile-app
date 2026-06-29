import { useMemo } from "react";
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { api } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";
import { useAuth } from "../../src/api/auth";
import { notify } from "../../src/ui/dialogs";

type CollectionCounts = { cash: number; fpx: number; dbt: number };

export default function Collections() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const counts = useApi<CollectionCounts | null>(
    () => (token ? api.collectionCount() : Promise.resolve(null)),
    [token]
  );

  const fmtCount = (n?: number) => (counts.loading ? "…" : String(n ?? 0));

  const cards: {
    id: string;
    label: string;
    icon: keyof typeof Ionicons.glyphMap;
    count?: string;
    onPress: () => void;
  }[] = [
    {
      id: "cash",
      label: "Cash Payments",
      icon: "cash-outline",
      count: fmtCount(counts.data?.cash),
      onPress: () => notify("Cash Payments", "Detailed list is coming soon."),
    },
    {
      id: "online",
      label: "Online Payments",
      icon: "card-outline",
      count: fmtCount(counts.data?.fpx),
      onPress: () => notify("Online Payments", "Detailed list is coming soon."),
    },
    {
      id: "slips",
      label: "Payment Slips",
      icon: "document-attach-outline",
      count: fmtCount(counts.data?.dbt),
      onPress: () => notify("Payment Slips", "Detailed list is coming soon."),
    },
    {
      id: "update",
      label: "Update Collection",
      icon: "sync-outline",
      onPress: () => notify("Update Collection", "Coming soon."),
    },
  ];

  return (
    <View style={styles.root} testID="instructor-collections">
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <Text style={styles.title}>Collections</Text>
          <Text style={styles.subtitle}>Track payments received across your club</Text>
        </View>
      </SafeAreaView>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.grid}>
          {cards.map((c) => (
            <TouchableOpacity
              key={c.id}
              testID={`coll-${c.id}`}
              style={styles.card}
              onPress={c.onPress}
              activeOpacity={0.85}
            >
              <View style={styles.cardIcon}>
                <Ionicons name={c.icon} size={24} color={colors.primary} />
              </View>
              <Text style={styles.cardLabel} numberOfLines={2}>
                {c.count !== undefined ? `${c.label} (${c.count})` : c.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },

    header: { paddingHorizontal: spacing.xl, paddingTop: 8, paddingBottom: 12 },
    title: { ...font.h1, color: colors.textPrimary },
    subtitle: { ...font.body, color: colors.textSecondary, marginTop: 4 },

    grid: {
      flexDirection: "row",
      flexWrap: "wrap",
      paddingHorizontal: spacing.lg,
      paddingTop: spacing.md,
      justifyContent: "space-between",
      rowGap: spacing.lg,
    },
    card: {
      width: "47%",
      backgroundColor: colors.surface,
      borderRadius: radius.xl,
      paddingVertical: spacing.xl,
      paddingHorizontal: spacing.md,
      alignItems: "center",
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    cardIcon: {
      width: 56,
      height: 56,
      borderRadius: 28,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
      marginBottom: spacing.md,
    },
    cardLabel: {
      ...font.h4,
      color: colors.textPrimary,
      textAlign: "center",
      lineHeight: 20,
    },
  });
}
