import { useState } from "react";
import { View, Text, StyleSheet, ScrollView, Image, TouchableOpacity, ImageBackground } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { colors, font, radius, shadow, spacing } from "../src/theme";
import { events, certificates } from "../src/mockData";

const tabs = ["Upcoming", "Registered", "Certificates"];

export default function Events() {
  const router = useRouter();
  const [tab, setTab] = useState(0);
  const filtered = tab === 1 ? events.filter((e) => e.registered) : events;

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => router.back()} testID="events-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Events & Competition</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <View style={styles.tabsRow}>
        {tabs.map((t, i) => (
          <TouchableOpacity
            key={t}
            style={[styles.tab, tab === i && styles.tabActive]}
            onPress={() => setTab(i)}
            testID={`events-tab-${i}`}
          >
            <Text style={[styles.tabTxt, tab === i && styles.tabTxtActive]}>{t}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        {tab !== 2 ? (
          filtered.map((e) => (
            <TouchableOpacity key={e.id} activeOpacity={0.92} style={styles.eventCard} testID={`event-${e.id}`}>
              <ImageBackground source={{ uri: e.image }} style={styles.eventImg} imageStyle={{ borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl }}>
                <LinearGradient colors={["rgba(15,23,42,0)", "rgba(15,23,42,0.8)"]} style={[StyleSheet.absoluteFillObject, { borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl }]} />
                {e.registered && (
                  <View style={styles.registeredBadge}>
                    <Ionicons name="checkmark-circle" size={12} color="#fff" />
                    <Text style={styles.registeredTxt}>REGISTERED</Text>
                  </View>
                )}
                <View style={styles.catPill}>
                  <Text style={styles.catTxt}>{e.category.toUpperCase()}</Text>
                </View>
                <View style={styles.countdownOverlay}>
                  <Text style={styles.countdownNum}>{e.countdown}</Text>
                  <Text style={styles.countdownLbl}>DAYS TO GO</Text>
                </View>
              </ImageBackground>
              <View style={styles.eventBody}>
                <Text style={styles.eventTitle}>{e.title}</Text>
                <View style={styles.eventMetaRow}>
                  <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                  <Text style={styles.eventMeta}>{e.date}</Text>
                  <Ionicons name="location-outline" size={14} color={colors.textSecondary} style={{ marginLeft: 10 }} />
                  <Text style={styles.eventMeta}>{e.location}</Text>
                </View>
                <TouchableOpacity style={[styles.regBtn, e.registered && { backgroundColor: colors.success }]} testID={`event-${e.id}-btn`}>
                  <Ionicons name={e.registered ? "checkmark" : "flash"} size={14} color="#fff" />
                  <Text style={styles.regBtnTxt}>{e.registered ? "View Details" : "Register Now"}</Text>
                </TouchableOpacity>
              </View>
            </TouchableOpacity>
          ))
        ) : (
          <View>
            {certificates.map((c) => (
              <View key={c.id} style={styles.certCard}>
                <LinearGradient colors={["#FEF3C7", "#FDE68A"]} style={styles.certRibbon}>
                  <Ionicons name="ribbon" size={22} color="#92400E" />
                </LinearGradient>
                <View style={{ flex: 1 }}>
                  <Text style={styles.certTitle}>{c.title}</Text>
                  <Text style={styles.certMeta}>Issued by {c.issuer} · {c.date}</Text>
                </View>
                <TouchableOpacity style={styles.dlBtn}>
                  <Ionicons name="download-outline" size={18} color={colors.primary} />
                </TouchableOpacity>
              </View>
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
  backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
  title: { ...font.h3, color: colors.textPrimary },

  tabsRow: { flexDirection: "row", paddingHorizontal: spacing.xl, paddingVertical: 12, gap: 8 },
  tab: { flex: 1, paddingVertical: 10, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, alignItems: "center" },
  tabActive: { backgroundColor: colors.primary },
  tabTxt: { fontSize: 12, fontWeight: "700", color: colors.textSecondary },
  tabTxtActive: { color: "#fff" },

  eventCard: { backgroundColor: "#fff", borderRadius: radius.xl, marginBottom: 16, ...shadow.card, overflow: "hidden" },
  eventImg: { height: 180, justifyContent: "space-between" },
  catPill: { position: "absolute", top: 14, left: 14, backgroundColor: "rgba(255,255,255,0.95)", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10 },
  catTxt: { color: colors.primary, fontSize: 10, fontWeight: "800", letterSpacing: 1 },
  registeredBadge: { position: "absolute", top: 14, right: 14, flexDirection: "row", gap: 4, alignItems: "center", backgroundColor: colors.success, paddingHorizontal: 10, paddingVertical: 5, borderRadius: 12 },
  registeredTxt: { color: "#fff", fontSize: 10, fontWeight: "800", letterSpacing: 1 },
  countdownOverlay: { position: "absolute", bottom: 14, right: 14, backgroundColor: "rgba(255,255,255,0.95)", paddingHorizontal: 14, paddingVertical: 8, borderRadius: radius.md, alignItems: "center", minWidth: 72 },
  countdownNum: { color: colors.primary, fontSize: 22, fontWeight: "800" },
  countdownLbl: { color: colors.textSecondary, fontSize: 9, fontWeight: "800", letterSpacing: 1 },

  eventBody: { padding: 16 },
  eventTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
  eventMetaRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 8, flexWrap: "wrap" },
  eventMeta: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },
  regBtn: { flexDirection: "row", gap: 6, backgroundColor: colors.primary, paddingVertical: 12, borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginTop: 12 },
  regBtnTxt: { color: "#fff", fontWeight: "700", fontSize: 13 },

  certCard: { flexDirection: "row", gap: 14, alignItems: "center", backgroundColor: "#fff", padding: 14, borderRadius: radius.lg, marginBottom: 12, ...shadow.soft },
  certRibbon: { width: 50, height: 50, borderRadius: radius.md, alignItems: "center", justifyContent: "center" },
  certTitle: { fontSize: 14, fontWeight: "800", color: colors.textPrimary },
  certMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 3 },
  dlBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: "#EEF2FF", alignItems: "center", justifyContent: "center" },
});
