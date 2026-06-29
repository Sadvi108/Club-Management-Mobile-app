import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { notify } from "../../src/ui/dialogs";

type ReportRow = { id: string; label: string; icon: keyof typeof Ionicons.glyphMap };

const REPORTS: ReportRow[] = [
  { id: "student-centers", label: "Student Centers", icon: "business-outline" },
  { id: "training-centers", label: "Training Centers", icon: "barbell-outline" },
  { id: "exam-centers", label: "Exam Centers", icon: "clipboard-outline" },
  { id: "student-list", label: "Student List", icon: "people-outline" },
  { id: "training-time", label: "Training Time", icon: "time-outline" },
  { id: "grading-schedule", label: "Grading Schedule", icon: "school-outline" },
  { id: "outstanding", label: "Outstanding Report", icon: "alert-circle-outline" },
  { id: "attendance", label: "Attendance Report", icon: "checkmark-done-circle-outline" },
  { id: "receipt", label: "Receipt", icon: "receipt-outline" },
  { id: "grading-past", label: "Grading (Past)", icon: "ribbon-outline" },
  { id: "purchase-request", label: "Purchase Request", icon: "cart-outline" },
  { id: "payment-slip", label: "Payment Slip", icon: "document-attach-outline" },
  { id: "tournaments-past", label: "Tournaments (Past)", icon: "trophy-outline" },
  { id: "upcoming-tournaments", label: "Upcoming Tournaments", icon: "medal-outline" },
  { id: "reimbursement", label: "Reimbursement", icon: "cash-outline" },
];

export default function Reports() {
  const { colors, shadow, mode } = useTheme();
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
        contentContainerStyle={{ paddingHorizontal: spacing.xl, paddingTop: 16, paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
      >
        {REPORTS.map((r) => (
          <TouchableOpacity
            key={r.id}
            testID={`report-${r.id}`}
            style={styles.row}
            activeOpacity={0.85}
            onPress={() => notify(r.label, "This report is coming soon.")}
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
