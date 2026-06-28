import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, Image, TouchableOpacity, Switch, Modal } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme, LOGO_URL } from "../../src/theme";
import { confirmDialog } from "../../src/ui/dialogs";
import { useAuth } from "../../src/api/auth";
import { api } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";

export default function Profile() {
  const router = useRouter();
  const { colors, shadow, mode, toggle } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user, logout } = useAuth();

  const info = useApi(() => api.myInfo(), []);
  const siblings = useApi(() => api.mySiblings(), []);

  const [studentModal, setStudentModal] = useState(false);
  const [clubModal, setClubModal] = useState(false);

  const qrUrl = user?.id ? api.qrCodeUrl(user.id) : null;
  const grade = info.data?.currentGrade || user?.currentGrade || "—";
  const clubName = user?.clubName || user?.clubList?.[0]?.text || "—";

  const onLogout = async () => {
    const ok = await confirmDialog("Logout", "Are you sure you want to logout?", {
      confirmLabel: "Logout",
      destructive: true,
    });
    if (ok) {
      logout();
      router.replace("/login");
    }
  };

  const ROWS = [
    { id: "scan", icon: "qr-code-outline", label: "Scan QR to Check In", onPress: () => router.push("/qr-scan") },
    { id: "help", icon: "headset-outline", label: "Help Desk", onPress: () => router.push("/helpdesk") },
    { id: "details", icon: "id-card-outline", label: "Student Details", onPress: () => router.push("/student-details") },
    { id: "purchases", icon: "bag-handle-outline", label: "My Purchases", onPress: () => router.push("/purchases") },
  ];

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={{ paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.headerBg}>
            <View style={styles.topRow}>
              <Text style={styles.topTitle}>My Profile</Text>
              <TouchableOpacity style={styles.topIcon} testID="profile-edit" hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={() => router.push("/edit-profile")}>
                <Ionicons name="pencil" size={18} color="#fff" />
              </TouchableOpacity>
            </View>
            <View style={styles.profileTop}>
              <View style={styles.avatarRing}>
                {user?.profilePic ? (
                  <Image source={{ uri: user.profilePic }} style={styles.avatar} />
                ) : (
                  <View style={[styles.avatar, styles.avatarEmpty]}>
                    <Ionicons name="person" size={44} color="rgba(255,255,255,0.5)" />
                  </View>
                )}
              </View>
              <Text style={styles.name} numberOfLines={1}>{user?.name?.trim() || "Member"}</Text>
              <Text style={styles.id} numberOfLines={1}>{user?.code || user?.icNo}</Text>
              <View style={styles.memberRow}>
                <Ionicons name="shield-checkmark" size={14} color="#FFF7ED" />
                <Text style={styles.memberTxt} numberOfLines={1}>{clubName}</Text>
              </View>
            </View>
          </LinearGradient>
        </SafeAreaView>

        {/* Virtual ID with QR */}
        <View style={styles.virtualId}>
          <View style={styles.vidLeft}>
            <View style={styles.vidBrandRow}>
              <Image source={{ uri: LOGO_URL }} style={styles.vidLogo} />
              <Text style={styles.vidBrand}>D-CLIX</Text>
            </View>
            <Text style={styles.vidName} numberOfLines={1}>{user?.name?.trim()}</Text>
            <Text style={styles.vidLbl} numberOfLines={1}>· {grade}</Text>
            <Text style={styles.vidId} numberOfLines={1}>{user?.code || user?.icNo}</Text>
          </View>
          <View style={styles.vidQR}>
            {qrUrl ? (
              <Image source={{ uri: qrUrl }} style={styles.qrImg} resizeMode="contain" />
            ) : (
              <Ionicons name="qr-code" size={60} color={colors.primary} />
            )}
          </View>
        </View>

        {/* Active Student + Club */}
        <View style={styles.dualRow}>
          <TouchableOpacity style={styles.dualCard} testID="profile-active-student" onPress={() => setStudentModal(true)} activeOpacity={0.85}>
            <View style={styles.dualTop}>
              <View style={styles.dualIcon}><Ionicons name="swap-horizontal" size={18} color={colors.primary} /></View>
              <Ionicons name="chevron-expand" size={16} color={colors.textMuted} />
            </View>
            <Text style={styles.dualLbl}>ACTIVE STUDENT</Text>
            <Text style={styles.dualVal} numberOfLines={1}>{user?.name?.trim()}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.dualCard} testID="profile-club" onPress={() => setClubModal(true)} activeOpacity={0.85}>
            <View style={styles.dualTop}>
              <View style={styles.dualIcon}><Ionicons name="business" size={18} color={colors.primary} /></View>
              <Ionicons name="chevron-expand" size={16} color={colors.textMuted} />
            </View>
            <Text style={styles.dualLbl}>CLUB</Text>
            <Text style={styles.dualVal} numberOfLines={1}>{clubName}</Text>
          </TouchableOpacity>
        </View>

        {/* Personal Info */}
        <View style={styles.card}>
          <View style={styles.cardHeadRow}>
            <View style={styles.cardHeadLeft}>
              <View style={styles.cardHeadIcon}><Ionicons name="id-card" size={18} color={colors.primary} /></View>
              <Text style={styles.cardTitle}>Personal Info</Text>
            </View>
            <Text style={styles.badge}>2 fields</Text>
          </View>
          <Row icon="call-outline" label="Phone" value={user?.handPhone || "—"} colors={colors} />
          <View style={styles.divider} />
          <Row icon="ribbon-outline" label="Belt / Grade" value={grade} colors={colors} />
        </View>

        {/* Light Mode */}
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

        {/* Action rows */}
        {ROWS.map((r) => (
          <TouchableOpacity key={r.id} style={styles.actionRow} testID={`profile-row-${r.id}`} onPress={r.onPress} activeOpacity={0.85}>
            <View style={styles.actionIcon}><Ionicons name={r.icon as any} size={20} color={colors.primary} /></View>
            <Text style={styles.actionLbl}>{r.label}</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
          </TouchableOpacity>
        ))}

        <TouchableOpacity style={styles.logout} onPress={onLogout} testID="logout-btn">
          <Ionicons name="log-out-outline" size={18} color={colors.danger} />
          <Text style={styles.logoutTxt}>Logout</Text>
        </TouchableOpacity>
        <Text style={styles.version}>D-Clix · v1.0.0</Text>
      </ScrollView>

      {/* Active Student picker */}
      <PickerModal
        visible={studentModal}
        title="Switch Student"
        onClose={() => setStudentModal(false)}
        items={(siblings.data ?? []).map((s) => ({ id: s.id, label: s.text, active: s.id === user?.id }))}
        styles={styles}
        colors={colors}
      />
      {/* Club picker */}
      <PickerModal
        visible={clubModal}
        title="Switch Club"
        onClose={() => setClubModal(false)}
        items={(user?.clubList ?? []).map((c) => ({ id: c.id, label: c.text, active: c.id === user?.clubId }))}
        styles={styles}
        colors={colors}
      />
    </View>
  );
}

