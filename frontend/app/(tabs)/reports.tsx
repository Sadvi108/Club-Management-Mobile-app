import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useBottomTabBarHeight } from "@react-navigation/bottom-tabs";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../../src/theme";

type ReportRow = { id: string; label: string; icon: keyof typeof Ionicons.glyphMap; route: string };

const REPORTS: ReportRow[] = [
  { id: "student-centers", label: "Student Centers", icon: "business-outline", route: "/r-student-centers" },
  { id: "training-centers", label: "Training Centers", icon: "barbell-outline", route: "/r-training-centers" },
  { id: "exam-centers", label: "Exam Centers", icon: "clipboard-outline", route: "/r-exam-centers" },
  { id: "student-list", label: "Student List", icon: "people-outline", route: "/r-student-list" },
  { id: "training-time", label: "Training Schedule", icon: "time-outline", route: "/r-training-schedule" },
  { id: "grading-schedule", label: "Grading Schedule", icon: "school-outline", route: "/r-grading" },
  { id: "outstanding", label: "Outstanding Report", icon: "alert-circle-outline", route: "/r-outstanding" },
  { id: "attendance", label: "Attendance Report", icon: "checkmark-done-circle-outline", route: "/r-attendance" },
  { id: "receipt", label: "Receipt Report", icon: "receipt-outline", route: "/r-receipts" },
  { id: "grading-past", label: "Grade Completed", icon: "ribbon-outline", route: "/r-grading" },
  { id: "purchase-request", label: "Purchase Requests", icon: "cart-outline", route: "/r-purchase-requests" },
  { id: "payment-slip", label: "Payment Slips", icon: "document-attach-outline", route: "/r-payment-slips" },
  { id: "tournaments-past", label: "Tournaments (Past)", icon: "trophy-outline", route: "/r-tournament-past" },
  { id: "upcoming-tournaments", label: "Upcoming Tournaments", icon: "medal-outline", route: "/r-tournament-upcoming" },
  { id: "contribution", label: "Contribution Report", icon: "git-compare-outline", route: "/r-contribution" },
  { id: "reimbursement", label: "Reimbursement", icon: "cash-outline", route: "/r-reimbursement" },
  { id: "pay-dues", label: "Pay Your Dues", icon: "card-outline", route: "/pay-dues" },
];

export default function Reports() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const tabBarHeight = useBottomTabBarHeight();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  return (
    <View style={styles.root} testID="instructor-reports">
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
        <LinearGradient
          colors={colors.gradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.headerBg}
        >
          <View style={styles.headerRow}>
            <View style={styles.headerIcon}>
              <Ionicons name="document-text" size={20} color="#fff" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.title}>Reports</Text>
              <Text style={styles.subtitle}>Tap a report to view details</Text>
            </View>
          </View>
        </LinearGradient>
      </SafeAreaView>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingHorizontal: spacing.xl, paddingTop: 16, paddingBottom: tabBarHeight + 24 }}
        showsVerticalScrollIndicator={false}
      >
        {REPORTS.map((r) => (
          <TouchableOpacity
            key={r.id}
            testID={`report-${r.id}`}
            style={styles.row}
            activeOpacity={0.85}
            onPress={() => router.push(r.route as any)}
          >
            <View style={styles.rowIcon}>
              <Ionicons name={r.icon} size={20} color={colors.primary} />
            </View>
            <Text style={styles.rowLabel} numberOfLines={1}>{r.label}</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
          </TouchableOpacity>
        ))}
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
      paddingBottom: 24,
      borderBottomLeftRadius: 28,
      borderBottomRightRadius: 28,
    },
    headerRow: { flexDirection: "row", alignItems: "center", gap: 12 },
    headerIcon: {
      width: 44,
      height: 44,
      borderRadius: 22,
      backgroundColor: "rgba(255,255,255,0.22)",
      alignItems: "center",
      justifyContent: "center",
    },
    title: { color: "#fff", fontSize: 22, fontWeight: "800", letterSpacing: -0.3 },
    subtitle: { color: "rgba(255,255,255,0.85)", fontSize: 12, marginTop: 3 },

    row: {
      flexDirection: "row",
      gap: 14,
      alignItems: "center",
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 16,
      marginTop: 12,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    rowIcon: {
      width: 40,
      height: 40,
      borderRadius: 20,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    rowLabel: { flex: 1, ...font.h4, color: colors.textPrimary },
  });
}
