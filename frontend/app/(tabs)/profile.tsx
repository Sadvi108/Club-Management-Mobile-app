import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, Image, TouchableOpacity, Alert, Switch } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme, LOGO_URL } from "../../src/theme";
import { student, certificates } from "../../src/mockData";

const settingsItems = [
  { id: "notif", icon: "notifications-outline", label: "Notifications", badge: "3" },
  { id: "lang", icon: "language-outline", label: "Language", meta: "English" },
  { id: "priv", icon: "lock-closed-outline", label: "Privacy & Security" },
  { id: "help", icon: "help-circle-outline", label: "Help & Support" },
  { id: "refer", icon: "gift-outline", label: "Refer a Friend", meta: "Earn RM 50" },
  { id: "about", icon: "information-circle-outline", label: "About D-Clix" },
];

export default function Profile() {
  const router = useRouter();
  const { colors, shadow, mode, toggle } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const onLogout = () => {
    Alert.alert("Logout", "Are you sure you want to logout?", [
      { text: "Cancel", style: "cancel" },
      { text: "Logout", style: "destructive", onPress: () => router.replace("/login") },
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
                <Image source={{ uri: student.photo }} style={styles.avatar} />
                <TouchableOpacity style={styles.avatarEdit}>
                  <Ionicons name="camera" size={12} color={colors.primary} />
                </TouchableOpacity>
              </View>
              <Text style={styles.name}>{student.name}</Text>
              <Text style={styles.id}>{student.id}</Text>
              <View style={styles.memberRow}>
                <Ionicons name="shield-checkmark" size={14} color="#FFF7ED" />
                <Text style={styles.memberTxt}>{student.membership} · Since {student.joinDate}</Text>
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
            <Text style={styles.vidName}>{student.name}</Text>
            <Text style={styles.vidLbl}>{student.level} · {student.belt}</Text>
            <View style={styles.barcodeRow}>
              {Array.from({ length: 20 }).map((_, i) => (
                <View key={i} style={[styles.bar, { height: 20 + ((i * 7) % 12), opacity: i % 3 === 0 ? 1 : 0.6 }]} />
              ))}
            </View>
            <Text style={styles.vidId}>{student.id}</Text>
          </View>
          <View style={styles.vidQR}>
            <Ionicons name="qr-code" size={60} color={colors.primary} />
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
          <Text style={styles.cardTitle}>Contact Information</Text>
          <Row icon="call-outline" label="Phone" value={student.phone} colors={colors} />
          <Row icon="mail-outline" label="Email" value={student.email} colors={colors} />
          <Row icon="people-outline" label="Emergency Contact" value={`${student.parent.name} · ${student.parent.phone}`} colors={colors} />
        </View>

        <View style={styles.card}>
          <View style={styles.cardHeadRow}>
            <Text style={styles.cardTitle}>Certificates & Achievements</Text>
            <Text style={styles.badge}>{certificates.length}</Text>
          </View>
          {certificates.map((c) => (
            <View key={c.id} style={styles.certRow} testID={`cert-${c.id}`}>
              <View style={styles.certIcon}><Ionicons name="ribbon" size={18} color={colors.warning} /></View>
              <View style={{ flex: 1 }}>
                <Text style={styles.certTitle}>{c.title}</Text>
                <Text style={styles.certMeta}>{c.issuer} · {c.date}</Text>
              </View>
              <TouchableOpacity><Ionicons name="download-outline" size={18} color={colors.primary} /></TouchableOpacity>
            </View>
          ))}
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Settings</Text>
          {settingsItems.map((s) => (
            <TouchableOpacity key={s.id} style={styles.settingRow} testID={`setting-${s.id}`}>
              <View style={styles.settingIcon}><Ionicons name={s.icon as any} size={18} color={colors.primary} /></View>
              <Text style={styles.settingLbl}>{s.label}</Text>
              {s.badge ? (<View style={styles.settingBadge}><Text style={styles.settingBadgeTxt}>{s.badge}</Text></View>)
                : s.meta ? (<Text style={styles.settingMeta}>{s.meta}</Text>) : null}
              <Ionicons name="chevron-forward" size={16} color={colors.textMuted} />
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.renewBtn} testID="renew-membership">
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.renewInner, shadow.strong]}>
            <Ionicons name="sparkles" size={18} color="#fff" />
            <Text style={styles.renewTxt}>Renew Membership — 20% OFF</Text>
          </LinearGradient>
        </TouchableOpacity>

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
    avatar: { width: 90, height: 90, borderRadius: 45 },
    avatarEdit: { position: "absolute", right: 2, bottom: 2, width: 26, height: 26, borderRadius: 13, backgroundColor: "#fff", alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: colors.primary },
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
    vidQR: { width: 90, height: 90, backgroundColor: colors.surfaceAlt, borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginLeft: 14 },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 18, marginHorizontal: spacing.xl, marginTop: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardHeadRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
    cardTitle: { ...font.h4, color: colors.textPrimary, marginBottom: 12 },
    badge: { backgroundColor: colors.surfaceAlt, color: colors.primary, fontSize: 11, fontWeight: "800", paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10, overflow: "hidden" },

    themeRow: { flexDirection: "row", gap: 12, alignItems: "center" },
    themeIcon: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    themeTitle: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
    themeSub: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },

    certRow: { flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 10 },
    certIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: mode === "dark" ? "#2D1A0A" : "#FEF3C7", alignItems: "center", justifyContent: "center" },
    certTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    certMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },

    settingRow: { flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 12 },
    settingIcon: { width: 34, height: 34, borderRadius: 17, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    settingLbl: { flex: 1, fontSize: 14, color: colors.textPrimary, fontWeight: "600" },
    settingBadge: { backgroundColor: colors.danger, paddingHorizontal: 7, paddingVertical: 2, borderRadius: 10, marginRight: 6 },
    settingBadgeTxt: { color: "#fff", fontSize: 10, fontWeight: "800" },
    settingMeta: { color: colors.textSecondary, fontSize: 11, fontWeight: "600", marginRight: 4 },

    renewBtn: { marginHorizontal: spacing.xl, marginTop: 18 },
    renewInner: { flexDirection: "row", gap: 8, paddingVertical: 16, borderRadius: radius.md, alignItems: "center", justifyContent: "center" },
    renewTxt: { color: "#fff", fontWeight: "800", fontSize: 14 },

    logout: { flexDirection: "row", gap: 8, alignSelf: "center", paddingVertical: 14, paddingHorizontal: 24, marginTop: 16, borderRadius: radius.md, alignItems: "center" },
    logoutTxt: { color: colors.danger, fontWeight: "700", fontSize: 14 },
    version: { textAlign: "center", color: colors.textMuted, fontSize: 11, marginTop: 8 },
  });
}
