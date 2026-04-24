import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { colors, font, radius, shadow, spacing } from "../src/theme";
import { skills, achievements, trainerComments, student } from "../src/mockData";

const beltStages = [
  { name: "White", color: "#E5E7EB", done: true },
  { name: "Yellow", color: "#FDE68A", done: true },
  { name: "Orange", color: "#FED7AA", done: true },
  { name: "Green", color: "#86EFAC", done: true },
  { name: "Blue", color: "#93C5FD", done: true, current: true },
  { name: "Purple", color: "#C4B5FD", done: false },
  { name: "Brown", color: "#D6D3D1", done: false },
  { name: "Black", color: "#1F2937", done: false },
];

export default function Progress() {
  const router = useRouter();

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => router.back()} testID="progress-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Progress</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        {/* Fitness Score */}
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.fitCard}>
          <View style={{ flex: 1 }}>
            <Text style={styles.fitLbl}>FITNESS SCORE</Text>
            <Text style={styles.fitNum}>{student.fitness}<Text style={styles.fitUnit}>/100</Text></Text>
            <Text style={styles.fitMsg}>Excellent shape — keep the momentum</Text>
          </View>
          <View style={styles.fitIconWrap}>
            <Ionicons name="fitness" size={48} color="rgba(255,255,255,0.9)" />
          </View>
        </LinearGradient>

        {/* Belt journey */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Belt Journey</Text>
          <View style={styles.beltLine}>
            {beltStages.map((b, i) => (
              <View key={b.name} style={styles.beltItem}>
                <View style={[styles.beltDot, { backgroundColor: b.color }, b.current && styles.beltDotCurrent]}>
                  {b.done && !b.current && <Ionicons name="checkmark" size={12} color="#0F172A" />}
                  {b.current && <Ionicons name="star" size={14} color="#fff" />}
                </View>
                {i < beltStages.length - 1 && <View style={[styles.beltConnector, b.done && { backgroundColor: colors.primary }]} />}
              </View>
            ))}
          </View>
          <View style={styles.beltLabels}>
            {beltStages.map((b) => (
              <Text key={b.name} style={[styles.beltLbl, b.current && { color: colors.primary, fontWeight: "800" }]}>{b.name[0]}</Text>
            ))}
          </View>
          <View style={styles.beltStatus}>
            <View style={{ flex: 1 }}>
              <Text style={styles.beltStatusLbl}>CURRENT BELT</Text>
              <Text style={styles.beltStatusVal}>{student.belt}</Text>
            </View>
            <View style={{ flex: 1, alignItems: "flex-end" }}>
              <Text style={styles.beltStatusLbl}>NEXT EXAM</Text>
              <Text style={styles.beltStatusVal}>15 Apr 2026</Text>
            </View>
          </View>
        </View>

        {/* Skills */}
        <Text style={styles.section}>Skill Breakdown</Text>
        <View style={styles.card}>
          {skills.map((s) => (
            <View key={s.name} style={styles.skillRow}>
              <Text style={styles.skillName}>{s.name}</Text>
              <View style={styles.skillBar}>
                <View style={[styles.skillFill, { width: `${s.value}%`, backgroundColor: s.color }]} />
              </View>
              <Text style={[styles.skillVal, { color: s.color }]}>{s.value}</Text>
            </View>
          ))}
        </View>

        {/* Achievements */}
        <Text style={styles.section}>Achievement Badges</Text>
        <View style={styles.achieveRow}>
          {achievements.map((a) => (
            <View key={a.id} style={styles.achieveCard}>
              <View style={[styles.achieveIcon, { backgroundColor: a.color + "20" }]}>
                <Ionicons name={a.icon as any} size={22} color={a.color} />
              </View>
              <Text style={styles.achieveLbl}>{a.title}</Text>
            </View>
          ))}
        </View>

        {/* Trainer Comments */}
        <Text style={styles.section}>Trainer Feedback</Text>
        {trainerComments.map((c, i) => (
          <View key={i} style={styles.commentCard}>
            <View style={styles.quoteIcon}>
              <Ionicons name="chatbox-ellipses" size={16} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.commentTxt}>&ldquo;{c.comment}&rdquo;</Text>
              <Text style={styles.commentMeta}>— {c.trainer} · {c.date}</Text>
            </View>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
  backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
  title: { ...font.h3, color: colors.textPrimary },

  fitCard: { flexDirection: "row", borderRadius: radius.xxl, padding: 20, ...shadow.strong },
  fitLbl: { color: "#FDE68A", fontSize: 11, fontWeight: "800", letterSpacing: 1.2 },
  fitNum: { color: "#fff", fontSize: 44, fontWeight: "800", marginTop: 4, letterSpacing: -1 },
  fitUnit: { fontSize: 18, fontWeight: "600", color: "rgba(255,255,255,0.8)" },
  fitMsg: { color: "rgba(255,255,255,0.85)", fontSize: 12 },
  fitIconWrap: { width: 80, height: 80, borderRadius: 40, backgroundColor: "rgba(255,255,255,0.14)", alignItems: "center", justifyContent: "center" },

  card: { backgroundColor: "#fff", borderRadius: radius.xl, padding: 18, marginTop: 16, ...shadow.soft },
  cardTitle: { ...font.h4, color: colors.textPrimary, marginBottom: 14 },

  beltLine: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  beltItem: { flexDirection: "row", alignItems: "center", flex: 1 },
  beltDot: { width: 26, height: 26, borderRadius: 13, alignItems: "center", justifyContent: "center" },
  beltDotCurrent: { width: 32, height: 32, borderRadius: 16, borderWidth: 2, borderColor: colors.primary, backgroundColor: colors.primary },
  beltConnector: { flex: 1, height: 2, backgroundColor: colors.border },
  beltLabels: { flexDirection: "row", justifyContent: "space-between", marginTop: 8, paddingHorizontal: 6 },
  beltLbl: { fontSize: 10, color: colors.textSecondary, fontWeight: "600", width: 26, textAlign: "center" },
  beltStatus: { flexDirection: "row", marginTop: 16, paddingTop: 14, borderTopWidth: 1, borderTopColor: colors.borderLight },
  beltStatusLbl: { fontSize: 10, color: colors.textSecondary, fontWeight: "700", letterSpacing: 0.5 },
  beltStatusVal: { fontSize: 15, color: colors.textPrimary, fontWeight: "800", marginTop: 4 },

  section: { ...font.h4, color: colors.textPrimary, marginTop: 22, marginBottom: 10 },
  skillRow: { flexDirection: "row", alignItems: "center", paddingVertical: 8 },
  skillName: { width: 80, fontSize: 13, fontWeight: "600", color: colors.textPrimary },
  skillBar: { flex: 1, height: 10, backgroundColor: colors.surfaceAlt, borderRadius: 5, overflow: "hidden", marginRight: 10 },
  skillFill: { height: "100%", borderRadius: 5 },
  skillVal: { fontSize: 13, fontWeight: "800", width: 30, textAlign: "right" },

  achieveRow: { flexDirection: "row", gap: 10 },
  achieveCard: { flex: 1, backgroundColor: "#fff", borderRadius: radius.md, padding: 12, alignItems: "center", ...shadow.soft },
  achieveIcon: { width: 46, height: 46, borderRadius: 23, alignItems: "center", justifyContent: "center", marginBottom: 6 },
  achieveLbl: { fontSize: 10, color: colors.textPrimary, fontWeight: "700", textAlign: "center" },

  commentCard: { flexDirection: "row", gap: 12, backgroundColor: "#fff", padding: 14, borderRadius: radius.lg, marginBottom: 10, ...shadow.soft },
  quoteIcon: { width: 32, height: 32, borderRadius: 16, backgroundColor: "#EEF2FF", alignItems: "center", justifyContent: "center" },
  commentTxt: { fontSize: 13, color: colors.textPrimary, fontWeight: "500", fontStyle: "italic", lineHeight: 18 },
  commentMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 6, fontWeight: "600" },
});
