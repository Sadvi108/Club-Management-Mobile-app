import { useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Keyboard,
  Pressable,
  Image,
} from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { LOGO_URL, radius, spacing, useTheme } from "../src/theme";

export default function Login() {
  const router = useRouter();
  const { colors, shadow, mode, toggle } = useTheme();
  const [studentId, setStudentId] = useState("SA-2026-0142");
  const [password, setPassword] = useState("demo1234");
  const [showPwd, setShowPwd] = useState(false);
  const [loginMode, setLoginMode] = useState<"student" | "instructor">("student");
  const [focus, setFocus] = useState<"id" | "pwd" | null>(null);

  const styles = useMemo(() => createStyles(colors, shadow), [colors, shadow]);

  const onLogin = () => {
    if (!studentId || !password) return;
    Keyboard.dismiss();
    router.replace("/(tabs)/home");
  };

  return (
    <Pressable style={styles.root} onPress={Keyboard.dismiss}>
      {/* Decorative gradient blobs */}
      <View style={[styles.blobTop, { backgroundColor: colors.primary, opacity: mode === "dark" ? 0.22 : 0.18 }]} />
      <View style={[styles.blobBottom, { backgroundColor: colors.primaryLight, opacity: mode === "dark" ? 0.18 : 0.16 }]} />

      <SafeAreaView edges={["top"]} style={{ flex: 1 }}>
        <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
          <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
            {/* Top row: logo + theme toggle */}
            <View style={styles.brandRow}>
              <Image source={{ uri: LOGO_URL }} style={styles.logoImg} />
              <Text style={styles.brand}>D-CLIX</Text>
              <View style={{ flex: 1 }} />
              <TouchableOpacity style={styles.themeBtn} onPress={toggle} testID="login-theme-toggle">
                <Ionicons name={mode === "dark" ? "sunny" : "moon"} size={16} color={colors.primary} />
              </TouchableOpacity>
              <TouchableOpacity style={styles.helpBtn} testID="login-help">
                <Ionicons name="help-circle-outline" size={14} color={colors.textSecondary} />
                <Text style={styles.helpTxt}>Help</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.hero}>
              <Text style={styles.eyebrow}>WELCOME BACK</Text>
              <Text style={styles.title}>Let&apos;s get you{"\n"}back on the mat.</Text>
              <Text style={styles.subtitle}>Sign in to continue your training journey</Text>
            </View>

            <View style={styles.segment}>
              <TouchableOpacity style={{ flex: 1 }} onPress={() => setLoginMode("student")} testID="login-tab-student" activeOpacity={0.85}>
                {loginMode === "student" ? (
                  <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.chipActive, shadow.strong]}>
                    <Ionicons name="school" size={15} color="#fff" />
                    <Text style={styles.chipTxtActive}>Student</Text>
                  </LinearGradient>
                ) : (
                  <View style={styles.chipInactive}>
                    <Ionicons name="school" size={15} color={colors.textSecondary} />
                    <Text style={styles.chipTxt}>Student</Text>
                  </View>
                )}
              </TouchableOpacity>
              <TouchableOpacity style={{ flex: 1 }} onPress={() => setLoginMode("instructor")} testID="login-tab-instructor" activeOpacity={0.85}>
                {loginMode === "instructor" ? (
                  <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.chipActive, shadow.strong]}>
                    <Ionicons name="ribbon" size={15} color="#fff" />
                    <Text style={styles.chipTxtActive}>Instructor</Text>
                  </LinearGradient>
                ) : (
                  <View style={styles.chipInactive}>
                    <Ionicons name="ribbon" size={15} color={colors.textSecondary} />
                    <Text style={styles.chipTxt}>Instructor</Text>
                  </View>
                )}
              </TouchableOpacity>
            </View>

            <View style={styles.fieldGroup}>
              <Text style={styles.fieldLabel}>
                {loginMode === "student" ? "Student ID, phone or email" : "Instructor ID, phone or email"}
              </Text>
              <View style={[styles.inputLine, focus === "id" && { borderBottomColor: colors.primary }]}>
                <Ionicons name="at" size={18} color={focus === "id" ? colors.primary : colors.textMuted} />
                <TextInput
                  testID="login-id-input"
                  value={studentId}
                  onChangeText={setStudentId}
                  placeholder={loginMode === "student" ? "e.g. SA-2026-0142" : "e.g. IN-2025-0007"}
                  placeholderTextColor={colors.textMuted}
                  style={styles.input}
                  autoCapitalize="none"
                  onFocus={() => setFocus("id")}
                  onBlur={() => setFocus(null)}
                />
              </View>
            </View>

            <View style={styles.fieldGroup}>
              <View style={styles.labelRow}>
                <Text style={styles.fieldLabel}>Password</Text>
                <TouchableOpacity testID="login-forgot-password"><Text style={styles.forgot}>Forgot?</Text></TouchableOpacity>
              </View>
              <View style={[styles.inputLine, focus === "pwd" && { borderBottomColor: colors.primary }]}>
                <Ionicons name="lock-closed" size={18} color={focus === "pwd" ? colors.primary : colors.textMuted} />
                <TextInput
                  testID="login-password-input"
                  value={password}
                  onChangeText={setPassword}
                  placeholder="Enter password"
                  placeholderTextColor={colors.textMuted}
                  style={styles.input}
                  secureTextEntry={!showPwd}
                  onFocus={() => setFocus("pwd")}
                  onBlur={() => setFocus(null)}
                />
                <TouchableOpacity onPress={() => setShowPwd(!showPwd)} testID="login-toggle-password" hitSlop={8}>
                  <Ionicons name={showPwd ? "eye-off-outline" : "eye-outline"} size={18} color={colors.textSecondary} />
                </TouchableOpacity>
              </View>
            </View>

            <TouchableOpacity style={styles.remember} testID="login-remember">
              <View style={styles.checkbox}><Ionicons name="checkmark" size={12} color="#fff" /></View>
              <Text style={styles.rememberTxt}>Keep me signed in</Text>
            </TouchableOpacity>

            <TouchableOpacity testID="login-submit-button" onPress={onLogin} activeOpacity={0.92} style={[styles.signInWrap, shadow.strong]}>
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.signIn}>
                <Text style={styles.signInText}>Sign In</Text>
                <View style={styles.arrowCircle}>
                  <Ionicons name="arrow-forward" size={14} color={colors.primary} />
                </View>
              </LinearGradient>
            </TouchableOpacity>

            <View style={styles.divider}>
              <View style={styles.dLine} />
              <Text style={styles.dText}>or continue with</Text>
              <View style={styles.dLine} />
            </View>

            <View style={styles.altRow}>
              <TouchableOpacity style={styles.altBtn} testID="login-qr-option">
                <Ionicons name="qr-code-outline" size={20} color={colors.primary} />
                <Text style={styles.altTxt}>Academy QR</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.altBtn} testID="login-face-id">
                <Ionicons name="finger-print" size={20} color={colors.primary} />
                <Text style={styles.altTxt}>Biometric</Text>
              </TouchableOpacity>
            </View>

            <Text style={styles.footer}>
              New to D-Clix? <Text style={styles.footerLink}>Contact your academy</Text>
            </Text>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Pressable>
  );
}

