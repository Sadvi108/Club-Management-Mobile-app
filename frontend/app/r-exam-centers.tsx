import { useMemo } from "react";
import { View, Text, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, KV } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { ExamCenterRow } from "../src/api/types";

export default function RExamCenters() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const { data, loading, error } = useApi(
    () => (token ? api.reportExamCenters() : Promise.resolve<ExamCenterRow[]>([])),
    [token]
  );

  return (
    <View style={styles.root} testID="rep-exam-centers">
      <ReportScaffold<ExamCenterRow>
        title="Exam Centers"
        loading={loading}
        error={error}
        data={data}
        keyExtractor={(item) => String(item.id)}
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={2}>{item.centername}</Text>
            <View style={styles.pillRow}>
              <View style={[styles.pill, { backgroundColor: colors.success + "22" }]}>
                <Ionicons name="people" size={13} color={colors.success} />
                <Text style={[styles.pillTxt, { color: colors.success }]}>{item.activeStudents} Active</Text>
              </View>
              <View style={[styles.pill, { backgroundColor: colors.danger + "22" }]}>
                <Ionicons name="people" size={13} color={colors.danger} />
                <Text style={[styles.pillTxt, { color: colors.danger }]}>{item.inactveStudents} Inactive</Text>
              </View>
            </View>
            <KV label="Code" value={item.shortid} />
          </View>
        )}
      />
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    card: {
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    pillRow: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 10 },
    pill: { flexDirection: "row", alignItems: "center", gap: 5, borderRadius: radius.full, paddingHorizontal: 10, paddingVertical: 5 },
    pillTxt: { fontSize: 12, fontWeight: "800" },
  });
}
