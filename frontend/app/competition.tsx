import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import type { TournamentRow } from "../src/api/types";

const tabs = ["Upcoming", "Past"];

export default function Competition() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const { token } = useAuth();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const [tab, setTab] = useState<number>(0);
  const [selectedName, setSelectedName] = useState<string>("");

  const { data, loading, error, reload } = useApi<TournamentRow[]>(
    () => (token ? (api.tournamentSummary({ fromDate: null, toDate: null }) as Promise<TournamentRow[]>) : Promise.resolve([])),
    [token]
  );

  const allRows = useMemo(() => (Array.isArray(data) ? data : []), [data]);

  // Unique tournament names for filter dropdown/pills
  const nameOptions = useMemo(() => {
    const seen = new Set<string>();
    const opts: string[] = [];
    allRows.forEach((r) => {
      const n = (r.name || "").trim();
      if (n && !seen.has(n)) {
        seen.add(n);
        opts.push(n);
      }
    });
    return opts;
  }, [allRows]);

  const filteredRows = useMemo(() => {
    let rows = allRows;
    if (selectedName) {
      rows = rows.filter((r) => (r.name || "").trim() === selectedName);
    }
    return rows;
  }, [allRows, selectedName]);

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="competition-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Competition</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      {/* Segmented Control: Upcoming vs Past */}
      <View style={styles.tabsRow}>
        {tabs.map((t, i) => (
          <TouchableOpacity
            key={t}
            style={[styles.tab, tab === i && styles.tabActive]}
            onPress={() => setTab(i)}
            testID={`competition-tab-${i}`}
            activeOpacity={0.8}
          >
            <Ionicons
              name={i === 0 ? "time-outline" : "trophy-outline"}
              size={16}
              color={tab === i ? "#fff" : colors.textSecondary}
              style={{ marginRight: 6 }}
            />
            <Text style={[styles.tabTxt, tab === i && styles.tabTxtActive]}>{t} Competition</Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Filter by Tournament Name if options exist */}
      {nameOptions.length > 0 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={{ paddingHorizontal: spacing.xl, paddingVertical: 6, gap: 8 }}
        >
          <TouchableOpacity
            style={[styles.filterPill, !selectedName && styles.filterPillActive]}
            onPress={() => setSelectedName("")}
          >
            <Text style={[styles.filterPillTxt, !selectedName && styles.filterPillTxtActive]}>All</Text>
          </TouchableOpacity>
          {nameOptions.map((name) => (
            <TouchableOpacity
              key={name}
              style={[styles.filterPill, selectedName === name && styles.filterPillActive]}
              onPress={() => setSelectedName(selectedName === name ? "" : name)}
            >
              <Text style={[styles.filterPillTxt, selectedName === name && styles.filterPillTxtActive]} numberOfLines={1}>
                {name}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      )}

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={reload} colors={[colors.primary]} />}
      >
        {loading && !data && (
          <View style={styles.centerContainer}>
            <ActivityIndicator size="large" color={colors.primary} />
            <Text style={styles.loadingTxt}>Loading competitions...</Text>
          </View>
        )}

        {error && !loading && (
          <View style={styles.centerContainer}>
            <Ionicons name="alert-circle-outline" size={40} color={colors.danger} />
            <Text style={styles.errorTxt}>Failed to load competition data.</Text>
            <TouchableOpacity style={styles.retryBtn} onPress={reload}>
              <Text style={styles.retryTxt}>Tap to retry</Text>
            </TouchableOpacity>
          </View>
        )}

        {!loading && !error && filteredRows.length === 0 && (
          <View style={styles.centerContainer}>
            <Ionicons name="medal-outline" size={48} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>
              {tab === 0 ? "No upcoming competitions scheduled right now." : "No past competition records found."}
            </Text>
          </View>
        )}

        {!loading &&
          !error &&
          filteredRows.map((t: TournamentRow, i: number) => {
            const displayName = t.name?.trim() || t.category?.trim() || t.gender?.trim() || "Club Competition";
            return (
              <View key={`${t.id}-${i}`} style={styles.card} testID={`competition-card-${i}`}>
                <View style={styles.cardHead}>
                  <View style={styles.iconCircle}>
                    <Ionicons name="medal" size={22} color="#DB2777" />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.cardTitle} numberOfLines={2}>
                      {displayName}
                    </Text>
                    {!!t.ageGroup && <Text style={styles.cardSub}>Age Group: {t.ageGroup}</Text>}
                  </View>
                  <View style={styles.statusBadge}>
                    <Text style={styles.statusTxt}>{tab === 0 ? "UPCOMING" : "COMPLETED"}</Text>
                  </View>
                </View>

                <View style={styles.detailsRow}>
                  {!!t.gender && (
                    <View style={styles.tagPill}>
                      <Ionicons name="person-outline" size={12} color={colors.textSecondary} />
                      <Text style={styles.tagTxt}>{t.gender}</Text>
                    </View>
                  )}
                  {t.playerCount != null && (
                    <View style={styles.tagPill}>
                      <Ionicons name="people-outline" size={12} color={colors.textSecondary} />
                      <Text style={styles.tagTxt}>{t.playerCount} Players</Text>
                    </View>
                  )}
                </View>

                {/* Medals Breakdown */}
                <View style={styles.medalSection}>
                  <Text style={styles.medalSectionTitle}>MEDAL STANDINGS</Text>
                  <View style={styles.medalGrid}>
                    <MedalBadge color="#F59E0B" label="Gold" value={t.medalGold ?? 0} colors={colors} styles={styles} />
                    <MedalBadge color="#9CA3AF" label="Silver" value={t.medalSilver ?? 0} colors={colors} styles={styles} />
                    <MedalBadge color="#B45309" label="Bronze" value={t.medalBronze ?? 0} colors={colors} styles={styles} />
                    <MedalBadge color={colors.primary} label="Total Players" value={t.playerCount ?? 0} colors={colors} styles={styles} />
                  </View>
                </View>
              </View>
            );
          })}
      </ScrollView>
    </View>
  );
}

