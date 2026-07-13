import { useMemo, useState } from "react";
import {
  View, Text, StyleSheet, TouchableOpacity, Modal, TextInput, FlatList, ScrollView, ActivityIndicator,
} from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../theme";
import { safeBack } from "./dialogs";
import { SkeletonList } from "./skeleton";

// Shared building blocks for the instructor report / filter screens. Everything here matches the
// D-CLIX design system (theme tokens, Ionicons, surface cards, light/dark parity, 44pt targets,
// smooth bottom-sheet pickers). Screens stay thin: a header, a filter row, and a renderItem.

export type Option = { id: number | string; text: string };

// ── Screen header (plain surface bar with back) ──────────────────────────────
export function ScreenHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  const router = useRouter();
  const { colors } = useTheme();
  const s = useMemo(() => hStyles(colors), [colors]);
  return (
    <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
      <View style={s.row}>
        <TouchableOpacity style={s.back} onPress={() => safeBack(router)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} testID="rk-back">
          <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
        </TouchableOpacity>
        <View style={{ flex: 1 }}>
          <Text style={s.title} numberOfLines={1}>{title}</Text>
          {subtitle ? <Text style={s.subtitle} numberOfLines={1}>{subtitle}</Text> : null}
        </View>
      </View>
    </SafeAreaView>
  );
}

