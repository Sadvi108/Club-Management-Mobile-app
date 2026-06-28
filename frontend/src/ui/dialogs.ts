import { Alert, Platform } from "react-native";
import type { Router } from "expo-router";

// react-native-web does NOT implement Alert.alert (it's a silent no-op), so any confirm/notify
// built on Alert never appears on web and callbacks inside it never fire — which silently breaks
// logout, "Saved → go back", error toasts, etc. These helpers fall back to the browser dialogs on
// web and use Alert on native, returning a Promise so call sites read the same on both platforms.

const isWeb = Platform.OS === "web";
const join = (title: string, message?: string) => (message ? `${title}\n\n${message}` : title);

// Yes/No confirmation. Resolves true when the user confirms.
export function confirmDialog(
  title: string,
  message?: string,
  opts?: { confirmLabel?: string; cancelLabel?: string; destructive?: boolean }
): Promise<boolean> {
  const confirmLabel = opts?.confirmLabel ?? "OK";
  const cancelLabel = opts?.cancelLabel ?? "Cancel";
  if (isWeb) {
    const ok = typeof window !== "undefined" && window.confirm(join(title, message));
    return Promise.resolve(!!ok);
  }
  return new Promise((resolve) => {
    Alert.alert(title, message, [
      { text: cancelLabel, style: "cancel", onPress: () => resolve(false) },
      { text: confirmLabel, style: opts?.destructive ? "destructive" : "default", onPress: () => resolve(true) },
    ]);
  });
}

// Single-OK message. Resolves when dismissed.
export function notify(title: string, message?: string): Promise<void> {
  if (isWeb) {
    if (typeof window !== "undefined") window.alert(join(title, message));
    return Promise.resolve();
  }
  return new Promise((resolve) => {
    Alert.alert(title, message, [{ text: "OK", onPress: () => resolve() }]);
  });
}

// Go back if there's somewhere to go back to, else navigate to a sensible default. Plain
// router.back() is a dead no-op ("GO_BACK was not handled") when the screen is the first route
// (deep link, page refresh, post-replace), which is why some back buttons appear broken.
export function safeBack(router: Router, fallback: string = "/(tabs)/home") {
  if (router.canGoBack()) router.back();
  else router.replace(fallback as any);
}