function createStyles(colors: any, shadow: any) {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    blobTop: { position: "absolute", width: 280, height: 280, borderRadius: 140, top: -130, right: -80 },
    blobBottom: { position: "absolute", width: 220, height: 220, borderRadius: 110, bottom: -80, left: -60 },
    scroll: { padding: spacing.xl, paddingBottom: 40, minHeight: "100%" },

    brandRow: { flexDirection: "row", alignItems: "center", gap: 10, marginTop: 4 },
    logoImg: { width: 38, height: 38, borderRadius: 10 },
    brand: { color: colors.textPrimary, fontWeight: "900", letterSpacing: 3, fontSize: 14 },
    themeBtn: { width: 32, height: 32, borderRadius: 10, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center", marginRight: 6 },
    helpBtn: { flexDirection: "row", alignItems: "center", gap: 4, backgroundColor: colors.surfaceAlt, paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14 },
    helpTxt: { color: colors.textSecondary, fontSize: 12, fontWeight: "600" },

    hero: { marginTop: 48 },
    eyebrow: { fontSize: 11, fontWeight: "800", color: colors.primary, letterSpacing: 2.5 },
    title: { fontSize: 32, fontWeight: "800", color: colors.textPrimary, letterSpacing: -0.8, marginTop: 10, lineHeight: 38 },
    subtitle: { color: colors.textSecondary, fontSize: 14, marginTop: 10, fontWeight: "500" },

    segment: { flexDirection: "row", gap: 10, marginTop: 32 },
    chipActive: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6, paddingVertical: 12, borderRadius: radius.md },
    chipInactive: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6, paddingVertical: 12, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, borderWidth: 1, borderColor: colors.border },
    chipTxtActive: { color: "#fff", fontWeight: "700", fontSize: 13 },
    chipTxt: { color: colors.textSecondary, fontWeight: "700", fontSize: 13 },

    fieldGroup: { marginTop: 24 },
    labelRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
    fieldLabel: { fontSize: 12, color: colors.textSecondary, fontWeight: "700", letterSpacing: 0.3, marginBottom: 8 },
    forgot: { color: colors.primary, fontSize: 12, fontWeight: "700" },
    inputLine: { flexDirection: "row", alignItems: "center", gap: 12, borderBottomWidth: 1.5, borderBottomColor: colors.border, paddingVertical: Platform.OS === "ios" ? 14 : 6 },
    input: { flex: 1, color: colors.textPrimary, fontSize: 15, fontWeight: "600" },

    remember: { flexDirection: "row", alignItems: "center", gap: 8, marginTop: 20 },
    checkbox: { width: 18, height: 18, borderRadius: 5, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },
    rememberTxt: { color: colors.textSecondary, fontSize: 13, fontWeight: "600" },

    signInWrap: { marginTop: 28 },
    signIn: { paddingVertical: 18, borderRadius: radius.lg, flexDirection: "row", justifyContent: "center", alignItems: "center", gap: 10 },
    signInText: { color: "#fff", fontWeight: "800", fontSize: 15, letterSpacing: 0.5 },
    arrowCircle: { width: 26, height: 26, borderRadius: 13, backgroundColor: "#fff", alignItems: "center", justifyContent: "center" },

    divider: { flexDirection: "row", alignItems: "center", marginVertical: 22, gap: 10 },
    dLine: { flex: 1, height: 1, backgroundColor: colors.border },
    dText: { color: colors.textMuted, fontSize: 11, fontWeight: "600", letterSpacing: 0.5 },

    altRow: { flexDirection: "row", gap: 12 },
    altBtn: { flex: 1, flexDirection: "row", gap: 8, alignItems: "center", justifyContent: "center", paddingVertical: 14, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, borderWidth: 1, borderColor: colors.border },
    altTxt: { color: colors.textPrimary, fontWeight: "700", fontSize: 13 },

    footer: { textAlign: "center", marginTop: 28, color: colors.textSecondary, fontSize: 13 },
    footerLink: { color: colors.primary, fontWeight: "800" },
  });
}
