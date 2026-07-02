import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
import { setAuthToken, setUnauthorizedHandler } from "./http";
import { storage } from "./storage";
import { api } from "./endpoints";
import type { AuthUser } from "./types";

const SESSION_KEY = "dclix.session.v1";

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
  // fire-and-forget: storage is async (AsyncStorage) but callers don't need to wait
  if (session) void storage.set(SESSION_KEY, JSON.stringify(session));
  else void storage.remove(SESSION_KEY);
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);

  // Restore persisted session on mount.
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const raw = await storage.get(SESSION_KEY);
        if (alive && raw) {
          const s = JSON.parse(raw) as Session;
          if (s?.token && s?.user) {
            setAuthToken(s.token);
            setSession(s);
          }
        }
      } catch {}
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