function PickerModal({ visible, title, onClose, items, styles, colors }: any) {
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <TouchableOpacity style={styles.modalBackdrop} activeOpacity={1} onPress={onClose}>
        <View style={styles.modalSheet}>
          <View style={styles.modalHandle} />
          <Text style={styles.modalTitle}>{title}</Text>
          {items.length === 0 && <Text style={styles.modalEmpty}>Nothing to switch to.</Text>}
          {items.map((it: any) => (
            <View key={it.id} style={styles.pickRow}>
              <Ionicons name={it.active ? "radio-button-on" : "radio-button-off"} size={20} color={it.active ? colors.primary : colors.textMuted} />
              <Text style={styles.pickLbl} numberOfLines={1}>{it.label}</Text>
              {it.active && <Text style={styles.pickActive}>Active</Text>}
            </View>
          ))}
        </View>
      </TouchableOpacity>
    </Modal>
  );
}

function Row({ icon, label, value, colors }: { icon: string; label: string; value: string; colors: any }) {
  return (
    <View style={{ flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 10 }}>
      <View style={{ width: 38, height: 38, borderRadius: 19, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" }}>
        <Ionicons name={icon as any} size={18} color={colors.primary} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 12, color: colors.textSecondary, fontWeight: "600" }}>{label}</Text>
        <Text style={{ fontSize: 15, color: colors.textPrimary, fontWeight: "700", marginTop: 1 }} numberOfLines={1}>{value}</Text>
      </View>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    headerBg: { paddingHorizontal: spacing.xl, paddingBottom: 56, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 },
    topRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 6 },
    topTitle: { color: "#fff", fontSize: 22, fontWeight: "800" },
    topIcon: { width: 40, height: 40, borderRadius: 20, backgroundColor: "rgba(255,255,255,0.22)", alignItems: "center", justifyContent: "center" },
    profileTop: { alignItems: "center", marginTop: 14 },
    avatarRing: { padding: 5, borderRadius: 66, borderWidth: 2, borderColor: "rgba(255,255,255,0.55)" },
    avatar: { width: 104, height: 104, borderRadius: 52, backgroundColor: "rgba(255,255,255,0.18)" },
    avatarEmpty: { alignItems: "center", justifyContent: "center" },
    name: { color: "#fff", fontSize: 24, fontWeight: "800", marginTop: 14, textAlign: "center", paddingHorizontal: 10 },
    id: { color: "rgba(255,255,255,0.9)", fontSize: 13, marginTop: 4 },
    memberRow: { flexDirection: "row", gap: 6, alignItems: "center", marginTop: 10, backgroundColor: "rgba(255,255,255,0.22)", paddingHorizontal: 14, paddingVertical: 6, borderRadius: 16, maxWidth: "90%" },
    memberTxt: { color: "#FFF7ED", fontSize: 12, fontWeight: "700", flexShrink: 1 },

    virtualId: { flexDirection: "row", backgroundColor: colors.surface, marginHorizontal: spacing.xl, marginTop: -34, borderRadius: radius.xl, padding: 18, ...shadow.card, overflow: "hidden", borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border, alignItems: "center" },
    vidLeft: { flex: 1 },
    vidBrandRow: { flexDirection: "row", gap: 8, alignItems: "center" },
    vidLogo: { width: 24, height: 24, borderRadius: 7 },
    vidBrand: { color: colors.primary, fontSize: 13, fontWeight: "900", letterSpacing: 2 },
    vidName: { color: colors.textPrimary, fontSize: 16, fontWeight: "800", marginTop: 10 },
    vidLbl: { color: colors.textSecondary, fontSize: 13, marginTop: 4 },
    vidId: { color: colors.textPrimary, fontSize: 12, fontWeight: "700", letterSpacing: 0.5, marginTop: 10 },
    vidQR: { width: 96, height: 96, backgroundColor: "#fff", borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginLeft: 14, overflow: "hidden" },
    qrImg: { width: 92, height: 92 },

    dualRow: { flexDirection: "row", gap: 12, marginHorizontal: spacing.xl, marginTop: 14 },
    dualCard: { flex: 1, backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    dualTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
    dualIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    dualLbl: { fontSize: 11, color: colors.textSecondary, fontWeight: "700", letterSpacing: 0.5, marginTop: 12 },
    dualVal: { fontSize: 15, color: colors.textPrimary, fontWeight: "800", marginTop: 3 },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 16, marginHorizontal: spacing.xl, marginTop: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardHeadRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 6 },
    cardHeadLeft: { flexDirection: "row", alignItems: "center", gap: 10 },
    cardHeadIcon: { width: 38, height: 38, borderRadius: 19, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    cardTitle: { ...font.h4, color: colors.textPrimary },
    badge: { backgroundColor: colors.surfaceAlt, color: colors.primary, fontSize: 11, fontWeight: "800", paddingHorizontal: 10, paddingVertical: 5, borderRadius: 12, overflow: "hidden" },
    divider: { height: 1, backgroundColor: colors.border, marginVertical: 2 },

    themeRow: { flexDirection: "row", gap: 12, alignItems: "center" },
    themeIcon: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    themeTitle: { fontSize: 16, fontWeight: "700", color: colors.textPrimary },
    themeSub: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },

    actionRow: { flexDirection: "row", gap: 14, alignItems: "center", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 16, marginHorizontal: spacing.xl, marginTop: 12, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    actionIcon: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    actionLbl: { flex: 1, fontSize: 16, color: colors.textPrimary, fontWeight: "700" },

    logout: { flexDirection: "row", gap: 8, alignSelf: "center", paddingVertical: 14, paddingHorizontal: 24, marginTop: 20, borderRadius: radius.md, alignItems: "center" },
    logoutTxt: { color: colors.danger, fontWeight: "700", fontSize: 15 },
    version: { textAlign: "center", color: colors.textMuted, fontSize: 11, marginTop: 6 },

    modalBackdrop: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" },
    modalSheet: { backgroundColor: colors.surface, borderTopLeftRadius: radius.xxl, borderTopRightRadius: radius.xxl, paddingHorizontal: spacing.xl, paddingTop: 12, paddingBottom: 36 },
    modalHandle: { alignSelf: "center", width: 44, height: 5, borderRadius: 3, backgroundColor: colors.border, marginBottom: 14 },
    modalTitle: { fontSize: 18, fontWeight: "800", color: colors.textPrimary, marginBottom: 8 },
    modalEmpty: { color: colors.textSecondary, fontSize: 14, paddingVertical: 16, textAlign: "center" },
    pickRow: { flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: colors.border },
    pickLbl: { color: colors.textPrimary, fontSize: 15, fontWeight: "600", flex: 1 },
    pickActive: { color: colors.primary, fontSize: 12, fontWeight: "700" },
  });
}
