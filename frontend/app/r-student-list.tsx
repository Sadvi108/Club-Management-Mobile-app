import { useMemo, useState } from "react";
import { View, Text, StyleSheet, TextInput, TouchableOpacity, FlatList, ActivityIndicator } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { radius, spacing, useTheme } from "../src/theme";
import { ScreenHeader, SelectField, Option } from "../src/ui/reportkit";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import type { IdValueText } from "../src/api/types";

const STATUS_OPTIONS: Option[] = [
  { id: "Active", text: "Active" },
  { id: "Inactive", text: "Inactive" },
];

export default function StudentList() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const [centerId, setCenterId] = useState<number | string | null>(null);
  const [centerName, setCenterName] = useState<string>("");
  const [status, setStatus] = useState<number | string>("Active");
  const [name, setName] = useState("");

  // Search is explicit: a query token bumps on Search press; the fetch is gated on it (and the session token).
  const [query, setQuery] = useState<{ centerId: number | string; nonce: number } | null>(null);

  const centers = useApi<IdValueText[]>(
    () => (token ? api.dropdownListByType(3) : Promise.resolve([])),
    [token]
  );
  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));

  const students = useApi<IdValueText[]>(
    () => (token && query ? api.studentListByTcId(Number(query.centerId)) : Promise.resolve([])),
    [token, query?.centerId, query?.nonce]
  );

  const rows = useMemo(() => {
    const all = students.data ?? [];
    const q = name.trim().toLowerCase();
    return q ? all.filter((s) => (s.text || "").toLowerCase().includes(q)) : all;
  }, [students.data, name]);

  const onSearch = () => {
    if (centerId == null) return;
    setQuery({ centerId, nonce: Date.now() });
  };

  const loading = !!query && students.loading;
  const searched = !!query;

  return (
    <View style={styles.root} testID="rep-student-list">
      <ScreenHeader title="Student List" />

      <View style={styles.filterCard}>
        <SelectField
          label="Training Center"
          placeholder="Select a center"
          value={centerId}
          options={centerOptions}
          loading={centers.loading}
          onChange={(id, opt) => {
            setCenterId(id);
            setCenterName(opt.text);
          }}
          testID="sl-center"
        />

        <View style={styles.row}>
          <SelectField
            label="Status"
            value={status}
            options={STATUS_OPTIONS}
            onChange={(id) => setStatus(id)}
            compact
          />
          <View style={styles.nameWrap}>
            <Text style={styles.fieldLabel}>NAME</Text>
            <TextInput
              style={styles.nameInput}
              placeholder="Search name"
              placeholderTextColor={colors.textMuted}
              value={name}
              onChangeText={setName}
              autoCorrect={false}
            />
          </View>
        </View>

        <TouchableOpacity
          style={styles.searchBtn}
          onPress={onSearch}
          activeOpacity={0.9}
          disabled={loading}
          testID="sl-search"
        >
          {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.searchTxt}>Search</Text>}
        </TouchableOpacity>
      </View>

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={colors.primary} size="large" />
        </View>
      ) : students.error ? (
        <View style={styles.center}>
          <Ionicons name="alert-circle-outline" size={44} color={colors.danger} />
          <Text style={styles.errTxt}>{students.error}</Text>
        </View>
      ) : !searched ? (
        <View style={styles.center}>
          <Ionicons name="search-outline" size={44} color={colors.textMuted} />
          <Text style={styles.emptyTxt}>Choose a center and search.</Text>
        </View>
      ) : rows.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="people-outline" size={44} color={colors.textMuted} />
          <Text style={styles.emptyTxt}>No students found.</Text>
        </View>
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(item, i) => `${item.id}-${i}`}
          contentContainerStyle={{ padding: spacing.xl, paddingBottom: 140 }}
          showsVerticalScrollIndicator={false}
          ItemSeparatorComponent={() => <View style={{ height: 10 }} />}
          initialNumToRender={12}
          removeClippedSubviews
          renderItem={({ item }) => (
            <View style={styles.card}>
              <View style={styles.avatar}>
                <Ionicons name="person" size={22} color={colors.primary} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle} numberOfLines={1}>{item.text}</Text>
                <Text style={styles.cardMeta} numberOfLines={1}>Reg No: {item.value || "—"}</Text>
                <Text style={styles.cardMeta} numberOfLines={1}>Center: {centerName || "—"}</Text>
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
    row: { flexDirection: "row", alignItems: "flex-end", gap: 10 },
    nameWrap: { flex: 1 },
    fieldLabel: { fontSize: 11, fontWeight: "600", letterSpacing: 0.5, color: colors.textSecondary, marginBottom: 6, textTransform: "uppercase" },
    nameInput: {
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.full,
      paddingHorizontal: 16,
      minHeight: 46,
      fontSize: 14,
      fontWeight: "600",
      color: colors.textPrimary,
    },
    searchBtn: { backgroundColor: colors.primary, borderRadius: radius.full, paddingVertical: 13, alignItems: "center", justifyContent: "center", minHeight: 46 },
    searchTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
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
