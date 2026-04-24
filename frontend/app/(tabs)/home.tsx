import { useMemo } from "react";
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Image, ImageBackground,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme, LOGO_URL } from "../../src/theme";
import { student, quickCards, events, schedule } from "../../src/mockData";

export default function Home() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const today = schedule.find((d) => d.day === "Mon") ?? schedule[0];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.headerBg}>
          <View style={styles.headerRow}>
            <View style={styles.userRow}>
              <Image source={{ uri: student.photo }} style={styles.avatar} />
              <View>
                <Text style={styles.hi}>Hello,</Text>
                <Text style={styles.name} testID="home-student-name">{student.name}</Text>
                <View style={styles.badgeRow}>
                  <Ionicons name="shield-checkmark" size={12} color="#FFF7ED" />
                  <Text style={styles.badgeTxt}>{student.membership}</Text>
                </View>
              </View>
            </View>
            <View style={styles.headerActions}>
              <Image source={{ uri: LOGO_URL }} style={styles.headerLogo} />
              <TouchableOpacity style={styles.bell} testID="home-notification-btn">
                <Ionicons name="notifications-outline" size={20} color="#fff" />
                <View style={styles.dot} />
              </TouchableOpacity>
            </View>
          </View>

          <View style={styles.statRow}>
            <View style={styles.stat}><Text style={styles.statNum}>{student.attendance}%</Text><Text style={styles.statLbl}>Attendance</Text></View>
            <View style={styles.statSep} />
            <View style={styles.stat}><Text style={styles.statNum}>{student.belt.split(" ")[0]}</Text><Text style={styles.statLbl}>Current Belt</Text></View>
            <View style={styles.statSep} />
            <View style={styles.stat}><Text style={styles.statNum}>{student.fitness}</Text><Text style={styles.statLbl}>Fitness</Text></View>
          </View>
        </LinearGradient>
      </SafeAreaView>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <View style={styles.topQuick}>
          {[
            { id: "att", label: "Attendance", icon: "checkmark-done-circle", route: "/attendance" },
            { id: "tt", label: "Timetable", icon: "calendar-outline", route: "/(tabs)/schedule" },
            { id: "id", label: "Virtual ID", icon: "card-outline", route: "/(tabs)/profile" },
            { id: "prof", label: "Profile", icon: "person-circle-outline", route: "/(tabs)/profile" },
          ].map((q) => (
            <TouchableOpacity key={q.id} testID={`quick-top-${q.id}`} style={styles.topQuickItem} onPress={() => router.push(q.route as any)} activeOpacity={0.7}>
              <View style={styles.topQuickIcon}><Ionicons name={q.icon as any} size={22} color={colors.primary} /></View>
              <Text style={styles.topQuickLbl}>{q.label}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.dueCard} onPress={() => router.push("/(tabs)/payments")} activeOpacity={0.9} testID="home-due-card">
          <LinearGradient colors={mode === "dark" ? ["#2D1A0A", "#3F2410"] : ["#FEF3C7", "#FED7AA"]} style={styles.dueGradient}>
            <View style={{ flex: 1 }}>
              <Text style={styles.dueLbl}>FEES DUE</Text>
              <Text style={styles.dueAmt}>RM {student.nextPayment.amount.toLocaleString()}</Text>
              <Text style={styles.dueDate}>Due {student.nextPayment.dueDate}</Text>
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
        {today.sessions.slice(0, 1).map((s, i) => (
          <View key={i} style={styles.todayCard}>
            <View style={[styles.todayBar, { backgroundColor: s.color }]} />
            <View style={{ flex: 1 }}>
              <Text style={styles.todayTime}>{s.time} · {s.duration}</Text>
              <Text style={styles.todayTitle}>{s.title}</Text>
              <Text style={styles.todayTrainer}>with {s.trainer}</Text>
            </View>
            <TouchableOpacity style={styles.checkInBtn}>
              <Ionicons name="qr-code" size={14} color={colors.primary} />
              <Text style={styles.checkInTxt}>Check In</Text>
            </TouchableOpacity>
          </View>
        ))}

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

        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>Featured Event</Text>
          <TouchableOpacity onPress={() => router.push("/events")}><Text style={styles.sectionLink}>View all</Text></TouchableOpacity>
        </View>
        <TouchableOpacity activeOpacity={0.9} onPress={() => router.push("/events")} testID="home-event-banner">
          <ImageBackground source={{ uri: events[0].image }} style={styles.eventBanner} imageStyle={{ borderRadius: radius.xl }}>
            <LinearGradient colors={["rgba(15,23,42,0.05)", "rgba(15,23,42,0.85)"]} style={[StyleSheet.absoluteFillObject, { borderRadius: radius.xl }]} />
            <View style={styles.eventCountdown}>
              <Text style={styles.eventCountdownNum}>{events[0].countdown}</Text>
              <Text style={styles.eventCountdownLbl}>days</Text>
            </View>
            <View style={styles.eventBottom}>
              <Text style={styles.eventCat}>{events[0].category.toUpperCase()}</Text>
              <Text style={styles.eventTitle}>{events[0].title}</Text>
              <Text style={styles.eventMeta}>📅 {events[0].date}  ·  📍 {events[0].location}</Text>
            </View>
          </ImageBackground>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    headerBg: { paddingHorizontal: spacing.xl, paddingBottom: 30, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 },
    headerRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 6 },
    userRow: { flexDirection: "row", gap: 12, alignItems: "center" },
    avatar: { width: 52, height: 52, borderRadius: 26, borderWidth: 2, borderColor: "rgba(255,255,255,0.6)" },
    hi: { color: "rgba(255,255,255,0.85)", fontSize: 12 },
    name: { color: "#fff", fontSize: 18, fontWeight: "800", letterSpacing: -0.3 },
    badgeRow: { flexDirection: "row", alignItems: "center", gap: 4, marginTop: 4, backgroundColor: "rgba(255,255,255,0.22)", paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10, alignSelf: "flex-start" },
    badgeTxt: { color: "#FFF7ED", fontSize: 10, fontWeight: "700", letterSpacing: 0.3 },
    headerActions: { flexDirection: "row", alignItems: "center", gap: 10 },
    headerLogo: { width: 36, height: 36, borderRadius: 10, backgroundColor: "#fff" },
    bell: { width: 42, height: 42, borderRadius: 21, backgroundColor: "rgba(255,255,255,0.22)", alignItems: "center", justifyContent: "center" },
    dot: { position: "absolute", top: 10, right: 10, width: 8, height: 8, borderRadius: 4, backgroundColor: "#FDE68A", borderWidth: 2, borderColor: colors.primary },
    statRow: { flexDirection: "row", marginTop: 22, backgroundColor: "rgba(255,255,255,0.18)", borderRadius: radius.lg, paddingVertical: 14 },
    stat: { flex: 1, alignItems: "center" },
    statNum: { color: "#fff", fontSize: 18, fontWeight: "800" },
    statLbl: { color: "rgba(255,255,255,0.85)", fontSize: 10, marginTop: 2, letterSpacing: 0.5 },
    statSep: { width: 1, backgroundColor: "rgba(255,255,255,0.25)" },

    topQuick: { flexDirection: "row", backgroundColor: colors.surface, marginHorizontal: spacing.xl, marginTop: -20, borderRadius: radius.xl, paddingVertical: 16, paddingHorizontal: 8, ...shadow.card, justifyContent: "space-around", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    topQuickItem: { alignItems: "center", width: 72 },
    topQuickIcon: { width: 46, height: 46, borderRadius: 23, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center", marginBottom: 6 },
    topQuickLbl: { fontSize: 10, color: colors.textPrimary, fontWeight: "600", textAlign: "center" },

    dueCard: { marginHorizontal: spacing.xl, marginTop: 18 },
    dueGradient: { borderRadius: radius.xl, padding: 18, flexDirection: "row", alignItems: "center" },
    dueLbl: { color: mode === "dark" ? "#FDBA74" : "#9A3412", fontSize: 11, fontWeight: "700", letterSpacing: 0.5 },
    dueAmt: { color: mode === "dark" ? "#FED7AA" : "#7C2D12", fontSize: 24, fontWeight: "800", marginTop: 2 },
    dueDate: { color: mode === "dark" ? "#FDBA74" : "#9A3412", fontSize: 11, marginTop: 2, fontWeight: "500" },
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

    grid: { flexDirection: "row", flexWrap: "wrap", paddingHorizontal: spacing.lg, gap: 12 },
    gridCard: { width: "22.5%", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 12, alignItems: "center", ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    gridIcon: { width: 44, height: 44, borderRadius: 22, alignItems: "center", justifyContent: "center", marginBottom: 6 },
    gridLbl: { fontSize: 10, color: colors.textPrimary, fontWeight: "600", textAlign: "center", lineHeight: 13 },

    eventBanner: { height: 180, marginHorizontal: spacing.xl, borderRadius: radius.xl, overflow: "hidden", justifyContent: "space-between" },
    eventCountdown: { position: "absolute", top: 14, right: 14, backgroundColor: "rgba(255,255,255,0.95)", borderRadius: radius.md, paddingHorizontal: 10, paddingVertical: 8, alignItems: "center", minWidth: 54 },
    eventCountdownNum: { fontSize: 20, fontWeight: "800", color: colors.primary },
    eventCountdownLbl: { fontSize: 9, color: "#64748B", fontWeight: "700", letterSpacing: 1 },
    eventBottom: { padding: 16, marginTop: "auto" },
    eventCat: { color: "#FDBA74", fontSize: 10, fontWeight: "700", letterSpacing: 1.5 },
    eventTitle: { color: "#fff", fontSize: 18, fontWeight: "800", marginTop: 4 },
    eventMeta: { color: "rgba(255,255,255,0.85)", fontSize: 11, marginTop: 6 },
  });
}
