import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { IdValueText, ReportRow } from "../src/api/types";

export default function RTrainingSchedule() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [centerId, setCenterId] = useState<number | string | null>(null);

  const centers = useApi<IdValueText[]>(
    () => (token ? api.dropdownListByType(3) : Promise.resolve([])),
    [token]
  );
  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));

  const schedule = useApi<ReportRow[]>(
    () => (token && centerId ? api.trainingTimeByTcId(Number(centerId)) : Promise.resolve([])),
    [token, centerId]
  );

  const filters = (
    <SelectField
      label="Training Center"
      placeholder="Select a training center"
      value={centerId}
      options={centerOptions}
      onChange={(id) => setCenterId(id)}
      loading={centers.loading}
      testID="rts-center"
    />
  );

  return (
    <View style={styles.root} testID="rep-training-schedule">
      <ReportScaffold<ReportRow>
        title="Training Schedule"
        filters={filters}
        loading={schedule.loading && !!centerId}
        error={schedule.error}
        data={centerId ? schedule.data : null}
        emptyText="Select a training center to view its schedule."
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={2}>{item.text || "—"}</Text>
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
  });
}
