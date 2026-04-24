import { Tabs, useRouter } from "expo-router";
import { View, Text, StyleSheet, TouchableOpacity, Platform } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useTheme } from "../../src/theme";

function FabQR({ onPress, gradient }: { onPress: () => void; gradient: readonly [string, string, string] }) {
  return (
    <TouchableOpacity testID="fab-qr-scan" onPress={onPress} activeOpacity={0.9} style={styles.fabWrap}>
      <LinearGradient colors={gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.fab}>
        <Ionicons name="qr-code" size={26} color="#fff" />
      </LinearGradient>
      <Text style={[styles.fabLabel, { color: gradient[1] }]}>Scan</Text>
    </TouchableOpacity>
  );
}

export default function TabsLayout() {
  const router = useRouter();
  const { colors, shadow } = useTheme();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarShowLabel: true,
        tabBarLabelStyle: { fontSize: 10, fontWeight: "600", marginTop: -2 },
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: {
          position: "absolute",
          borderTopWidth: 0,
          backgroundColor: colors.surface,
          height: Platform.OS === "ios" ? 84 : 68,
          paddingTop: 8,
          paddingBottom: Platform.OS === "ios" ? 24 : 10,
          paddingHorizontal: 6,
          ...shadow.card,
        },
      }}
    >
      <Tabs.Screen name="home" options={{ title: "Home", tabBarIcon: ({ color, focused }) => <Ionicons name={focused ? "home" : "home-outline"} size={22} color={color} /> }} />
      <Tabs.Screen name="training" options={{ title: "Training", tabBarIcon: ({ color, focused }) => <Ionicons name={focused ? "barbell" : "barbell-outline"} size={22} color={color} /> }} />
      <Tabs.Screen name="qr" options={{ title: "", tabBarButton: () => <FabQR onPress={() => router.push("/qr-scan")} gradient={colors.gradient} /> }} />
      <Tabs.Screen name="schedule" options={{ title: "Schedule", tabBarIcon: ({ color, focused }) => <Ionicons name={focused ? "calendar" : "calendar-outline"} size={22} color={color} /> }} />
      <Tabs.Screen name="payments" options={{ title: "Payments", tabBarIcon: ({ color, focused }) => <Ionicons name={focused ? "wallet" : "wallet-outline"} size={22} color={color} /> }} />
      <Tabs.Screen name="profile" options={{ title: "Profile", tabBarIcon: ({ color, focused }) => <Ionicons name={focused ? "person" : "person-outline"} size={22} color={color} /> }} />
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
