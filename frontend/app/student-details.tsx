import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

function fmtDate(iso?: string) {
  if (!iso) return "—";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function StudentDetails() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user, token } = useAuth();
  // Guarded on token — an unauthenticated cold open 401s into a silent logout.
  const info = useApi(() => (token ? api.myInfo() : Promise.resolve(null as any)), [token]);
  const addtnl = useApi(() => (token ? api.studentAddtnlInfo() : Promise.resolve(null as any)), [token]);
  const loading = info.loading || addtnl.loading;

  const fields: { icon: string; label: string; value: string }[] = [
    { icon: "person-outline", label: "Name", value: user?.name?.trim() || "—" },
    { icon: "card-outline", label: "Registration No", value: info.data?.registrationNo || user?.code || "—" },
    { icon: "finger-print-outline", label: "IC No", value: user?.icNo || "—" },
    { icon: "ribbon-outline", label: "Current Grade", value: info.data?.currentGrade || user?.currentGrade || "—" },
    { icon: "location-outline", label: "Training Center", value: info.data?.tCenterName || "—" },
    { icon: "business-outline", label: "Exam Center", value: info.data?.eCenterName || "—" },
    { icon: "person-circle-outline", label: "Instructor", value: info.data?.instructorName || "—" },
    { icon: "call-outline", label: "Phone", value: user?.handPhone || (addtnl.data as any)?.mobileNo || "—" },
    { icon: "school-outline", label: "School", value: addtnl.data?.schoolname || "—" },
    { icon: "calendar-outline", label: "Date of Birth", value: fmtDate(addtnl.data?.dob) },
    { icon: "water-outline", label: "Blood Type", value: addtnl.data?.bloodtype || "—" },
    { icon: "fitness-outline", label: "Health Status", value: addtnl.data?.healthstatus || "—" },
  ];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="sd-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Student Details</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>
      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
        {loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 30 }} />}
        {!loading && (
          <View style={styles.card}>
            {fields.map((f, i) => (
              <View key={f.label}>
                <View style={styles.row}>
                  <View style={styles.iconWrap}><Ionicons name={f.icon as any} size={18} color={colors.primary} /></View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.lbl} numberOfLines={1}>{f.label}</Text>
                    <Text style={styles.val} numberOfLines={2}>{f.value}</Text>
                  </View>
                </View>
                {i < fields.length - 1 && <View style={styles.divider} />}
              </View>
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 16, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    row: { flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 11 },
    iconWrap: { width: 38, height: 38, borderRadius: 19, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    lbl: { fontSize: 12, color: colors.textSecondary, fontWeight: "600" },
    val: { fontSize: 15, color: colors.textPrimary, fontWeight: "700", marginTop: 2 },
    divider: { height: 1, backgroundColor: colors.border },
  });
}
