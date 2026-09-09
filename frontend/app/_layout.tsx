import { Redirect, Stack, usePathname } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { ThemeProvider, useTheme } from "../src/theme";
import { AuthProvider, useAuth } from "../src/api/auth";
import { NotificationsProvider } from "../src/notifications/NotificationsProvider";

/** Routes reachable without a session. Everything else requires one. */
const PUBLIC_ROUTES = ["/", "/login", "/user-guide"];

function ThemedStack() {
  const { mode } = useTheme();
  const { ready, user } = useAuth();
  const pathname = usePathname();

  // The session gate used to live only in (tabs)/_layout, which left every root route —
  // edit-profile, notifications, purchases, chat, the r-* reports — renderable with a null
  // user via a deep link or a web URL. They degraded into blank shells with no way back,
  // and a 401 mid-session stranded the user wherever they were. Gate the whole stack.
  if (ready && !user && !PUBLIC_ROUTES.includes(pathname)) {
    return <Redirect href="/login" />;
  }

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
        <Stack.Screen name="competition" />
        <Stack.Screen name="qr-scan" options={{ presentation: "modal", animation: "fade_from_bottom" }} />
        <Stack.Screen name="book-class" options={{ animation: "slide_from_bottom" }} />
        <Stack.Screen name="more" />
        <Stack.Screen name="notifications" />
        <Stack.Screen name="notification-settings" />
        <Stack.Screen name="edit-profile" />
        <Stack.Screen name="student-details" />
        <Stack.Screen name="purchases" />
        <Stack.Screen name="helpdesk" />
        <Stack.Screen name="offer-detail" />
        <Stack.Screen name="chat" />
        <Stack.Screen name="chat-thread" />
        <Stack.Screen name="user-guide" options={{ animation: "slide_from_bottom" }} />
        <Stack.Screen name="new-student" />
        <Stack.Screen name="student-particulars" />
      </Stack>
    </>
  );
}

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <AuthProvider>
        <NotificationsProvider>
          <ThemeProvider>
            <ThemedStack />
          </ThemeProvider>
        </NotificationsProvider>
      </AuthProvider>
    </SafeAreaProvider>
  );
}
