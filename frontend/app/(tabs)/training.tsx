import { View, Text, StyleSheet, ScrollView, Image, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { colors, font, radius, shadow, spacing } from "../../src/theme";
import { programs } from "../../src/mockData";

export default function Training() {
  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <View>
            <Text style={styles.title}>My Training</Text>
            <Text style={styles.sub}>3 active programs · Keep pushing!</Text>
          </View>
          <TouchableOpacity style={styles.filterBtn} testID="training-filter-btn">
            <Ionicons name="options-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        {/* Training stats */}
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.heroCard}>
          <View style={styles.heroRow}>
            <Ionicons name="trophy" size={22} color="#FDE68A" />
            <Text style={styles.heroBadge}>WEEKLY STREAK</Text>
          </View>
          <Text style={styles.heroNum}>12 <Text style={styles.heroUnit}>days</Text></Text>
          <Text style={styles.heroMsg}>You&apos;re on fire! Don&apos;t break the chain 🔥</Text>
          <View style={styles.heroStatsRow}>
            <View style={styles.heroStat}>
              <Text style={styles.heroStatNum}>24</Text>
              <Text style={styles.heroStatLbl}>Classes</Text>
            </View>
            <View style={styles.heroStat}>
              <Text style={styles.heroStatNum}>18h</Text>
              <Text style={styles.heroStatLbl}>Trained</Text>
            </View>
            <View style={styles.heroStat}>
              <Text style={styles.heroStatNum}>3</Text>
              <Text style={styles.heroStatLbl}>Sports</Text>
            </View>
          </View>
        </LinearGradient>

        <Text style={styles.section}>Enrolled Programs</Text>

        {programs.map((p) => (
          <View key={p.id} style={styles.programCard} testID={`program-${p.id}`}>
            <Image source={{ uri: p.image }} style={styles.programImg} />
            <View style={styles.programBody}>
              <View style={styles.programTop}>
                <Text style={styles.programSport}>{p.sport}</Text>
                <View style={[styles.levelPill, { backgroundColor: p.color + "18" }]}>
                  <Text style={[styles.levelTxt, { color: p.color }]}>{p.level}</Text>
                </View>
              </View>
              <View style={styles.trainerRow}>
                <Ionicons name="person-circle-outline" size={16} color={colors.textSecondary} />
                <Text style={styles.trainerTxt}>{p.trainer}</Text>
              </View>

              <View style={styles.progressHead}>
                <Text style={styles.progLbl}>Progress to {p.nextMilestone}</Text>
                <Text style={[styles.progVal, { color: p.color }]}>{p.progress}%</Text>
              </View>
              <View style={styles.progBg}>
                <View style={[styles.progFill, { width: `${p.progress}%`, backgroundColor: p.color }]} />
              </View>

              <View style={styles.actionRow}>
                <TouchableOpacity style={[styles.actionBtn, styles.actionBtnPrimary, { backgroundColor: p.color }]} testID={`program-${p.id}-upgrade`}>
                  <Ionicons name="trending-up" size={14} color="#fff" />
                  <Text style={styles.actionBtnPrimaryTxt}>Upgrade Level</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.actionBtnGhost}>
                  <Ionicons name="information-circle-outline" size={18} color={colors.textSecondary} />
                </TouchableOpacity>
              </View>
            </View>
          </View>
        ))}

        <TouchableOpacity style={styles.addProgramBtn} testID="training-add-program">
          <Ionicons name="add-circle-outline" size={22} color={colors.primary} />
          <Text style={styles.addProgramTxt}>Add New Program</Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, paddingVertical: 14 },
  title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
  sub: { color: colors.textSecondary, fontSize: 12, marginTop: 2 },
  filterBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },

  heroCard: { borderRadius: radius.xl, padding: 20, marginBottom: 20, ...shadow.strong },
  heroRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  heroBadge: { color: "#FDE68A", fontSize: 11, fontWeight: "800", letterSpacing: 1.2 },
  heroNum: { color: "#fff", fontSize: 44, fontWeight: "800", marginTop: 4, letterSpacing: -1 },
  heroUnit: { fontSize: 16, fontWeight: "500", color: "rgba(255,255,255,0.8)" },
  heroMsg: { color: "rgba(255,255,255,0.85)", fontSize: 12, marginTop: 2 },
  heroStatsRow: { flexDirection: "row", marginTop: 16, gap: 12 },
  heroStat: { flex: 1, backgroundColor: "rgba(255,255,255,0.14)", borderRadius: radius.md, paddingVertical: 10, alignItems: "center" },
  heroStatNum: { color: "#fff", fontSize: 18, fontWeight: "800" },
  heroStatLbl: { color: "rgba(255,255,255,0.8)", fontSize: 10, marginTop: 2 },

  section: { ...font.h3, color: colors.textPrimary, marginBottom: 14 },
  programCard: { backgroundColor: "#fff", borderRadius: radius.xl, overflow: "hidden", marginBottom: 16, ...shadow.card },
  programImg: { width: "100%", height: 140 },
  programBody: { padding: 16 },
  programTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  programSport: { fontSize: 18, fontWeight: "800", color: colors.textPrimary },
  levelPill: { paddingHorizontal: 10, paddingVertical: 5, borderRadius: 20 },
  levelTxt: { fontSize: 11, fontWeight: "700" },
  trainerRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 6 },
  trainerTxt: { color: colors.textSecondary, fontSize: 13, fontWeight: "500" },
  progressHead: { flexDirection: "row", justifyContent: "space-between", marginTop: 14, marginBottom: 6 },
  progLbl: { color: colors.textSecondary, fontSize: 11, fontWeight: "600" },
  progVal: { fontSize: 13, fontWeight: "800" },
  progBg: { height: 8, backgroundColor: colors.surfaceAlt, borderRadius: 4, overflow: "hidden" },
  progFill: { height: "100%", borderRadius: 4 },
  actionRow: { flexDirection: "row", gap: 10, marginTop: 14 },
  actionBtn: { flex: 1, paddingVertical: 12, borderRadius: radius.md, alignItems: "center", justifyContent: "center", flexDirection: "row", gap: 6 },
  actionBtnPrimary: {},
  actionBtnPrimaryTxt: { color: "#fff", fontWeight: "700", fontSize: 13 },
  actionBtnGhost: { width: 44, borderRadius: radius.md, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceAlt },

  addProgramBtn: { flexDirection: "row", gap: 8, alignItems: "center", justifyContent: "center", paddingVertical: 16, borderRadius: radius.md, borderWidth: 1, borderStyle: "dashed", borderColor: colors.primary, backgroundColor: "#EEF2FF" },
  addProgramTxt: { color: colors.primary, fontWeight: "700", fontSize: 14 },
});