function MedalBadge({ color, label, value, colors, styles }: { color: string; label: string; value: number; colors: any; styles: any }) {
  return (
    <View style={styles.medalBadgeItem}>
      <View style={[styles.medalCircle, { backgroundColor: color + "20" }]}>
        <Text style={[styles.medalNum, { color }]}>{value}</Text>
      </View>
      <Text style={[styles.medalLbl, { color: colors.textSecondary }]}>{label}</Text>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    tabsRow: { flexDirection: "row", paddingHorizontal: spacing.xl, paddingVertical: 10, gap: 8 },
    tab: { flex: 1, flexDirection: "row", paddingVertical: 11, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    tabActive: { backgroundColor: colors.primary },
    tabTxt: { fontSize: 13, fontWeight: "700", color: colors.textSecondary },
    tabTxtActive: { color: "#fff" },

    filterPill: { paddingHorizontal: 14, paddingVertical: 6, borderRadius: radius.xl, backgroundColor: colors.surfaceAlt, borderWidth: 1, borderColor: colors.border },
    filterPillActive: { backgroundColor: colors.primary + "18", borderColor: colors.primary },
    filterPillTxt: { fontSize: 12, fontWeight: "600", color: colors.textSecondary },
    filterPillTxtActive: { color: colors.primary, fontWeight: "700" },

    centerContainer: { alignItems: "center", justifyContent: "center", paddingVertical: 40 },
    loadingTxt: { color: colors.textSecondary, marginTop: 12, fontSize: 13 },
    errorTxt: { color: colors.error, marginTop: 8, fontSize: 13 },
    retryBtn: { marginTop: 12, paddingHorizontal: 16, paddingVertical: 8, backgroundColor: colors.primary, borderRadius: radius.sm },
    retryTxt: { color: "#fff", fontWeight: "700", fontSize: 12 },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center", marginTop: 12, paddingHorizontal: 24 },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 16, marginBottom: 16, ...shadow.card, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardHead: { flexDirection: "row", alignItems: "flex-start", gap: 12, marginBottom: 12 },
    iconCircle: { width: 44, height: 44, borderRadius: 22, backgroundColor: "#DB277718", alignItems: "center", justifyContent: "center" },
    cardTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    cardSub: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
    statusBadge: { backgroundColor: colors.surfaceAlt, paddingHorizontal: 8, paddingVertical: 3, borderRadius: 8 },
    statusTxt: { fontSize: 10, fontWeight: "800", color: colors.primary, letterSpacing: 0.5 },

    detailsRow: { flexDirection: "row", gap: 8, marginBottom: 14 },
    tagPill: { flexDirection: "row", alignItems: "center", gap: 4, backgroundColor: colors.surfaceAlt, paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.sm },
    tagTxt: { fontSize: 11, fontWeight: "600", color: colors.textSecondary },

    medalSection: { borderTopWidth: 1, borderTopColor: colors.border, paddingTop: 12, marginTop: 4 },
    medalSectionTitle: { fontSize: 10, fontWeight: "800", letterSpacing: 1, color: colors.textMuted, marginBottom: 10 },
    medalGrid: { flexDirection: "row", justifyContent: "space-between", gap: 8 },
    medalBadgeItem: { flex: 1, alignItems: "center" },
    medalCircle: { width: 42, height: 42, borderRadius: 21, alignItems: "center", justifyContent: "center" },
    medalNum: { fontSize: 16, fontWeight: "800" },
    medalLbl: { fontSize: 10, fontWeight: "700", marginTop: 4 },
  });
}
