import { Tabs, useRouter, Redirect } from "expo-router";
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { BlurView } from "expo-blur";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useTheme } from "../../src/theme";
import { useAuth } from "../../src/api/auth";

function FabQR({ onPress, gradient }: { onPress: () => void; gradient: readonly [string, string, string] }) {
  return (
    <TouchableOpacity testID="fab-qr-scan" onPress={onPress} activeOpacity={0.9} style={styles.fabWrap}>
      <LinearGradient colors={gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.fab}>
        {/* smoother viewfinder look than the busy qr-code grid */}
        <Ionicons name="scan-outline" size={30} color="#fff" />
      </LinearGradient>
      <Text style={[styles.fabLabel, { color: gradient[1] }]}>Scan</Text>
    </TouchableOpacity>
  );
}

// filled icon when focused, outline otherwise
const tabIcon =
  (name: string) =>
  ({ color, focused }: { color: string; focused: boolean }) =>
    <Ionicons name={(focused ? name : `${name}-outline`) as any} size={22} color={color} />;

const HIDDEN = { href: null } as const;

export default function TabsLayout() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const { ready, user, isInstructor } = useAuth();
  const insets = useSafeAreaInsets();

  // Protect the tab group: wait for session restore, then gate on auth.
  if (!ready) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: colors.background }}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }
  if (!user) return <Redirect href="/login" />;

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarShowLabel: true,
        tabBarLabelStyle: { fontSize: 10, fontWeight: "600", marginTop: -2 },
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        // Android: an absolute bar would float above the open keyboard — hide it instead
        tabBarHideOnKeyboard: true,
        // Frosted liquid-glass tab bar (blur over the content behind it).
        tabBarBackground: () => (
          <BlurView
            intensity={mode === "dark" ? 40 : 60}
            tint={mode === "dark" ? "dark" : "light"}
            style={[StyleSheet.absoluteFill, { backgroundColor: colors.glassBg, borderTopWidth: 1, borderTopColor: colors.glassBorder }]}
          />
        ),
        tabBarStyle: {
          position: "absolute",
          borderTopWidth: 0,
          backgroundColor: "transparent",
          // Size from the device's real bottom inset so the bar clears the Android
          // system nav (gesture pill or 3-button) and the iOS home indicator alike.
          height: 62 + insets.bottom,
          paddingTop: 8,
          paddingBottom: Math.max(insets.bottom, 10),
          paddingHorizontal: 6,
          ...shadow.card,
        },
      }}
    >
      {/* Declaration order keeps the Scan FAB visually 3rd-of-5 for BOTH roles. Each non-shared
          tab is shown for its role and hidden (href:null) for the other. */}
      <Tabs.Screen name="home" options={{ title: "Home", tabBarIcon: tabIcon("home") }} />
      {/* Training lives inside the student Home → Quick Access; keep it routable, off the bar */}
      <Tabs.Screen name="training" options={HIDDEN} />
      <Tabs.Screen name="schedule" options={isInstructor ? HIDDEN : { title: "Schedule", tabBarIcon: tabIcon("calendar") }} />
      <Tabs.Screen name="collections" options={isInstructor ? { title: "Collections", tabBarIcon: tabIcon("cash") } : HIDDEN} />
      {/* Scan sits in the visual middle (3rd of 5) for both roles */}
      <Tabs.Screen name="qr" options={{ title: "", tabBarButton: () => <FabQR onPress={() => router.push("/qr-scan")} gradient={colors.gradient} /> }} />
      <Tabs.Screen name="payments" options={isInstructor ? HIDDEN : { title: "Payments", tabBarIcon: tabIcon("wallet") }} />
      <Tabs.Screen name="reports" options={isInstructor ? { title: "Reports", tabBarIcon: tabIcon("document-text") } : HIDDEN} />
      <Tabs.Screen name="profile" options={isInstructor ? HIDDEN : { title: "Profile", tabBarIcon: tabIcon("person") }} />
      <Tabs.Screen name="settings" options={isInstructor ? { title: "Settings", tabBarIcon: tabIcon("settings") } : HIDDEN} />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  fabWrap: { flex: 1, alignItems: "center", justifyContent: "flex-end" },
  fab: {
    width: 58, height: 58, borderRadius: 29,
    alignItems: "center", justifyContent: "center",
    marginTop: -26,
    borderWidth: 4,
    borderColor: "#fff",
    shadowColor: "#F97316",
    shadowOpacity: 0.35, shadowRadius: 16, shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
  fabLabel: { fontSize: 10, fontWeight: "700", marginTop: 4 },
});
