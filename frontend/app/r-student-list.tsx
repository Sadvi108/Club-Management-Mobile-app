import { useMemo, useState } from "react";
import { View, Text, StyleSheet, TextInput, FlatList, ActivityIndicator, Image } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { radius, spacing, useTheme } from "../src/theme";
import { ScreenHeader, SelectField, Option } from "../src/ui/reportkit";
import { useAuth } from "../src/api/auth";
import { api, parseStudentQr, studentQrContent } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import type { IdValueText } from "../src/api/types";

type Student = IdValueText & { centerName: string; centerId: number | string };

/**
 * Photo for a roster row.
 *
 * `/Listing/StudentListByTcId` returns `{ id, value, text }` only — no photo — and no other
 * mobile route exposes one for a list of students: display pictures are stored under
 * `Files/DP/<guid>.png` (a per-student GUID, see `AuthUser.profilePic`), so the URL cannot be
 * derived from a student id. This reads whichever field the backend adds, so the roster starts
 * showing real photos the moment the endpoint returns one; until then every row falls back to
 * the initials avatar below instead of one identical grey silhouette.
 */
function photoOf(s: any): string | null {
  const raw = s?.photo ?? s?.profilePic ?? s?.dp ?? s?.imageUrl ?? s?.picture;
  const url = typeof raw === "string" ? raw.trim() : "";
  if (!url) return null;
  return /^https?:\/\//i.test(url) ? url : `https://www.maclubsystem.com/${url.replace(/^\/+/, "")}`;
}

function initialsOf(name?: string) {
  return (
    (name || "?")
      .trim()
      .split(/\s+/)
      .map((w) => w[0])
      .slice(0, 2)
      .join("")
      .toUpperCase() || "?"
  );
}

// Stable per-student tint so a roster reads as a list of people rather than a wall of grey.
const AVATAR_TINTS = ["#4F46E5", "#0EA5E9", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#DB2777", "#14B8A6"];
const tintFor = (id: number | string) => {
  const n = String(id);
  let h = 0;
  for (let i = 0; i < n.length; i++) h = (h * 31 + n.charCodeAt(i)) >>> 0;
  return AVATAR_TINTS[h % AVATAR_TINTS.length];
};


export default function StudentList() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const [centerId, setCenterId] = useState<number | string>(""); // "" = All Centers
  const [name, setName] = useState("");
  const [ic, setIc] = useState("");
  const [qr, setQr] = useState("");

  const centers = useApi<IdValueText[]>(
    () => (token ? api.dropdownListByType(3) : Promise.resolve([])),
    [token]
  );
  const centerOptions: Option[] = [
    { id: "", text: "All Centers" },
    ...(centers.data ?? []).map((o) => ({ id: o.id, text: o.text })),
  ];

  // Load every center's students up-front (parallel) so the full roster shows without searching.
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

  // All controls filter the already-loaded list client-side (live).
  const rows = useMemo(() => {
    let all = students.data ?? [];
    if (centerId !== "") all = all.filter((s) => String(s.centerId) === String(centerId));
    const n = name.trim().toLowerCase();
    if (n) all = all.filter((s) => (s.text || "").toLowerCase().includes(n));
    const i = ic.trim().toLowerCase();
    if (i) all = all.filter((s) => (s.value || "").toLowerCase().includes(i));
    const q = qr.trim().toLowerCase();
    if (q) {
      // A scanned student QR carries `ST-00089623`, not the bare id — match on the student id it
      // encodes so scanning the academy's printed code (or the one on the student's profile) finds
      // the row. Anything else still matches a reg no / name / id as typed.
      const scannedId = parseStudentQr(qr);
      all = all.filter(
        (s) =>
          (scannedId != null && Number(s.id) === scannedId) ||
          (s.value || "").toLowerCase() === q ||
          (s.text || "").toLowerCase() === q ||
          String(s.id) === q ||
          studentQrContent(s.id).toLowerCase() === q
      );
    }
    return all;
  }, [students.data, centerId, name, ic, qr]);

  const loading = centers.loading || students.loading;
  const anyFilter = centerId !== "" || !!name || !!ic || !!qr;

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
        <View style={styles.row}>
          <Field label="Name" value={name} onChange={setName} placeholder="Search name" colors={colors} testID="sl-name" />
        </View>
        <View style={styles.row}>
          <Field label="IC No." value={ic} onChange={setIc} placeholder="IC / Reg no" colors={colors} testID="sl-ic" />
          <Field label="QR Code" value={qr} onChange={setQr} placeholder="Scan / paste code" colors={colors} icon="qr-code-outline" testID="sl-qr" />
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
          <Text style={styles.emptyTxt}>{anyFilter ? "No students match your filters." : "No students found."}</Text>
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
          renderItem={({ item }) => {
            const photo = photoOf(item);
            return (
              <View style={styles.card}>
                {photo ? (
                  <Image source={{ uri: photo }} style={styles.avatar} testID={`sl-photo-${item.id}`} />
                ) : (
                  <View style={[styles.avatar, styles.avatarFallback, { backgroundColor: tintFor(item.id) + "22" }]}>
                    <Text style={[styles.avatarTxt, { color: tintFor(item.id) }]}>{initialsOf(item.text)}</Text>
                  </View>
                )}
                <View style={{ flex: 1 }}>
                  <Text style={styles.cardTitle} numberOfLines={1}>{item.text || "—"}</Text>
                  <Text style={styles.cardMeta} numberOfLines={1}>Reg / IC No: {item.value || "—"}</Text>
                  <Text style={styles.cardMeta} numberOfLines={1}>Center: {item.centerName || "—"}</Text>
                </View>
              </View>
            );
          }}
        />
      )}
    </View>
  );
}

function Field({ label, value, onChange, placeholder, colors, icon, testID }: {
  label: string; value: string; onChange: (v: string) => void; placeholder: string; colors: any;
  icon?: keyof typeof Ionicons.glyphMap; testID?: string;
}) {
  return (
    <View style={{ flex: 1 }}>
      <Text style={{ fontSize: 11, fontWeight: "600", letterSpacing: 0.5, color: colors.textSecondary, marginBottom: 6, textTransform: "uppercase" }}>{label}</Text>
      <View style={{ flexDirection: "row", alignItems: "center", gap: 6, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, borderRadius: radius.full, paddingHorizontal: 14, minHeight: 46 }}>
        {icon && <Ionicons name={icon} size={15} color={colors.textMuted} />}
        <TextInput
          style={{ flex: 1, fontSize: 14, fontWeight: "600", color: colors.textPrimary, paddingVertical: 10 }}
          placeholder={placeholder}
          placeholderTextColor={colors.textMuted}
          value={value}
          onChangeText={onChange}
          autoCorrect={false}
          autoCapitalize="characters"
          testID={testID}
        />
        {value.length > 0 && <Ionicons name="close-circle" size={16} color={colors.textMuted} onPress={() => onChange("")} />}
      </View>
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
    avatar: { width: 48, height: 48, borderRadius: 24, backgroundColor: colors.surfaceAlt },
    avatarFallback: { alignItems: "center", justifyContent: "center" },
    avatarTxt: { fontSize: 16, fontWeight: "800", letterSpacing: 0.5 },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    cardMeta: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  });
}
