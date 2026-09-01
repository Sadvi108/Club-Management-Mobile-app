import { useMemo } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, KV } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { TrainingCenterRow } from "../src/api/types";

export default function RTrainingCenters() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const { data, loading, error } = useApi(
    () => (token ? api.reportTrainingCenters() : Promise.resolve<TrainingCenterRow[]>([])),
    [token]
  );

  return (
    <View style={styles.root} testID="rep-training-centers">
      <ReportScaffold<TrainingCenterRow>
        title="Training Centers"
        loading={loading}
        error={error}
        data={data}
        keyExtractor={(item) => String(item.id)}
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={2}>{item.name}</Text>
            <KV label="Code" value={item.code} />
            <KV label="Address" value={item.address} />
            <KV label="Total Classes" value={item.totalClasses} />
            <KV label="Total Students" value={item.totalStudents} strong />
            <KV label="Assigned" value={item.studentAssigned} />
            <KV label="Not Assigned" value={item.studentNotAssigned} />
            <KV label="Exam Center Students" value={item.examCentersAssignedStudents} />
            <KV label="Advance Training" value={item.advanceTrainingStudents} />
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
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginBottom: 4 },
  });
}
