import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, Image, TouchableOpacity, Alert, Switch } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme, LOGO_URL } from "../../src/theme";
import { useAuth } from "../../src/api/auth";
import { api } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";

const settingsItems = [
  { id: "notif", icon: "notifications-outline", label: "Notifications" },
  { id: "lang", icon: "language-outline", label: "Language", meta: "English" },
  { id: "priv", icon: "lock-closed-outline", label: "Privacy & Security" },
  { id: "help", icon: "help-circle-outline", label: "Help & Support" },
  { id: "about", icon: "information-circle-outline", label: "About D-Clix" },
];

function fmtDate(iso?: string) {
  if (!iso) return "—";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}
function initialsOf(name?: string) {
  return (name || "?").trim().split(/\s+/).map((w) => w[0]).slice(0, 2).join("").toUpperCase();
}

export default function Profile() {
  const router = useRouter();
  const { colors, shadow, mode, toggle } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user, logout } = useAuth();

  const info = useApi(() => api.myInfo(), []);
  const addtnl = useApi(() => api.studentAddtnlInfo(), []);
  const unread = useApi(() => api.unreadNotificationCount(), []);

  const [qrError, setQrError] = useState(false);
  const qrUrl =
    user && user.clubId && user.branchId && user.id
      ? api.studentQRCodeUrl(user.clubId, user.branchId, user.id)
      : null;

  const grade = (info.data?.currentGrade || user?.currentGrade || "—").replace(/Grade\s*/i, "");

  const onLogout = () => {
    Alert.alert("Logout", "Are you sure you want to logout?", [
      { text: "Cancel", style: "cancel" },
      { text: "Logout", style: "destructive", onPress: () => { logout(); router.replace("/login"); } },
    ]);
  };

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={{ paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.headerBg}>
            <View style={styles.topRow}>
              <Text style={styles.topTitle}>My Profile</Text>
              <TouchableOpacity style={styles.topIcon} testID="profile-settings">
                <Ionicons name="settings-outline" size={20} color="#fff" />
              </TouchableOpacity>
            </View>
            <View style={styles.profileTop}>
              <View style={styles.avatarRing}>
                {user?.clubPic ? (
                  <Image source={{ uri: user.clubPic }} style={styles.avatar} />
                ) : (
                  <View style={[styles.avatar, styles.avatarInitials]}>
                    <Text style={styles.avatarInitialsTxt}>{initialsOf(user?.name)}</Text>
                  </View>
                )}
              </View>
              <Text style={styles.name}>{user?.name?.trim() || "Member"}</Text>
              <Text style={styles.id}>{user?.code || user?.icNo}</Text>
              <View style={styles.memberRow}>
                <Ionicons name="shield-checkmark" size={14} color="#FFF7ED" />
                <Text style={styles.memberTxt}>{user?.clubName || "Academy"} · {user?.status || "Active"}</Text>
              </View>
            </View>
          </LinearGradient>
        </SafeAreaView>

        {/* Virtual ID */}
        <View style={styles.virtualId}>
          <View style={styles.vidLeft}>
            <View style={styles.vidBrandRow}>
              <Image source={{ uri: LOGO_URL }} style={styles.vidLogo} />
              <Text style={styles.vidBrand}>D-CLIX</Text>
            </View>
            <Text style={styles.vidName}>{user?.name?.trim()}</Text>
            <Text style={styles.vidLbl}>Grade {grade}</Text>
            <View style={styles.barcodeRow}>
              {Array.from({ length: 20 }).map((_, i) => (
                <View key={i} style={[styles.bar, { height: 20 + ((i * 7) % 12), opacity: i % 3 === 0 ? 1 : 0.6 }]} />
              ))}
            </View>
            <Text style={styles.vidId}>{user?.code || user?.icNo}</Text>
          </View>
          <View style={styles.vidQR}>
            {qrUrl && !qrError ? (
              <Image source={{ uri: qrUrl }} style={styles.qrImg} resizeMode="contain" onError={() => setQrError(true)} />
            ) : (
              <Ionicons name="qr-code" size={60} color={colors.primary} />
            )}
          </View>
        </View>

        {/* Theme toggle card */}
        <View style={styles.card}>
          <View style={styles.themeRow}>
            <View style={styles.themeIcon}>
              <Ionicons name={mode === "dark" ? "moon" : "sunny"} size={20} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.themeTitle}>{mode === "dark" ? "Dark Mode" : "Light Mode"}</Text>
              <Text style={styles.themeSub}>{mode === "dark" ? "Orange & black" : "Orange & white"}</Text>
            </View>
            <Switch
              testID="profile-dark-mode-toggle"
              value={mode === "dark"}
              onValueChange={toggle}
              trackColor={{ false: colors.border, true: colors.primary }}
              thumbColor="#fff"
              ios_backgroundColor={colors.border}
            />
          </View>
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Contact & Academy</Text>
          <Row icon="call-outline" label="Phone" value={user?.handPhone || "—"} colors={colors} />
          <Row icon="mail-outline" label="Email" value={user?.emailAddress || "—"} colors={colors} />
          <Row icon="document-text-outline" label="Registration No" value={info.data?.registrationNo || user?.code || "—"} colors={colors} />
          <Row icon="location-outline" label="Training Center" value={info.data?.tCenterName || "—"} colors={colors} />
          <Row icon="person-outline" label="Instructor" value={info.data?.instructorName || "—"} colors={colors} />
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Student Information</Text>
          <Row icon="school-outline" label="School" value={addtnl.data?.schoolname || "—"} colors={colors} />
          <Row icon="calendar-outline" label="Date of Birth" value={fmtDate(addtnl.data?.dob)} colors={colors} />
          <Row icon="water-outline" label="Blood Type" value={addtnl.data?.bloodtype || "—"} colors={colors} />
          <Row icon="fitness-outline" label="Health Status" value={addtnl.data?.healthstatus || "—"} colors={colors} />
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Settings</Text>
          {settingsItems.map((s) => {
            const badge = s.id === "notif" && (unread.data ?? 0) > 0 ? String(unread.data) : undefined;
            return (
              <TouchableOpacity key={s.id} style={styles.settingRow} testID={`setting-${s.id}`}>
                <View style={styles.settingIcon}><Ionicons name={s.icon as any} size={18} color={colors.primary} /></View>
                <Text style={styles.settingLbl}>{s.label}</Text>
                {badge ? (<View style={styles.settingBadge}><Text style={styles.settingBadgeTxt}>{badge}</Text></View>)
                  : s.meta ? (<Text style={styles.settingMeta}>{s.meta}</Text>) : null}
                <Ionicons name="chevron-forward" size={16} color={colors.textMuted} />
              </TouchableOpacity>
            );
          })}
        </View>

        <TouchableOpacity style={styles.logout} onPress={onLogout} testID="logout-btn">
          <Ionicons name="log-out-outline" size={18} color={colors.danger} />
          <Text style={styles.logoutTxt}>Logout</Text>
        </TouchableOpacity>

        <Text style={styles.version}>D-Clix · v1.0.0</Text>
      </ScrollView>
    </View>
  );
}

