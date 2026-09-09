import { useMemo } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useBottomTabBarHeight } from "@react-navigation/bottom-tabs";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../theme";
import { api } from "../api/endpoints";
import { useApi } from "../api/useApi";
import { Avatar } from "../ui/avatar";
import { useAuth } from "../api/auth";
import { useNotifications } from "../notifications/NotificationsProvider";
import { notify } from "../ui/dialogs";

// Quick Access tiles — fixed order, each with a distinct accent color (matches the
// home.tsx grid: tinted square + Ionicons + 2-line label). "33" tint in dark, "18" in light.
type Tile = { id: string; label: string; icon: any; color: string };
const TILES: Tile[] = [
  { id: "training-time", label: "Training Time", icon: "time-outline", color: "#F59E0B" },
  { id: "activities", label: "Activities", icon: "pulse-outline", color: "#10B981" },
  // "Update Attendance" would be a lie: the attendance subsystem is self-scoped in both
  // directions — /Attendance/Add only ever checks in the token holder, and /Reports/Attendance
  // returns nothing to an instructor. The screen shows the class list + the centre QR students
  // scan. See the contract notes on api.addAttendance / api.attendanceReport for the prod probes.
  { id: "update-attendance", label: "Class Check-In", icon: "checkmark-done-circle-outline", color: "#4F46E5" },
  { id: "receipt", label: "Receipt", icon: "receipt-outline", color: "#0EA5E9" },
  { id: "grading-schedule", label: "Grading Schedule", icon: "school-outline", color: "#9333EA" },
  { id: "tournament-schedule", label: "Tournament Schedule", icon: "trophy-outline", color: "#EF4444" },
  { id: "collections", label: "Collections", icon: "cash-outline", color: "#DB2777" },
  { id: "missing-invoice", label: "Missing Invoice", icon: "document-text-outline", color: "#F97316" },
  { id: "fee-master", label: "Fee Master", icon: "pricetags-outline", color: "#64748B" },
  { id: "new-student", label: "New Student", icon: "person-add-outline", color: "#10B981" },
  { id: "payment-slip", label: "Payment Slip", icon: "document-attach-outline", color: "#4F46E5" },
  { id: "more", label: "More", icon: "grid-outline", color: "#0EA5E9" },
];

