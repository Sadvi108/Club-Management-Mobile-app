import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <Stack screenOptions={{ headerShown: false, animation: "slide_from_right" }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="login" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="attendance" options={{ animation: "slide_from_bottom" }} />
        <Stack.Screen name="progress" />
        <Stack.Screen name="events" />
        <Stack.Screen name="qr-scan" options={{ presentation: "modal", animation: "fade_from_bottom" }} />
      </Stack>
    </SafeAreaProvider>
  );
}
