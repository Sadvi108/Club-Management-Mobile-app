import { useMemo, useState } from "react";
import { View, Text, StyleSheet, TextInput, FlatList, ActivityIndicator } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { radius, spacing, useTheme } from "../src/theme";
import { ScreenHeader, SelectField, Option } from "../src/ui/reportkit";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import type { IdValueText } from "../src/api/types";

type Student = IdValueText & { centerName: string; centerId: number | string };

export default function StudentList() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const [centerId, setCenterId] = useState<number | string>(""); // "" = All Centers
  const [name, setName] = useState("");

  const centers = useApi<IdValueText[]>(
    () => (token ? api.dropdownListByType(3) : Promise.resolve([])),
    [token]
  );
  const centerOptions: Option[] = [
    { id: "", text: "All Centers" },
    ...(centers.data ?? []).map((o) => ({ id: o.id, text: o.text })),
  ];

  // Load every center's students up-front (parallel), so the full list shows without searching.
  const students = useApi<Student[]>(
    () => {
      const list = centers.data;
      if (!token || !list?.length) return Promise.resolve([]);
      return Promise.all(
        list.map((c) =>
          api
            .studentListByTcId(Number(c.id))
            .then((rows) => (rows ?? []).map((s) => ({ ...s, centerName: c.text, centerId: c.id })))
            .catch(() => [] as Student[])
        )
      ).then((arr) => arr.flat());
    },
    [token, centers.data]
  );

  // Center + name are pure client-side filters over the already-loaded list.
  const rows = useMemo(() => {
    let all = students.data ?? [];
    if (centerId !== "") all = all.filter((s) => String(s.centerId) === String(centerId));
    const q = name.trim().toLowerCase();
    if (q) all = all.filter((s) => (s.text || "").toLowerCase().includes(q) || (s.value || "").toLowerCase().includes(q));
    return all;
  }, [students.data, centerId, name]);

  const loading = centers.loading || students.loading;

  return (
    <View style={styles.root} testID="rep-student-list">
      <ScreenHeader title="Student List" subtitle={loading ? "Loading…" : `${rows.length} student${rows.length === 1 ? "" : "s"}`} />

      <View style={styles.filterCard}>
        <SelectField
          label="Training Center"
          placeholder="All Centers"
          value={centerId}
          options={centerOptions}
          loading={centers.loading}
          onChange={(id) => setCenterId(id)}
          testID="sl-center"
        />
        <View style={styles.searchWrap}>
          <Ionicons name="search" size={16} color={colors.textMuted} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search by name or reg no"
            placeholderTextColor={colors.textMuted}
            value={name}
            onChangeText={setName}
            autoCorrect={false}
            autoCapitalize="none"
            testID="sl-name"
          />
          {name.length > 0 && (
            <Ionicons name="close-circle" size={18} color={colors.textMuted} onPress={() => setName("")} />
          )}
        </View>
      </View>

      {loading ? (
        <View style={styles.center}><ActivityIndicator color={colors.primary} size="large" /></View>
      ) : students.error ? (
        <View style={styles.center}>
          <Ionicons name="alert-circle-outline" size={44} color={colors.danger} />
          <Text style={styles.errTxt}>{students.error}</Text>
        </View>
      ) : rows.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="people-outline" size={44} color={colors.textMuted} />
          <Text style={styles.emptyTxt}>{name || centerId !== "" ? "No students match your filters." : "No students found."}</Text>
        </View>
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(item, i) => `${item.id}-${i}`}
          contentContainerStyle={{ padding: spacing.xl, paddingBottom: 140 }}
          showsVerticalScrollIndicator={false}
          ItemSeparatorComponent={() => <View style={{ height: 10 }} />}
          initialNumToRender={14}
          removeClippedSubviews
          keyboardShouldPersistTaps="handled"
          renderItem={({ item }) => (
            <View style={styles.card}>
              <View style={styles.avatar}>
                <Ionicons name="person" size={22} color={colors.primary} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle} numberOfLines={1}>{item.text || "—"}</Text>
                <Text style={styles.cardMeta} numberOfLines={1}>Reg No: {item.value || "—"}</Text>
                <Text style={styles.cardMeta} numberOfLines={1}>Center: {item.centerName || "—"}</Text>
              </View>
            </View>
          )}
        />
      )}
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    filterCard: {
      backgroundColor: colors.surfaceAlt,
      marginHorizontal: spacing.xl,
      marginTop: 4,
      marginBottom: 6,
      borderRadius: radius.xl,
      padding: 14,
      gap: 10,
    },
    searchWrap: {
      flexDirection: "row",
      alignItems: "center",
      gap: 8,
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.full,
      paddingHorizontal: 16,
      minHeight: 46,
    },
    searchInput: { flex: 1, fontSize: 14, fontWeight: "600", color: colors.textPrimary, paddingVertical: 10 },
    center: { flex: 1, alignItems: "center", justifyContent: "center", padding: 40, gap: 10 },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center" },
    errTxt: { color: colors.danger, fontSize: 14, textAlign: "center" },
    card: {
      flexDirection: "row",
      gap: spacing.md,
      alignItems: "center",
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    avatar: { width: 48, height: 48, borderRadius: 24, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    cardMeta: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  });
}