export default function InstructorHome() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user, token } = useAuth();
  const tabBarHeight = useBottomTabBarHeight();

  // Gate every authed call on the session token to dodge the cold-load 401 race.
  const stats = useApi(() => (token ? api.homePageStats() : Promise.resolve(null)), [token]);
  const clubStats = useApi(() => (token ? api.myClubStats() : Promise.resolve([])), [token]);
  const { unreadCount } = useNotifications(); // live (60s poll), same source as the student home

  /**
   * The dues card counts the very invoices it navigates to.
   *
   * It used to read `invoiceCount` / `dueAmount` off `/Reports/HomePageStats`, whose totals do
   * not agree with the `/Outstanding/Fetch` list behind the card — probed live 2026-08-10 on
   * RTT/KCP, HomePageStats answered 3 invoices / RM 420 while the outstanding list held 649
   * invoices / RM 47,365. Tapping a headline figure and landing on a different one is the bug;
   * one query now feeds both, so the number is always the list the user is about to see.
   */
  const dues = useApi(
    () => (token ? api.outstanding({ studentId: null, startDate: null, endDate: null }) : Promise.resolve([])),
    [token]
  );
  const dueRows = useMemo(() => (Array.isArray(dues.data) ? dues.data : []), [dues.data]);
  const invoiceCount = dueRows.length;
  const dueAmount = useMemo(() => dueRows.reduce((s, r) => s + Number(r.dueAmount || 0), 0), [dueRows]);

  const offers = stats.data?.myoffers ?? [];
  const hasUnread = unreadCount > 0;

  // MyClubStats rows: id = count, text = label, value = display order ("1".."10").
  const rows = useMemo(
    () => (clubStats.data ?? []).slice().sort((a, b) => Number(a.value) - Number(b.value)),
    [clubStats.data]
  );

  // Tiles that have a built detail screen; the rest show a "coming soon" notice.
  const TILE_ROUTES: Record<string, string> = {
    "training-time": "/r-training-schedule",
    "update-attendance": "/update-attendance",
    receipt: "/r-receipts",
    "grading-schedule": "/r-grading",
    "tournament-schedule": "/r-tournament-upcoming",
    collections: "/(tabs)/collections",
    "missing-invoice": "/r-outstanding",
    "payment-slip": "/r-payment-slips",
    "new-student": "/new-student",
    more: "/(tabs)/reports",
  };
  const onTile = (t: Tile) => {
    const route = TILE_ROUTES[t.id];
    if (route) return router.push(route as any);
    notify(t.label, "This feature is coming soon.");
  };

  return (
    <View style={styles.root} testID="instructor-home">
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.headerBg}>
          <View style={styles.headerRow}>
            <View style={styles.userRow}>
              <Avatar
                uri={user?.clubPic}
                icon="business"
                iconSize={26}
                iconColor="rgba(255,255,255,0.85)"
                imageStyle={styles.avatar}
                fallbackStyle={styles.avatarEmpty}
              />
              <View style={styles.nameCol}>
                <Text style={styles.hi}>Welcome,</Text>
                <Text style={styles.name} testID="instr-name" numberOfLines={1}>
                  {user?.name?.trim() || "Instructor"}
                </Text>
                <Text style={styles.sub} numberOfLines={1}>({user?.clubName || "Club"})</Text>
              </View>
            </View>
            <View style={styles.headerActions}>
              <TouchableOpacity
                style={styles.iconBtn}
                testID="instr-settings-btn"
                onPress={() => router.push("/(tabs)/settings")}
                activeOpacity={0.8}
              >
                <Ionicons name="settings-outline" size={20} color="#fff" />
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.iconBtn}
                testID="instr-notification-btn"
                onPress={() => router.push("/notifications")}
                activeOpacity={0.8}
              >
                <Ionicons name="notifications-outline" size={20} color="#fff" />
                {hasUnread && (
                  <View style={styles.badge}>
                    <Text style={styles.badgeNum}>{unreadCount > 99 ? "99+" : unreadCount}</Text>
                  </View>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </LinearGradient>
      </SafeAreaView>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: tabBarHeight + 24 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Dues summary card */}
        <TouchableOpacity
          style={styles.dueCard}
          testID="instr-dues-card"
          onPress={() => router.push("/pay-dues" as any)}
          activeOpacity={0.9}
        >
          <LinearGradient
            colors={mode === "dark" ? ["#2D1A0A", "#3F2410"] : ["#FEF3C7", "#FED7AA"]}
            style={styles.dueGradient}
          >
            <View style={styles.dueIcon}>
              <Ionicons name="notifications" size={22} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              {dues.loading && !dues.data ? (
                <ActivityIndicator color={colors.primary} style={{ alignSelf: "flex-start", marginVertical: 6 }} />
              ) : dues.error && !dues.data ? (
                // Never print "0 invoices are due" for a request that failed — that reads as
                // "the club is all paid up" and nothing distinguishes it from the truth.
                <Text style={styles.dueTitle}>Dues couldn&apos;t be loaded</Text>
              ) : (
                <Text style={styles.dueTitle}>
                  {invoiceCount} invoice{invoiceCount === 1 ? "" : "s"} {invoiceCount === 1 ? "is" : "are"} due
                </Text>
              )}
              <Text style={styles.dueSub}>
                {dues.error && !dues.data
                  ? "Tap to open Pay Your Dues"
                  : `RM ${dueAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} total due amount`}
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={mode === "dark" ? "#FDBA74" : "#9A3412"} />
          </LinearGradient>
        </TouchableOpacity>

        {/* Quick Access grid */}
        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>Quick Access</Text>
        </View>
        <View style={styles.grid}>
          {TILES.map((t) => (
            <TouchableOpacity
              key={t.id}
              testID={`instr-grid-${t.id}`}
              style={styles.gridCard}
              onPress={() => onTile(t)}
              activeOpacity={0.8}
            >
              <View style={[styles.gridIcon, { backgroundColor: t.color + (mode === "dark" ? "33" : "18") }]}>
                <Ionicons name={t.icon} size={22} color={t.color} />
              </View>
              <Text style={styles.gridLbl} numberOfLines={2}>{t.label}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Latest Updates (club stats) */}
        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>Latest Updates</Text>
        </View>
        <View style={styles.card}>
          {clubStats.loading ? (
            <ActivityIndicator color={colors.primary} style={{ marginVertical: 12 }} />
          ) : rows.length === 0 ? (
            <Text style={styles.emptyTxt}>No updates right now.</Text>
          ) : (
            rows.map((r, i) => (
              <View key={`${r.value}-${r.text}`}>
                {i > 0 && <View style={styles.divider} />}
                <View style={styles.updateRow}>
                  <Text style={styles.updateLbl} numberOfLines={1}>{r.text}</Text>
                  <Text style={styles.updateNum}>{r.id}</Text>
                </View>
              </View>
            ))
          )}
        </View>

        {/* Latest News (offers) */}
        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>Latest News</Text>
        </View>
        {stats.loading ? (
          <View style={styles.card}>
            <ActivityIndicator color={colors.primary} style={{ marginVertical: 12 }} />
          </View>
        ) : offers.length > 0 ? (
          offers.slice(0, 2).map((o, i) => (
            <View key={o.code || `news-${i}`} style={styles.newsCard} testID={`instr-news-${i}`}>
              <View style={styles.newsIcon}>
                <Ionicons name="megaphone-outline" size={20} color={colors.primary} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.newsName} numberOfLines={2}>{o.name}</Text>
                <Text style={styles.newsCode} numberOfLines={1}>{(o.code || "NEWS").toUpperCase()}</Text>
              </View>
            </View>
          ))
        ) : (
          <View style={styles.card}>
            <Text style={styles.emptyTxt}>No news right now.</Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },

    headerBg: {
      paddingHorizontal: spacing.xl,
      paddingTop: 6,
      paddingBottom: 26,
      borderBottomLeftRadius: 28,
      borderBottomRightRadius: 28,
    },
    headerRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 6 },
    userRow: { flexDirection: "row", gap: 12, alignItems: "center", flex: 1, marginRight: 12 },
    nameCol: { flex: 1 },
    avatar: {
      width: 52,
      height: 52,
      borderRadius: 26,
      borderWidth: 2,
      borderColor: "rgba(255,255,255,0.6)",
      backgroundColor: "#fff",
    },
    avatarEmpty: { alignItems: "center", justifyContent: "center", backgroundColor: "rgba(255,255,255,0.25)" },
    hi: { color: "rgba(255,255,255,0.85)", fontSize: 12 },
    name: { color: "#fff", fontSize: 18, fontWeight: "800", letterSpacing: -0.3 },
    sub: { color: "#FFF7ED", fontSize: 12, fontWeight: "600", marginTop: 2 },
    headerActions: { flexDirection: "row", alignItems: "center", gap: 10 },
    iconBtn: {
      width: 42,
      height: 42,
      borderRadius: 21,
      backgroundColor: "rgba(255,255,255,0.22)",
      alignItems: "center",
      justifyContent: "center",
    },
    badge: {
      position: "absolute",
      top: -3,
      right: -3,
      minWidth: 18,
      height: 18,
      borderRadius: 9,
      paddingHorizontal: 4,
      backgroundColor: "#EF4444",
      alignItems: "center",
      justifyContent: "center",
      borderWidth: 1.5,
      borderColor: colors.primary,
    },
    badgeNum: { color: "#fff", fontSize: 10, fontWeight: "800" },

    dueCard: { marginHorizontal: spacing.xl, marginTop: 18 },
    dueGradient: { borderRadius: radius.xl, padding: 16, flexDirection: "row", alignItems: "center", gap: 14 },
    dueIcon: {
      width: 44,
      height: 44,
      borderRadius: 22,
      backgroundColor: mode === "dark" ? "rgba(0,0,0,0.25)" : "rgba(255,255,255,0.7)",
      alignItems: "center",
      justifyContent: "center",
    },
    dueTitle: { color: mode === "dark" ? "#FED7AA" : "#7C2D12", fontSize: 16, fontWeight: "800" },
    dueSub: { color: mode === "dark" ? "#FDBA74" : "#9A3412", fontSize: 12, marginTop: 3, fontWeight: "600" },

    sectionHead: {
      flexDirection: "row",
      justifyContent: "space-between",
      alignItems: "center",
      paddingHorizontal: spacing.xl,
      marginTop: 24,
      marginBottom: 12,
    },
    sectionTitle: { ...font.h3, color: colors.textPrimary },

    grid: {
      flexDirection: "row",
      flexWrap: "wrap",
      paddingHorizontal: spacing.lg,
      justifyContent: "space-between",
      rowGap: 14,
    },
    gridCard: {
      width: "30%",
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      paddingVertical: 14,
      paddingHorizontal: 6,
      alignItems: "center",
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    gridIcon: { width: 48, height: 48, borderRadius: 24, alignItems: "center", justifyContent: "center", marginBottom: 8 },
    gridLbl: { fontSize: 11, color: colors.textPrimary, fontWeight: "600", textAlign: "center", lineHeight: 14 },

    card: {
      backgroundColor: colors.surface,
      borderRadius: radius.xl,
      padding: 16,
      marginHorizontal: spacing.xl,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    divider: { height: 1, backgroundColor: colors.border },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, paddingVertical: 8, textAlign: "center" },

    updateRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: 12 },
    updateLbl: { flex: 1, fontSize: 14, color: colors.textPrimary, fontWeight: "600", marginRight: 12 },
    updateNum: { fontSize: 18, fontWeight: "800", color: colors.primary },

    newsCard: {
      flexDirection: "row",
      alignItems: "center",
      gap: 14,
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 16,
      marginHorizontal: spacing.xl,
      marginBottom: 12,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    newsIcon: {
      width: 42,
      height: 42,
      borderRadius: 21,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    newsName: { fontSize: 14, color: colors.textPrimary, fontWeight: "700" },
    newsCode: { fontSize: 11, color: colors.textSecondary, fontWeight: "700", letterSpacing: 0.5, marginTop: 3 },
  });
}
