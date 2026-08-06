// Tiny persistence wrapper over AsyncStorage (async API).
// - Web: AsyncStorage is backed by window.localStorage → survives reloads.
// - Native: real device storage → session + chat history survive app restarts.
// A memory fallback keeps everything working if AsyncStorage ever throws (e.g. SSR).
import AsyncStorage from "@react-native-async-storage/async-storage";

const mem = new Map<string, string>();

export const storage = {
  async get(key: string): Promise<string | null> {
    try {
      const v = await AsyncStorage.getItem(key);
      if (v != null) return v;
    } catch {}
    return mem.has(key) ? (mem.get(key) as string) : null;
  },
  async set(key: string, value: string): Promise<void> {
    mem.set(key, value);
    try {
      await AsyncStorage.setItem(key, value);
    } catch {}
  },
  async remove(key: string): Promise<void> {
    mem.delete(key);
    try {
      await AsyncStorage.removeItem(key);
    } catch {}
  },
};