function Row({ icon, label, value, colors }: { icon: string; label: string; value: string; colors: any }) {
  return (
    <View style={{ flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 8 }}>
      <View style={{ width: 34, height: 34, borderRadius: 17, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" }}>
        <Ionicons name={icon as any} size={16} color={colors.primary} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 10, color: colors.textSecondary, fontWeight: "700", letterSpacing: 0.5 }}>{label.toUpperCase()}</Text>
        <Text style={{ fontSize: 13, color: colors.textPrimary, fontWeight: "600", marginTop: 1 }}>{value}</Text>
      </View>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    headerBg: { paddingHorizontal: spacing.xl, paddingBottom: 50, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 },
    topRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 6 },
    topTitle: { color: "#fff", fontSize: 18, fontWeight: "800" },
    topIcon: { width: 38, height: 38, borderRadius: 19, backgroundColor: "rgba(255,255,255,0.22)", alignItems: "center", justifyContent: "center" },
    profileTop: { alignItems: "center", marginTop: 16 },
    avatarRing: { padding: 4, borderRadius: 60, borderWidth: 2, borderColor: "rgba(255,255,255,0.6)" },
    avatar: { width: 90, height: 90, borderRadius: 45, backgroundColor: "#fff" },
    avatarInitials: { alignItems: "center", justifyContent: "center", backgroundColor: "rgba(255,255,255,0.25)" },
    avatarInitialsTxt: { color: "#fff", fontWeight: "800", fontSize: 30 },
    name: { color: "#fff", fontSize: 22, fontWeight: "800", marginTop: 12 },
    id: { color: "rgba(255,255,255,0.85)", fontSize: 12, marginTop: 2 },
    memberRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 8, backgroundColor: "rgba(255,255,255,0.22)", paddingHorizontal: 12, paddingVertical: 5, borderRadius: 14 },
    memberTxt: { color: "#FFF7ED", fontSize: 11, fontWeight: "700" },

    virtualId: { flexDirection: "row", backgroundColor: colors.surface, marginHorizontal: spacing.xl, marginTop: -36, borderRadius: radius.xl, padding: 18, ...shadow.card, overflow: "hidden", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    vidLeft: { flex: 1 },
    vidBrandRow: { flexDirection: "row", gap: 8, alignItems: "center" },
    vidLogo: { width: 22, height: 22, borderRadius: 6 },
    vidBrand: { color: colors.primary, fontSize: 11, fontWeight: "900", letterSpacing: 2 },
    vidName: { color: colors.textPrimary, fontSize: 15, fontWeight: "800", marginTop: 8 },
    vidLbl: { color: colors.textSecondary, fontSize: 11, marginTop: 2 },
    barcodeRow: { flexDirection: "row", gap: 2, marginTop: 10, alignItems: "flex-end" },
    bar: { width: 2, backgroundColor: colors.textPrimary },
    vidId: { color: colors.textPrimary, fontSize: 10, fontWeight: "700", letterSpacing: 1, marginTop: 4 },
    vidQR: { width: 90, height: 90, backgroundColor: "#fff", borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginLeft: 14, overflow: "hidden" },
    qrImg: { width: 86, height: 86 },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 18, marginHorizontal: spacing.xl, marginTop: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardHeadRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
    cardTitle: { ...font.h4, color: colors.textPrimary, marginBottom: 12 },
    badge: { backgroundColor: colors.surfaceAlt, color: colors.primary, fontSize: 11, fontWeight: "800", paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10, overflow: "hidden" },

    themeRow: { flexDirection: "row", gap: 12, alignItems: "center" },
    themeIcon: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    themeTitle: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
    themeSub: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },

    settingRow: { flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 12 },
    settingIcon: { width: 34, height: 34, borderRadius: 17, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    settingLbl: { flex: 1, fontSize: 14, color: colors.textPrimary, fontWeight: "600" },
    settingBadge: { backgroundColor: colors.danger, paddingHorizontal: 7, paddingVertical: 2, borderRadius: 10, marginRight: 6 },
    settingBadgeTxt: { color: "#fff", fontSize: 10, fontWeight: "800" },
    settingMeta: { color: colors.textSecondary, fontSize: 11, fontWeight: "600", marginRight: 4 },

    logout: { flexDirection: "row", gap: 8, alignSelf: "center", paddingVertical: 14, paddingHorizontal: 24, marginTop: 16, borderRadius: radius.md, alignItems: "center" },
    logoutTxt: { color: colors.danger, fontWeight: "700", fontSize: 14 },
    version: { textAlign: "center", color: colors.textMuted, fontSize: 11, marginTop: 8 },
  });
}
