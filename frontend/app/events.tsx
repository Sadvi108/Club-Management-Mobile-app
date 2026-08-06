import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ImageBackground, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api, defaultRange } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

const tabs = ["Offers", "Tournaments"];

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Events() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const { user } = useAuth();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const [tab, setTab] = useState(0);

  const stats = useApi(() => api.homePageStats(), []);
  const range = useMemo(() => defaultRange(), []);
  const tournaments = useApi(() => api.tournamentSummary({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const offers = stats.data?.myoffers ?? [];
  const tourneyRows = tournaments.data ?? [];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="events-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Events & Offers</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <View style={styles.tabsRow}>
        {tabs.map((t, i) => (
          <TouchableOpacity key={t} style={[styles.tab, tab === i && styles.tabActive]} onPress={() => setTab(i)} testID={`events-tab-${i}`}>
            <Text style={[styles.tabTxt, tab === i && styles.tabTxtActive]}>{t}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        {tab === 0 ? (
          <>
            {stats.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}
            {!stats.loading && offers.length === 0 && <Text style={styles.emptyTxt}>No offers available right now.</Text>}
            {offers.map((e, idx) => {
              const img = e.attachments?.[0]?.documentUrl || e.previewImages?.[0]?.documentUrl;
              return (
                <TouchableOpacity
                  key={`${e.code}-${idx}`}
                  activeOpacity={0.92}
                  style={styles.eventCard}
                  testID={`event-${idx}`}
                  onPress={() => router.push(`/offer-detail?code=${encodeURIComponent(e.code || "")}` as any)}
                >
                  <ImageBackground source={img ? { uri: img } : undefined} style={styles.eventImg} imageStyle={{ borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl }}>
                    <LinearGradient colors={["rgba(15,23,42,0)", "rgba(15,23,42,0.8)"]} style={[StyleSheet.absoluteFillObject, { borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl }]} />
                    <View style={styles.catPill}><Text style={styles.catTxt}>{(e.code || "OFFER").toUpperCase()}</Text></View>
                  </ImageBackground>
                  <View style={styles.eventBody}>
                    <Text style={styles.eventTitle} numberOfLines={2}>{e.name}</Text>
                    {!!e.description && <Text style={styles.eventDesc} numberOfLines={3}>{e.description.replace(/\s+/g, " ").trim()}</Text>}
                    <View style={styles.eventMetaRow}>
                      <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                      <Text style={styles.eventMeta}>Valid till {fmtDate(e.expiryDate)}</Text>
                      <Ionicons name="business-outline" size={14} color={colors.textSecondary} style={{ marginLeft: 10 }} />
                      <Text style={styles.eventMeta}>{user?.clubName || "Academy"}</Text>
                    </View>
                  </View>
                </TouchableOpacity>
              );
            })}
          </>
        ) : (
          <>
            {tournaments.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}
            {!tournaments.loading && tourneyRows.length === 0 && <Text style={styles.emptyTxt}>No tournament records found.</Text>}
            {tourneyRows.map((t: any, i: number) => (
              <View key={i} style={styles.tourneyCard}>
                <View style={styles.tourneyHead}>
                  <Ionicons name="trophy" size={20} color={colors.warning} />
                  <Text style={styles.tourneyName} numberOfLines={1}>{t.name?.trim() || "Tournament Summary"}</Text>
                  <View style={styles.genderPill}><Text style={styles.genderTxt}>{t.gender}</Text></View>
                </View>
                <View style={styles.medalRow}>
                  <Medal color="#F59E0B" label="Gold" value={t.medalGold} colors={colors} />
                  <Medal color="#9CA3AF" label="Silver" value={t.medalSilver} colors={colors} />
                  <Medal color="#B45309" label="Bronze" value={t.medalBronze} colors={colors} />
                  <Medal color={colors.primary} label="Players" value={t.playerCount} colors={colors} />
                </View>
              </View>
            ))}
          </>
        )}
      </ScrollView>
    </View>
  );
}

function Medal({ color, label, value, colors }: { color: string; label: string; value: number; colors: any }) {
  return (
    <View style={{ flex: 1, alignItems: "center" }}>
      <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: color + "22", alignItems: "center", justifyContent: "center" }}>
        <Text style={{ fontSize: 18, fontWeight: "800", color }}>{value ?? 0}</Text>
      </View>
      <Text style={{ fontSize: 10, color: colors.textSecondary, fontWeight: "700", marginTop: 4 }}>{label}</Text>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    tabsRow: { flexDirection: "row", paddingHorizontal: spacing.xl, paddingVertical: 12, gap: 8 },
    tab: { flex: 1, paddingVertical: 10, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, alignItems: "center" },
    tabActive: { backgroundColor: colors.primary },
    tabTxt: { fontSize: 12, fontWeight: "700", color: colors.textSecondary },
    tabTxtActive: { color: "#fff" },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, textAlign: "center", marginVertical: 30 },

    eventCard: { backgroundColor: colors.surface, borderRadius: radius.xl, marginBottom: 16, ...shadow.card, overflow: "hidden", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    eventImg: { height: 160, justifyContent: "space-between", backgroundColor: colors.surfaceAlt },
    catPill: { position: "absolute", top: 14, left: 14, backgroundColor: "rgba(255,255,255,0.95)", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10 },
    catTxt: { color: colors.primary, fontSize: 10, fontWeight: "800", letterSpacing: 1 },

    eventBody: { padding: 16 },
    eventTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    eventDesc: { fontSize: 12, color: colors.textSecondary, marginTop: 6, lineHeight: 17 },
    eventMetaRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 10, flexWrap: "wrap" },
    eventMeta: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },

    tourneyCard: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 16, marginBottom: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    tourneyHead: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 14 },
    tourneyName: { flex: 1, fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginRight: spacing.xs },
    genderPill: { backgroundColor: colors.surfaceAlt, paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10 },
    genderTxt: { fontSize: 10, fontWeight: "700", color: colors.textSecondary },
    medalRow: { flexDirection: "row", gap: spacing.xs },
  });
}
