// Tiny dependency-free persistence.
// - Web (localhost preview): uses window.localStorage → survives reloads.
// - Native: in-memory fallback (session lasts while app is open). Swap for
//   @react-native-async-storage/async-storage later for real device persistence.
const mem = new Map<string, string>();

const hasLocalStorage =
  typeof globalThis !== "undefined" &&
  typeof (globalThis as any).localStorage !== "undefined";

export const storage = {
  get(key: string): string | null {
    try {
      if (hasLocalStorage) return (globalThis as any).localStorage.getItem(key);
    } catch {}
    return mem.has(key) ? (mem.get(key) as string) : null;
  },
  set(key: string, value: string): void {
    try {
      if (hasLocalStorage) {
        (globalThis as any).localStorage.setItem(key, value);
        return;
      }
    } catch {}
    mem.set(key, value);
  },
  remove(key: string): void {
    try {
      if (hasLocalStorage) (globalThis as any).localStorage.removeItem(key);
    } catch {}
    mem.delete(key);
  },
};