// ── Dropdown that opens a bottom-sheet list (searchable for long lists) ───────
export function SelectField({
  label, placeholder, value, options, onChange, loading, disabled, searchable, testID, compact,
}: {
  label?: string; placeholder?: string; value?: number | string | null;
  options: Option[]; onChange: (id: number | string, opt: Option) => void;
  loading?: boolean; disabled?: boolean; searchable?: boolean; testID?: string; compact?: boolean;
}) {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const s = useMemo(() => fStyles(colors), [colors]);
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const selected = options.find((o) => String(o.id) === String(value));
  const showSearch = searchable ?? options.length > 8;
  const filtered = q ? options.filter((o) => (o.text || "").toLowerCase().includes(q.toLowerCase())) : options;

  return (
    <View style={{ flex: compact ? 1 : undefined }}>
      {label ? <Text style={s.label}>{label}</Text> : null}
      <TouchableOpacity
        style={[s.field, disabled && { opacity: 0.5 }]}
        disabled={disabled || loading}
        onPress={() => setOpen(true)}
        activeOpacity={0.7}
        testID={testID}
      >
        <Text style={[s.value, !selected && s.placeholder]} numberOfLines={1}>
          {loading ? "Loading…" : selected?.text || placeholder || "Select"}
        </Text>
        <Ionicons name="chevron-down" size={18} color={colors.textMuted} />
      </TouchableOpacity>

      <Modal visible={open} transparent animationType="slide" onRequestClose={() => setOpen(false)}>
        <TouchableOpacity style={s.backdrop} activeOpacity={1} onPress={() => setOpen(false)}>
          <TouchableOpacity activeOpacity={1} style={[s.sheet, { paddingBottom: 16 + insets.bottom }]}>
            <View style={s.handle} />
            <Text style={s.sheetTitle}>{label || placeholder || "Select"}</Text>
            {showSearch && (
              <View style={s.searchRow}>
                <Ionicons name="search" size={16} color={colors.textMuted} />
                <TextInput
                  style={s.search}
                  placeholder="Search"
                  placeholderTextColor={colors.textMuted}
                  value={q}
                  onChangeText={setQ}
                  autoCorrect={false}
                  autoCapitalize="none"
                />
              </View>
            )}
            <FlatList
              data={filtered}
              keyExtractor={(o, i) => `${o.id}-${i}`}
              style={{ maxHeight: 400 }}
              keyboardShouldPersistTaps="handled"
              renderItem={({ item }) => {
                const on = String(item.id) === String(value);
                return (
                  <TouchableOpacity style={s.opt} onPress={() => { onChange(item.id, item); setOpen(false); setQ(""); }}>
                    <Text style={[s.optTxt, on && { color: colors.primary, fontWeight: "800" }]} numberOfLines={1}>
                      {item.text || "—"}
                    </Text>
                    {on && <Ionicons name="checkmark" size={18} color={colors.primary} />}
                  </TouchableOpacity>
                );
              }}
              ListEmptyComponent={<Text style={s.sheetEmpty}>No options</Text>}
            />
          </TouchableOpacity>
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

// ── Date pill that opens a month calendar sheet ──────────────────────────────
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const pad2 = (n: number) => (n < 10 ? `0${n}` : `${n}`);
export const toISODate = (d: Date) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T00:00:00`;
const fmt = (d: Date) => `${pad2(d.getDate())}.${pad2(d.getMonth() + 1)}.${d.getFullYear()}`;

export function DateField({ label, value, onChange, testID }: { label?: string; value: Date; onChange: (d: Date) => void; testID?: string }) {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const s = useMemo(() => fStyles(colors), [colors]);
  const [open, setOpen] = useState(false);
  const [view, setView] = useState(new Date(value.getFullYear(), value.getMonth(), 1));

  const stepMonth = (delta: number) => setView((v) => new Date(v.getFullYear(), v.getMonth() + delta, 1));
  const first = new Date(view.getFullYear(), view.getMonth(), 1);
  const daysInMonth = new Date(view.getFullYear(), view.getMonth() + 1, 0).getDate();
  const lead = first.getDay();
  const cells: (number | null)[] = [...Array(lead).fill(null), ...Array.from({ length: daysInMonth }, (_, i) => i + 1)];

  return (
    <View style={{ flex: 1 }}>
      <TouchableOpacity style={s.field} onPress={() => { setView(new Date(value.getFullYear(), value.getMonth(), 1)); setOpen(true); }} activeOpacity={0.7} testID={testID}>
        <Text style={s.value} numberOfLines={1}>{label ? `${label} ` : ""}{fmt(value)}</Text>
        <Ionicons name="calendar-outline" size={16} color={colors.textMuted} />
      </TouchableOpacity>

      <Modal visible={open} transparent animationType="slide" onRequestClose={() => setOpen(false)}>
        <TouchableOpacity style={s.backdrop} activeOpacity={1} onPress={() => setOpen(false)}>
          <TouchableOpacity activeOpacity={1} style={[s.sheet, { paddingBottom: 16 + insets.bottom }]}>
            <View style={s.handle} />
            <View style={s.calHead}>
              <TouchableOpacity onPress={() => stepMonth(-1)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}><Ionicons name="chevron-back" size={22} color={colors.primary} /></TouchableOpacity>
              <Text style={s.calTitle}>{MONTHS[view.getMonth()]} {view.getFullYear()}</Text>
              <TouchableOpacity onPress={() => stepMonth(1)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}><Ionicons name="chevron-forward" size={22} color={colors.primary} /></TouchableOpacity>
            </View>
            <View style={s.calRow}>
              {["S", "M", "T", "W", "T", "F", "S"].map((d, i) => <Text key={i} style={s.calDow}>{d}</Text>)}
            </View>
            <View style={s.calGrid}>
              {cells.map((day, i) => {
                if (day == null) return <View key={`e${i}`} style={s.calCell} />;
                const on = value.getFullYear() === view.getFullYear() && value.getMonth() === view.getMonth() && value.getDate() === day;
                return (
                  <TouchableOpacity key={i} style={s.calCell} onPress={() => { onChange(new Date(view.getFullYear(), view.getMonth(), day)); setOpen(false); }}>
                    <View style={[s.calDay, on && { backgroundColor: colors.primary }]}>
                      <Text style={[s.calDayTxt, on && { color: "#fff", fontWeight: "800" }]}>{day}</Text>
                    </View>
                  </TouchableOpacity>
                );
              })}
            </View>
          </TouchableOpacity>
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

// ── Report scaffold: header + sticky filter card (+ optional Search) + list ──
export function ReportScaffold<T>({
  title, subtitle, filters, onSearch, loading, error, data, renderItem, keyExtractor, emptyText, headerRight,
}: {
  title: string;
  subtitle?: string;
  filters?: React.ReactNode;
  onSearch?: () => void;
  loading?: boolean;
  error?: string | null;
  data: T[] | null | undefined;
  renderItem: (item: T, index: number) => React.ReactElement;
  keyExtractor?: (item: T, index: number) => string;
  emptyText?: string;
  headerRight?: React.ReactNode;
}) {
  const { colors, shadow, mode } = useTheme();
  const s = useMemo(() => sStyles(colors, shadow, mode), [colors, shadow, mode]);
  const rows = data ?? [];

  return (
    <View style={s.root}>
      <ScreenHeader title={title} subtitle={subtitle} />
      {(filters || onSearch) && (
        <View style={s.filterCard}>
          {filters}
          {onSearch && (
            <TouchableOpacity style={s.searchBtn} onPress={onSearch} activeOpacity={0.9} disabled={loading} testID="rk-search">
              {loading ? <ActivityIndicator color="#fff" /> : <Text style={s.searchTxt}>Search</Text>}
            </TouchableOpacity>
          )}
        </View>
      )}
      {error ? (
        <View style={s.center}><Ionicons name="alert-circle-outline" size={40} color={colors.danger} /><Text style={s.errTxt}>{error}</Text></View>
      ) : loading && !onSearch ? (
        <SkeletonList rows={7} />
      ) : rows.length === 0 ? (
        <View style={s.center}>
          <Ionicons name="file-tray-outline" size={44} color={colors.textMuted} />
          <Text style={s.emptyTxt}>{emptyText || "No data available"}</Text>
        </View>
      ) : (
        <FlatList
          data={rows}
          keyExtractor={keyExtractor || ((_, i) => String(i))}
          renderItem={({ item, index }) => renderItem(item, index)}
          contentContainerStyle={{ padding: spacing.xl, paddingBottom: 140 }}
          showsVerticalScrollIndicator={false}
          ItemSeparatorComponent={() => <View style={{ height: 10 }} />}
          initialNumToRender={12}
          removeClippedSubviews
        />
      )}
    </View>
  );
}

// Small labelled key/value row used inside report cards.
export function KV({ label, value, strong }: { label: string; value: any; strong?: boolean }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 4, gap: 12 }}>
      <Text style={{ fontSize: 12, color: colors.textSecondary, fontWeight: "600" }}>{label}</Text>
      <Text style={{ fontSize: 13, color: strong ? colors.primary : colors.textPrimary, fontWeight: strong ? "800" : "700", flexShrink: 1, textAlign: "right" }} numberOfLines={2}>
        {value == null || value === "" ? "—" : String(value)}
      </Text>
    </View>
  );
}

function hStyles(colors: any) {
  return StyleSheet.create({
    row: { flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: spacing.lg, paddingVertical: 8 },
    back: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    subtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 1 },
  });
}

function fStyles(colors: any) {
  return StyleSheet.create({
    label: { ...font.tiny, color: colors.textSecondary, marginBottom: 6, textTransform: "uppercase" },
    field: {
      flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8,
      backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border,
      borderRadius: radius.full, paddingHorizontal: 16, minHeight: 46,
    },
    value: { flex: 1, fontSize: 14, fontWeight: "600", color: colors.textPrimary },
    placeholder: { color: colors.textMuted, fontWeight: "500" },

    backdrop: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" },
    sheet: { backgroundColor: colors.surface, borderTopLeftRadius: radius.xxl, borderTopRightRadius: radius.xxl, paddingHorizontal: spacing.xl, paddingTop: 12, paddingBottom: 32 },
    handle: { alignSelf: "center", width: 44, height: 5, borderRadius: 3, backgroundColor: colors.border, marginBottom: 14 },
    sheetTitle: { fontSize: 17, fontWeight: "800", color: colors.textPrimary, marginBottom: 10 },
    sheetEmpty: { color: colors.textSecondary, textAlign: "center", paddingVertical: 20 },
    searchRow: { flexDirection: "row", alignItems: "center", gap: 8, backgroundColor: colors.surfaceAlt, borderRadius: radius.md, paddingHorizontal: 12, marginBottom: 10 },
    search: { flex: 1, paddingVertical: 10, color: colors.textPrimary, fontSize: 14 },
    opt: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: colors.border },
    optTxt: { flex: 1, fontSize: 15, color: colors.textPrimary, fontWeight: "600" },

    calHead: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: 6, marginBottom: 6 },
    calTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    calRow: { flexDirection: "row" },
    calDow: { flex: 1, textAlign: "center", fontSize: 11, fontWeight: "700", color: colors.textMuted, paddingVertical: 4 },
    calGrid: { flexDirection: "row", flexWrap: "wrap" },
    calCell: { width: `${100 / 7}%`, alignItems: "center", justifyContent: "center", paddingVertical: 3 },
    calDay: { width: 38, height: 38, borderRadius: 19, alignItems: "center", justifyContent: "center" },
    calDayTxt: { fontSize: 14, color: colors.textPrimary, fontWeight: "600" },
  });
}

function sStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    filterCard: {
      backgroundColor: colors.surfaceAlt, marginHorizontal: spacing.xl, marginTop: 4, marginBottom: 6,
      borderRadius: radius.xl, padding: 14, gap: 10,
    },
    searchBtn: { backgroundColor: colors.primary, borderRadius: radius.full, paddingVertical: 13, alignItems: "center", justifyContent: "center", minHeight: 46 },
    searchTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
    center: { flex: 1, alignItems: "center", justifyContent: "center", padding: 40, gap: 10 },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center" },
    errTxt: { color: colors.danger, fontSize: 14, textAlign: "center" },
  });
}
