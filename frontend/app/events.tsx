import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ImageBackground, ActivityIndicator, RefreshControl } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter, useLocalSearchParams } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

const tabs = ["Events", "Offers"];

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Events() {
  const router = useRouter();
  const params = useLocalSearchParams<{ tab?: string }>();
  const { colors, shadow, mode } = useTheme();
  const { user } = useAuth();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const initialTab = params.tab === "offers" ? 1 : 0;
  const [tab, setTab] = useState<number>(initialTab);

  const stats = useApi(() => api.homePageStats(), []);

  const offers = stats.data?.myoffers ?? [];
  const newsEvents = stats.data?.mynews ?? [];

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
            <Ionicons
              name={i === 0 ? "calendar-outline" : "pricetags-outline"}
              size={16}
              color={tab === i ? "#fff" : colors.textSecondary}
              style={{ marginRight: 6 }}
            />
            <Text style={[styles.tabTxt, tab === i && styles.tabTxtActive]}>{t}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={stats.loading} onRefresh={stats.reload} colors={[colors.primary]} />}
      >
        {tab === 0 ? (
          <>
            {stats.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}
            {!stats.loading && newsEvents.length === 0 && (
              <View style={styles.emptyContainer}>
                <Ionicons name="calendar-outline" size={48} color={colors.textMuted} />
                <Text style={styles.emptyTitle}>Club Events & News</Text>
                <Text style={styles.emptyTxt}>No upcoming club events or news announcements posted right now. Check back soon for club activities and updates!</Text>
              </View>
            )}
            {newsEvents.map((e: any, idx: number) => {
              const img = e.attachments?.[0]?.documentUrl || e.previewImages?.[0]?.documentUrl || e.imageUrl;
              return (
                <View key={`${e.id || idx}`} style={styles.eventCard} testID={`news-event-${idx}`}>
                  {!!img && (
                    <ImageBackground source={{ uri: img }} style={styles.eventImg} imageStyle={{ borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl }}>
                      <LinearGradient colors={["rgba(15,23,42,0)", "rgba(15,23,42,0.8)"]} style={[StyleSheet.absoluteFillObject, { borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl }]} />
                      <View style={styles.catPill}><Text style={styles.catTxt}>EVENT</Text></View>
                    </ImageBackground>
                  )}
                  <View style={styles.eventBody}>
                    <Text style={styles.eventTitle} numberOfLines={2}>{e.title || e.name || "Club Event"}</Text>
                    {!!(e.description || e.content) && (
                      <Text style={styles.eventDesc} numberOfLines={4}>{(e.description || e.content || "").replace(/\s+/g, " ").trim()}</Text>
                    )}
                    <View style={styles.eventMetaRow}>
                      <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                      <Text style={styles.eventMeta}>{fmtDate(e.eventDate || e.createdDate || e.date) || "Upcoming"}</Text>
                      <Ionicons name="business-outline" size={14} color={colors.textSecondary} style={{ marginLeft: 10 }} />
                      <Text style={styles.eventMeta}>{user?.clubName || "Academy"}</Text>
                    </View>
                  </View>
                </View>
              );
            })}
          </>
        ) : (
          <>
            {stats.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}
            {!stats.loading && offers.length === 0 && (
              <View style={styles.emptyContainer}>
                <Ionicons name="pricetag-outline" size={48} color={colors.textMuted} />
                <Text style={styles.emptyTitle}>Special Offers</Text>
                <Text style={styles.emptyTxt}>No promotional offers available right now.</Text>
              </View>
            )}
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
        )}
      </ScrollView>
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
    tab: { flex: 1, flexDirection: "row", paddingVertical: 10, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    tabActive: { backgroundColor: colors.primary },
    tabTxt: { fontSize: 13, fontWeight: "700", color: colors.textSecondary },
    tabTxtActive: { color: "#fff" },

    emptyContainer: { alignItems: "center", justifyContent: "center", paddingVertical: 40, paddingHorizontal: 20 },
    emptyTitle: { fontSize: 16, fontWeight: "700", color: colors.textPrimary, marginTop: 12 },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, textAlign: "center", marginTop: 6, lineHeight: 18 },

    eventCard: { backgroundColor: colors.surface, borderRadius: radius.xl, marginBottom: 16, ...shadow.card, overflow: "hidden", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    eventImg: { height: 160, justifyContent: "space-between", backgroundColor: colors.surfaceAlt },
    catPill: { position: "absolute", top: 14, left: 14, backgroundColor: "rgba(255,255,255,0.95)", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10 },
    catTxt: { color: colors.primary, fontSize: 10, fontWeight: "800", letterSpacing: 1 },

    eventBody: { padding: 16 },
    eventTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    eventDesc: { fontSize: 12, color: colors.textSecondary, marginTop: 6, lineHeight: 17 },
    eventMetaRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 10, flexWrap: "wrap" },
    eventMeta: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },
  });
}

