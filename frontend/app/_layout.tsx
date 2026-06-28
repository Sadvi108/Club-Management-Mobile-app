import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { ThemeProvider, useTheme } from "../src/theme";
import { AuthProvider } from "../src/api/auth";

function ThemedStack() {
  const { mode } = useTheme();
  return (
    <>
      <StatusBar style={mode === "dark" ? "light" : "dark"} />
      <Stack screenOptions={{ headerShown: false, animation: "slide_from_right" }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="login" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="attendance" options={{ animation: "slide_from_bottom" }} />
        <Stack.Screen name="progress" />
        <Stack.Screen name="events" />
        <Stack.Screen name="qr-scan" options={{ presentation: "modal", animation: "fade_from_bottom" }} />
        <Stack.Screen name="book-class" options={{ animation: "slide_from_bottom" }} />
        <Stack.Screen name="more" />
        <Stack.Screen name="notifications" />
        <Stack.Screen name="edit-profile" />
        <Stack.Screen name="student-details" />
        <Stack.Screen name="purchases" />
        <Stack.Screen name="helpdesk" />
      </Stack>
    </>
  );
}

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <AuthProvider>
        <ThemeProvider>
          <ThemedStack />
        </ThemeProvider>
      </AuthProvider>
    </SafeAreaProvider>
  );
}
