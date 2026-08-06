// Secure storage for the one real secret the client holds: the bearer token.
// - Native: expo-secure-store → iOS Keychain / Android Keystore-backed store (encrypted at rest,
//   not readable from a plain ADB backup or by other apps).
// - Web (localhost preview only): falls back to localStorage (no Keychain in a browser).
// A memory fallback keeps auth working if the secure module ever throws.
import { Platform } from "react-native";

const mem = new Map<string, string>();

let SecureStore: typeof import("expo-secure-store") | null = null;
if (Platform.OS !== "web") {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    SecureStore = require("expo-secure-store");
  } catch {
    SecureStore = null;
  }
}

const webLS = (): Storage | null => {
  try {
    if (typeof globalThis !== "undefined" && (globalThis as any).localStorage) {
      return (globalThis as any).localStorage as Storage;
    }
  } catch {}
  return null;
};

export const secureStore = {
  async get(key: string): Promise<string | null> {
    try {
      if (SecureStore) {
        const v = await SecureStore.getItemAsync(key);
        if (v != null) return v;
      } else {
        const ls = webLS();
        if (ls) {
          const v = ls.getItem(key);
          if (v != null) return v;
        }
      }
    } catch {}
    return mem.has(key) ? (mem.get(key) as string) : null;
  },
  async set(key: string, value: string): Promise<void> {
    mem.set(key, value);
    try {
      if (SecureStore) await SecureStore.setItemAsync(key, value);
      else webLS()?.setItem(key, value);
    } catch {}
  },
  async remove(key: string): Promise<void> {
    mem.delete(key);
    try {
      if (SecureStore) await SecureStore.deleteItemAsync(key);
      else webLS()?.removeItem(key);
    } catch {}
  },
};
