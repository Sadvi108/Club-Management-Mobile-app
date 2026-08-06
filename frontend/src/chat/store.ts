// Local echo store for chat. The backend delivers our sent messages to the club admin
// but exposes NO endpoint to read them back, so the app persists its own copy per
// user + thread (AsyncStorage). Incoming messages always come from the server.
import { storage } from "../api/storage";

export type SentMsg = { id: string; text: string; at: string };

// Pseudo-thread for new conversations with the club (Send2ClubHelpDesk).
export const HELPDESK_THREAD = "helpdesk";

const KEY = (userId: number) => `dclix.chat.sent.v1.${userId}`;

type SentMap = Record<string, SentMsg[]>;

async function readAll(userId: number): Promise<SentMap> {
  try {
    const raw = await storage.get(KEY(userId));
    if (raw) return JSON.parse(raw) as SentMap;
  } catch {}
  return {};
}

export async function getSent(userId: number, threadKey: string): Promise<SentMsg[]> {
  const all = await readAll(userId);
  return all[threadKey] ?? [];
}

export async function appendSent(userId: number, threadKey: string, text: string): Promise<SentMsg> {
  const msg: SentMsg = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    text,
    at: new Date().toISOString(),
  };
  const all = await readAll(userId);
  all[threadKey] = [...(all[threadKey] ?? []), msg];
  await storage.set(KEY(userId), JSON.stringify(all));
  return msg;
}

/** Threads the user has sent messages in (helpdesk shows up even before any reply). */
export async function threadsWithSent(userId: number): Promise<Record<string, SentMsg[]>> {
  return readAll(userId);
}
