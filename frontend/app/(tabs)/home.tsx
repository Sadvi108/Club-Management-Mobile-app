import { useMemo } from "react";
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Image, ImageBackground, ActivityIndicator, useWindowDimensions,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useBottomTabBarHeight } from "@react-navigation/bottom-tabs";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { quickCards } from "../../src/mockData";
import { useAuth } from "../../src/api/auth";
import { api } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";
import { useNotifications } from "../../src/notifications/NotificationsProvider";
import { SkeletonStatRow } from "../../src/ui/skeleton";
import InstructorHome from "../../src/screens/InstructorHome";

function initialsOf(name?: string) {
  return (name || "?")
    .trim()
    .split(/\s+/)
    .map((w) => w[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

// Role dispatcher: instructors get the management dashboard, students the training home.
export default function Home() {
  const { isInstructor } = useAuth();
  return isInstructor ? <InstructorHome /> : <StudentHome />;
}

function StudentHome() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const { width } = useWindowDimensions(); // rotation/resize-safe (vs static Dimensions.get)
  const tabBarHeight = useBottomTabBarHeight(); // real bar height incl. safe-area inset
  const styles = useMemo(() => createStyles(colors, shadow, mode, width), [colors, shadow, mode, width]);
  const { user } = useAuth();

  const stats = useApi(() => api.homePageStats(), []);
  const info = useApi(() => api.myInfo(), []);
  const { unreadCount } = useNotifications(); // live (60s poll), not a one-shot fetch

  const grade = (info.data?.currentGrade || user?.currentGrade || "—").replace(/Grade\s*/i, "");
  const beltShort = grade.split(" ")[0];
  const dueAmount = stats.data?.dueAmount ?? 0;
  const invoiceCount = stats.data?.invoiceCount ?? 0;
  const offers = stats.data?.myoffers ?? [];
  const trainingFirstLine = (info.data?.trainingTme || "").split(/\r?\n/).find((l) => l.trim());
  const hasUnread = unreadCount > 0;
  // Account standing from the auth response ("Active" / "Inactive")
  const isActive = (user?.status || "").trim().toLowerCase() !== "inactive";

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.headerBg}>
          <View style={styles.headerRow}>
            <View style={styles.userRow}>
              {user?.clubPic ? (
                <Image source={{ uri: user.clubPic }} style={styles.avatar} />
              ) : (
                <View style={[styles.avatar, styles.avatarInitials]}>
                  <Text style={styles.avatarInitialsTxt}>{initialsOf(user?.name)}</Text>
                </View>
              )}
              <View style={styles.nameCol}>
                <Text style={styles.hi}>Hello,</Text>
                <Text style={styles.name} testID="home-student-name" numberOfLines={1}>{user?.name?.trim() || "Member"}</Text>
                <View style={styles.badgeRow}>
                  <Ionicons name="shield-checkmark" size={12} color="#FDECEC" />
                  <Text style={styles.badgeTxt} numberOfLines={1}>{user?.clubName || "Member"}</Text>
                </View>
                {!!user?.status && (
                  <View style={[styles.statusPill, { backgroundColor: isActive ? "rgba(34,197,94,0.25)" : "rgba(239,68,68,0.3)" }]} testID="home-status">
                    <View style={[styles.statusDot, { backgroundColor: isActive ? "#4ADE80" : "#FCA5A5" }]} />
                    <Text style={styles.statusTxt}>{isActive ? "Active" : "Inactive"}</Text>
                  </View>
                )}
              </View>
            </View>
            <View style={styles.headerActions}>
              {/* student's own photo (was the D-CLIX logo); falls back to initials */}
              {user?.profilePic ? (
                <Image source={{ uri: user.profilePic }} style={styles.headerLogo} testID="home-profile-pic" />
              ) : (
                <View style={[styles.headerLogo, styles.headerPicEmpty]}>
                  <Text style={styles.headerPicTxt}>{initialsOf(user?.name)}</Text>
                </View>
              )}
              <TouchableOpacity style={styles.bell} testID="home-notification-btn" onPress={() => router.push("/notifications")}>
                <Ionicons name="notifications-outline" size={20} color="#fff" />
                {hasUnread && (
                  <View style={styles.badge}>
                    <Text style={styles.badgeNum}>{unreadCount > 99 ? "99+" : unreadCount}</Text>
                  </View>
                )}
              </TouchableOpacity>
            </View>
          </View>

          <View style={styles.statRow}>
            {stats.loading && !stats.data ? (
              <SkeletonStatRow />
            ) : (
              <>
                <View style={styles.stat}><Text style={styles.statNum}>{invoiceCount}</Text><Text style={styles.statLbl}>Invoices</Text></View>
                <View style={styles.statSep} />
                <View style={styles.stat}><Text style={styles.statNum}>{beltShort}</Text><Text style={styles.statLbl}>Current Grade</Text></View>
                <View style={styles.statSep} />
                <View style={styles.stat}><Text style={styles.statNum}>{dueAmount}</Text><Text style={styles.statLbl}>Due (RM)</Text></View>
              </>
            )}
          </View>
        </LinearGradient>
      </SafeAreaView>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: tabBarHeight + 24 }} showsVerticalScrollIndicator={false}>
        <View style={styles.topQuick}>
          {[
            { id: "train", label: "Training", icon: "barbell-outline", route: "/(tabs)/training" },
            { id: "att", label: "Attendance", icon: "checkmark-done-circle", route: "/attendance" },
            { id: "tt", label: "Timetable", icon: "calendar-outline", route: "/(tabs)/schedule" },
            { id: "id", label: "Virtual ID", icon: "card-outline", route: "/(tabs)/profile" },
            { id: "prof", label: "Profile", icon: "person-circle-outline", route: "/(tabs)/profile" },
          ].map((q) => (
            <TouchableOpacity key={q.id} testID={`quick-top-${q.id}`} style={styles.topQuickItem} onPress={() => router.push(q.route as any)} activeOpacity={0.7}>
              <View style={styles.topQuickIcon}><Ionicons name={q.icon as any} size={22} color={colors.primary} /></View>
              <Text style={styles.topQuickLbl} numberOfLines={1}>{q.label}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.dueCard} onPress={() => router.push("/(tabs)/payments")} activeOpacity={0.9} testID="home-due-card">
          <LinearGradient colors={colors.gradientSoft} style={styles.dueGradient}>
            <View style={{ flex: 1 }}>
              <Text style={styles.dueLbl}>FEES DUE</Text>
              {stats.loading ? (
                <ActivityIndicator color={colors.primary} style={{ alignSelf: "flex-start", marginVertical: 6 }} />
              ) : (
                <Text style={styles.dueAmt}>RM {dueAmount.toLocaleString()}</Text>
              )}
              <Text style={styles.dueDate}>{invoiceCount} invoice{invoiceCount === 1 ? "" : "s"} pending</Text>
            </View>
            <View style={styles.dueBtn}>
              <Text style={styles.dueBtnTxt}>Pay Now</Text>
              <Ionicons name="arrow-forward" size={14} color="#fff" />
            </View>
          </LinearGradient>
        </TouchableOpacity>

        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>Today&apos;s Class</Text>
          <TouchableOpacity onPress={() => router.push("/(tabs)/schedule")}><Text style={styles.sectionLink}>See all</Text></TouchableOpacity>
        </View>
        <View style={styles.todayCard}>
          <View style={[styles.todayBar, { backgroundColor: colors.primary }]} />
          <View style={{ flex: 1 }}>
            <Text style={styles.todayTime}>{trainingFirstLine || (info.loading ? "Loading…" : "No training time set")}</Text>
            <Text style={styles.todayTitle}>{info.data?.tCenterName || "Training Center"}</Text>
            <Text style={styles.todayTrainer}>with {info.data?.instructorName || "your instructor"}</Text>
          </View>
          <TouchableOpacity style={styles.checkInBtn} onPress={() => router.push("/qr-scan")}>
            <Ionicons name="qr-code" size={14} color={colors.primary} />
            <Text style={styles.checkInTxt}>Check In</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.sectionHead}><Text style={styles.sectionTitle}>Quick Access</Text></View>
        <View style={styles.grid}>
          {quickCards.map((c) => (
            <TouchableOpacity key={c.id} testID={`quick-card-${c.id}`} style={styles.gridCard} onPress={() => router.push(c.route as any)} activeOpacity={0.8}>
              <View style={[styles.gridIcon, { backgroundColor: c.color + (mode === "dark" ? "33" : "18") }]}>
                <Ionicons name={c.icon as any} size={22} color={c.color} />
              </View>
              <Text style={styles.gridLbl} numberOfLines={2}>{c.label}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {offers.length > 0 && (
          <>
            <View style={styles.sectionHead}>
              <Text style={styles.sectionTitle}>Featured Offer{offers.length > 1 ? "s" : ""}</Text>
              <TouchableOpacity onPress={() => router.push("/events")}><Text style={styles.sectionLink}>View all</Text></TouchableOpacity>
            </View>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ paddingHorizontal: spacing.xl, gap: 12 }}
              // full-width cards when there's one offer, peek the next one when there are more
              snapToAlignment="start"
              decelerationRate="fast"
            >
              {offers.map((o, idx) => {
                const img = o.attachments?.[0]?.documentUrl || o.previewImages?.[0]?.documentUrl;
                return (
                  <TouchableOpacity
                    key={`${o.code}-${idx}`}
                    activeOpacity={0.9}
                    onPress={() => router.push(`/offer-detail?code=${encodeURIComponent(o.code || "")}` as any)}
                    testID={`home-offer-${o.code}`}
                  >
                    <ImageBackground source={img ? { uri: img } : undefined} style={[styles.eventBanner, offers.length > 1 && styles.eventBannerPeek]} imageStyle={{ borderRadius: radius.xl }}>
                      <LinearGradient colors={["rgba(15,23,42,0.05)", "rgba(15,23,42,0.85)"]} style={[StyleSheet.absoluteFillObject, { borderRadius: radius.xl }]} />
                      <View style={styles.eventBottom}>
                        <Text style={styles.eventCat}>{(o.code || "OFFER").toUpperCase()}</Text>
                        <Text style={styles.eventTitle} numberOfLines={2}>{o.name}</Text>
                        <Text style={styles.eventMeta} numberOfLines={1}>📍 {user?.clubName || "Your Academy"}</Text>
                      </View>
                    </ImageBackground>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          </>
        )}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark", width: number) {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    headerBg: { paddingHorizontal: spacing.xl, paddingBottom: 30, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 },
    headerRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 6 },
    userRow: { flexDirection: "row", gap: 12, alignItems: "center", flex: 1, marginRight: 12 },
    nameCol: { flex: 1 },
    avatar: { width: 52, height: 52, borderRadius: 26, borderWidth: 2, borderColor: "rgba(255,255,255,0.6)", backgroundColor: "#fff" },
    avatarInitials: { alignItems: "center", justifyContent: "center", backgroundColor: "rgba(255,255,255,0.25)" },
    avatarInitialsTxt: { color: "#fff", fontWeight: "800", fontSize: 18 },
    hi: { color: "rgba(255,255,255,0.85)", fontSize: 12 },
    name: { color: "#fff", fontSize: 18, fontWeight: "800", letterSpacing: -0.3 },
    badgeRow: { flexDirection: "row", alignItems: "center", gap: 4, marginTop: 4, backgroundColor: "rgba(255,255,255,0.22)", paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10, alignSelf: "flex-start" },
    badgeTxt: { color: "#FDECEC", fontSize: 10, fontWeight: "700", letterSpacing: 0.3 },
    headerActions: { flexDirection: "row", alignItems: "center", gap: 10 },
    headerLogo: { width: 36, height: 36, borderRadius: 10, backgroundColor: "#fff" },
    headerPicEmpty: { alignItems: "center", justifyContent: "center", backgroundColor: "rgba(255,255,255,0.25)" },
    headerPicTxt: { color: "#fff", fontWeight: "800", fontSize: 13 },
    statusPill: { flexDirection: "row", alignItems: "center", gap: 5, alignSelf: "flex-start", marginTop: 5, paddingHorizontal: 8, paddingVertical: 3, borderRadius: 9 },
    statusDot: { width: 6, height: 6, borderRadius: 3 },
    statusTxt: { color: "#fff", fontSize: 10, fontWeight: "800", letterSpacing: 0.3 },
    bell: { width: 42, height: 42, borderRadius: 21, backgroundColor: "rgba(255,255,255,0.22)", alignItems: "center", justifyContent: "center" },
    dot: { position: "absolute", top: 10, right: 10, width: 8, height: 8, borderRadius: 4, backgroundColor: "#FDE68A", borderWidth: 2, borderColor: colors.primary },
    badge: { position: "absolute", top: -3, right: -3, minWidth: 18, height: 18, borderRadius: 9, paddingHorizontal: 4, backgroundColor: "#EF4444", alignItems: "center", justifyContent: "center", borderWidth: 1.5, borderColor: colors.primary },
    badgeNum: { color: "#fff", fontSize: 10, fontWeight: "800" },
    statRow: { flexDirection: "row", marginTop: 22, backgroundColor: "rgba(255,255,255,0.18)", borderRadius: radius.lg, paddingVertical: 14 },
    stat: { flex: 1, alignItems: "center" },
    statNum: { color: "#fff", fontSize: 18, fontWeight: "800" },
    statLbl: { color: "rgba(255,255,255,0.85)", fontSize: 10, marginTop: 2, letterSpacing: 0.5 },
    statSep: { width: 1, backgroundColor: "rgba(255,255,255,0.25)" },

    topQuick: { flexDirection: "row", backgroundColor: colors.surface, marginHorizontal: spacing.xl, marginTop: -20, borderRadius: radius.xl, paddingVertical: 16, paddingHorizontal: 6, ...shadow.card, justifyContent: "space-between", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    topQuickItem: { alignItems: "center", flex: 1 },
    topQuickIcon: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center", marginBottom: 6 },
    topQuickLbl: { fontSize: 9.5, color: colors.textPrimary, fontWeight: "600", textAlign: "center" },

    dueCard: { marginHorizontal: spacing.xl, marginTop: 18 },
    dueGradient: { borderRadius: radius.xl, padding: 18, flexDirection: "row", alignItems: "center" },
    dueLbl: { color: mode === "dark" ? "#FF8A93" : "#B10E18", fontSize: 11, fontWeight: "700", letterSpacing: 0.5 },
    dueAmt: { color: mode === "dark" ? "#FFB3B8" : "#8F0B13", fontSize: 24, fontWeight: "800", marginTop: 2 },
    dueDate: { color: mode === "dark" ? "#FF8A93" : "#B10E18", fontSize: 11, marginTop: 2, fontWeight: "500" },
    dueBtn: { flexDirection: "row", gap: 6, alignItems: "center", backgroundColor: colors.primary, paddingHorizontal: 16, paddingVertical: 10, borderRadius: radius.md },
    dueBtnTxt: { color: "#fff", fontWeight: "700", fontSize: 12 },

    sectionHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, marginTop: 24, marginBottom: 12 },
    sectionTitle: { ...font.h3, color: colors.textPrimary },
    sectionLink: { color: colors.primary, fontSize: 12, fontWeight: "700" },

    todayCard: { marginHorizontal: spacing.xl, backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, flexDirection: "row", alignItems: "center", gap: 14, ...shadow.soft, overflow: "hidden", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    todayBar: { width: 4, height: 50, borderRadius: 2 },
    todayTime: { color: colors.textSecondary, fontSize: 11, fontWeight: "600" },
    todayTitle: { color: colors.textPrimary, fontSize: 15, fontWeight: "700", marginTop: 2 },
    todayTrainer: { color: colors.textSecondary, fontSize: 11, marginTop: 2 },
    checkInBtn: { flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 12, paddingVertical: 8, backgroundColor: colors.surfaceAlt, borderRadius: radius.sm },
    checkInTxt: { color: colors.primary, fontWeight: "700", fontSize: 11 },

    grid: { flexDirection: "row", flexWrap: "wrap", paddingHorizontal: spacing.lg, justifyContent: "space-between", rowGap: 14 },
    gridCard: { width: "23%", backgroundColor: colors.surface, borderRadius: radius.lg, paddingVertical: 12, paddingHorizontal: 6, alignItems: "center", ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    gridIcon: { width: 44, height: 44, borderRadius: 22, alignItems: "center", justifyContent: "center", marginBottom: 6 },
    gridLbl: { fontSize: 10, color: colors.textPrimary, fontWeight: "600", textAlign: "center", lineHeight: 13 },

    eventBanner: { height: 180, width: width - spacing.xl * 2, borderRadius: radius.xl, overflow: "hidden", justifyContent: "space-between", backgroundColor: colors.surfaceAlt },
    // slightly narrower when several offers exist so the next card peeks in
    eventBannerPeek: { width: width - spacing.xl * 2 - 36 },
    eventBottom: { padding: 16, marginTop: "auto" },
    eventCat: { color: "#FF8A93", fontSize: 10, fontWeight: "700", letterSpacing: 1.5 },
    eventTitle: { color: "#fff", fontSize: 18, fontWeight: "800", marginTop: 4 },
    eventMeta: { color: "rgba(255,255,255,0.85)", fontSize: 11, marginTop: 6 },
  });
}
