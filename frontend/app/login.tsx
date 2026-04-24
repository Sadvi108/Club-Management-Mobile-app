import { useState } from "react";
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
  TouchableWithoutFeedback,
} from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { colors, font, radius, shadow, spacing } from "../src/theme";

export default function Login() {
  const router = useRouter();
  const [studentId, setStudentId] = useState("SA-2026-0142");
  const [password, setPassword] = useState("demo1234");
  const [showPwd, setShowPwd] = useState(false);
  const [mode, setMode] = useState<"student" | "parent">("student");

  const onLogin = () => {
    if (!studentId || !password) return;
    Keyboard.dismiss();
    router.replace("/(tabs)/home");
  };

  return (
    <View style={styles.root}>
      <LinearGradient colors={colors.gradient} style={styles.topGradient}>
        <SafeAreaView edges={["top"]}>
          <View style={styles.brandRow}>
            <View style={styles.logoBox}>
              <Ionicons name="flash" size={22} color={colors.primary} />
            </View>
            <Text style={styles.brand}>APEX ACADEMY</Text>
          </View>
          <Text style={styles.welcome}>Welcome Back,{"\n"}Champion 👋</Text>
          <Text style={styles.sub}>Sign in to continue your training journey</Text>
        </SafeAreaView>
      </LinearGradient>

      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        style={{ flex: 1 }}
      >
        <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
          <ScrollView
            style={{ flex: 1 }}
            contentContainerStyle={styles.formScroll}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.card}>
              <View style={styles.tabs}>
                <TouchableOpacity
                  testID="login-tab-student"
                  style={[styles.tab, mode === "student" && styles.tabActive]}
                  onPress={() => setMode("student")}
                >
                  <Text style={[styles.tabText, mode === "student" && styles.tabTextActive]}>Student</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  testID="login-tab-parent"
                  style={[styles.tab, mode === "parent" && styles.tabActive]}
                  onPress={() => setMode("parent")}
                >
                  <Text style={[styles.tabText, mode === "parent" && styles.tabTextActive]}>Parent</Text>
                </TouchableOpacity>
              </View>

              <Text style={styles.label}>
                {mode === "student" ? "Student ID / Phone / Email" : "Parent Phone / Email"}
              </Text>
              <View style={styles.inputWrap}>
                <Ionicons name="person-outline" size={18} color={colors.textSecondary} />
                <TextInput
                  testID="login-id-input"
                  value={studentId}
                  onChangeText={setStudentId}
                  placeholder="Enter your ID"
                  placeholderTextColor={colors.textMuted}
                  style={styles.input}
                  autoCapitalize="none"
                />
              </View>

              <Text style={styles.label}>Password</Text>
              <View style={styles.inputWrap}>
                <Ionicons name="lock-closed-outline" size={18} color={colors.textSecondary} />
                <TextInput
                  testID="login-password-input"
                  value={password}
                  onChangeText={setPassword}
                  placeholder="Enter password"
                  placeholderTextColor={colors.textMuted}
                  style={styles.input}
                  secureTextEntry={!showPwd}
                />
                <TouchableOpacity onPress={() => setShowPwd(!showPwd)} testID="login-toggle-password">
                  <Ionicons name={showPwd ? "eye-off-outline" : "eye-outline"} size={18} color={colors.textSecondary} />
                </TouchableOpacity>
              </View>

              <TouchableOpacity style={styles.forgotBtn} testID="login-forgot-password">
                <Text style={styles.forgot}>Forgot password?</Text>
              </TouchableOpacity>

              <TouchableOpacity testID="login-submit-button" onPress={onLogin} activeOpacity={0.9}>
                <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.signIn}>
                  <Text style={styles.signInText}>Sign In</Text>
                  <Ionicons name="arrow-forward" size={18} color="#fff" />
                </LinearGradient>
              </TouchableOpacity>

              <View style={styles.divider}>
                <View style={styles.dLine} />
                <Text style={styles.dText}>or</Text>
                <View style={styles.dLine} />
              </View>

              <TouchableOpacity style={styles.secondary} testID="login-qr-option">
                <Ionicons name="qr-code-outline" size={18} color={colors.primary} />
                <Text style={styles.secondaryText}>Scan Academy QR to Login</Text>
              </TouchableOpacity>
            </View>

            <Text style={styles.footer}>
              New to Apex? <Text style={styles.footerLink}>Contact your academy</Text>
            </Text>
          </ScrollView>
        </TouchableWithoutFeedback>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  topGradient: { paddingHorizontal: spacing.xl, paddingBottom: 44, borderBottomLeftRadius: 32, borderBottomRightRadius: 32 },
  brandRow: { flexDirection: "row", alignItems: "center", gap: 10, marginTop: 8 },
  logoBox: { width: 36, height: 36, borderRadius: 10, backgroundColor: "#fff", alignItems: "center", justifyContent: "center" },
  brand: { color: "#fff", fontWeight: "800", letterSpacing: 2, fontSize: 14 },
  welcome: { color: "#fff", fontSize: 28, fontWeight: "800", marginTop: 24, letterSpacing: -0.5 },
  sub: { color: "rgba(255,255,255,0.85)", marginTop: 8, fontSize: 13 },
  formScroll: { padding: spacing.xl, paddingTop: 0 },
  card: {
    backgroundColor: "#fff",
    borderRadius: radius.xxl,
    padding: spacing.xl,
    marginTop: -28,
    ...shadow.card,
  },
  tabs: { flexDirection: "row", backgroundColor: colors.surfaceAlt, borderRadius: radius.md, padding: 4, marginBottom: spacing.xl },
  tab: { flex: 1, paddingVertical: 10, borderRadius: radius.sm, alignItems: "center" },
  tabActive: { backgroundColor: "#fff", ...shadow.soft },
  tabText: { color: colors.textSecondary, fontWeight: "600", fontSize: 13 },
  tabTextActive: { color: colors.primary },
  label: { ...font.tiny, color: colors.textSecondary, marginBottom: 8, marginTop: 6 },
  inputWrap: {
    flexDirection: "row", alignItems: "center", gap: 10,
    borderWidth: 1, borderColor: colors.border, borderRadius: radius.md,
    paddingHorizontal: 14, paddingVertical: Platform.OS === "ios" ? 14 : 4, marginBottom: 14,
    backgroundColor: colors.surfaceAlt,
  },
  input: { flex: 1, color: colors.textPrimary, fontSize: 14, fontWeight: "500" },
  forgotBtn: { alignSelf: "flex-end", paddingVertical: 6 },
  forgot: { color: colors.primary, fontSize: 12, fontWeight: "600" },
  signIn: {
    marginTop: 8, paddingVertical: 16, borderRadius: radius.md,
    flexDirection: "row", justifyContent: "center", alignItems: "center", gap: 8,
    ...shadow.strong,
  },
  signInText: { color: "#fff", fontWeight: "700", fontSize: 15, letterSpacing: 0.3 },
  divider: { flexDirection: "row", alignItems: "center", marginVertical: 20, gap: 10 },
  dLine: { flex: 1, height: 1, backgroundColor: colors.border },
  dText: { color: colors.textMuted, fontSize: 12 },
  secondary: {
    flexDirection: "row", gap: 10, alignItems: "center", justifyContent: "center",
    paddingVertical: 14, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, backgroundColor: "#fff",
  },
  secondaryText: { color: colors.primary, fontWeight: "700", fontSize: 14 },
  footer: { textAlign: "center", marginTop: 20, color: colors.textSecondary, fontSize: 13 },
  footerLink: { color: colors.primary, fontWeight: "700" },
});
