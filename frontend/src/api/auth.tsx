import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
import { setAuthToken, setUnauthorizedHandler } from "./http";
import { storage } from "./storage";
import { secureStore } from "./secureStore";
import { api } from "./endpoints";
import type { AuthUser } from "./types";

// The bearer token (the only real secret) lives in the OS secure store (Keychain/Keystore);
// the user profile — the user's own, non-secret, re-fetchable data — lives in AsyncStorage.
export const TOKEN_KEY = "dclix.token.v1";
export const USER_KEY = "dclix.user.v1";
const LEGACY_SESSION_KEY = "dclix.session.v1"; // pre-2.4 combined blob (token+user in AsyncStorage)

type Session = { token: string; user: AuthUser };

type StudentCreds = { username: string; password: string };
type InstructorCreds = {
  clubCode: string;
  branchId: number;
  username: string;
  password: string;
};

type AuthCtx = {
  ready: boolean; // restored from storage yet?
  user: AuthUser | null;
  token: string | null;
  isInstructor: boolean;
  loginStudent: (c: StudentCreds) => Promise<void>;
  loginInstructor: (c: InstructorCreds) => Promise<void>;
  logout: () => void;
  updateUser: (patch: Partial<AuthUser>) => void; // merge edited profile fields into the session
};

const Ctx = createContext<AuthCtx | null>(null);

function persist(session: Session | null) {
  // fire-and-forget: stores are async but callers don't need to wait
  if (session) {
    void secureStore.set(TOKEN_KEY, session.token);
    void storage.set(USER_KEY, JSON.stringify(session.user));
  } else {
    void secureStore.remove(TOKEN_KEY);
    void storage.remove(USER_KEY);
    void storage.remove(LEGACY_SESSION_KEY);
  }
}

// Read the persisted session, migrating a pre-2.4 combined blob into the split stores.
async function loadSession(): Promise<Session | null> {
  try {
    const token = await secureStore.get(TOKEN_KEY);
    const userRaw = await storage.get(USER_KEY);
    if (token && userRaw) {
      const user = JSON.parse(userRaw) as AuthUser;
      if (user) return { token, user };
    }
    // Migration: older builds stored { token, user } together in AsyncStorage.
    const legacy = await storage.get(LEGACY_SESSION_KEY);
    if (legacy) {
      const s = JSON.parse(legacy) as Session;
      if (s?.token && s?.user) {
        persist(s); // re-home into secure + user stores
        void storage.remove(LEGACY_SESSION_KEY);
        return s;
      }
    }
  } catch {}
  return null;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);

  // Restore persisted session on mount.
  useEffect(() => {
    let alive = true;
    (async () => {
      const s = await loadSession();
      if (alive && s) {
        setAuthToken(s.token);
        setSession(s);
      }
      if (alive) setReady(true);
    })();
    return () => {
      alive = false;
    };
  }, []);

  // Wire 401 → auto logout.
  useEffect(() => {
    setUnauthorizedHandler(() => {
      setAuthToken(null);
      persist(null);
      setSession(null);
    });
    return () => setUnauthorizedHandler(null);
  }, []);

  async function authenticate(body: any, extra?: Partial<AuthUser>) {
    const env = await api.authenticate(body);
    const data: AuthUser | undefined = env?.data;
    if (env?.status !== 200 || !data?.accessToken) {
      throw new Error(env?.meta?.message || "Invalid credentials. Please try again.");
    }
    const user: AuthUser = { ...data, ...extra };
    setAuthToken(user.accessToken);
    const s: Session = { token: user.accessToken, user };
    persist(s);
    setSession(s);
  }

  const value = useMemo<AuthCtx>(
    () => ({
      ready,
      user: session?.user ?? null,
      token: session?.token ?? null,
      // Role is decided by which login flow was used (student tab vs instructor tab), not the
      // response userType — instructors come back with varying userTypes (0, 2, ...) while only
      // students are userType 3. Fall back to userType for any older session without a role tag.
      isInstructor: session?.user
        ? session.user.role
          ? session.user.role === "instructor"
          : session.user.userType !== 3
        : false,
      loginStudent: (c) =>
        authenticate(
          {
            userType: 3,
            username: c.username.trim(),
            password: c.password,
            accessMethod: 0,
            branchId: 0,
          },
          { role: "student" }
        ),
      loginInstructor: (c) =>
        authenticate(
          {
            userType: 0,
            clubCode: c.clubCode.trim(),
            branchId: c.branchId,
            username: c.username.trim(),
            password: c.password,
            accessMethod: 0,
          },
          { role: "instructor", clubCode: c.clubCode.trim() } // role + clubCode kept on the session
        ),
      logout: () => {
        setAuthToken(null);
        persist(null);
        setSession(null);
      },
      updateUser: (patch) =>
        setSession((prev) => {
          if (!prev) return prev;
          const next = { ...prev, user: { ...prev.user, ...patch } };
          persist(next);
          return next;
        }),
    }),
    [ready, session]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error("useAuth must be used within AuthProvider");
  return v;
}
