// Audible alert for the WEB build.
//
// Native gets its sound from the notification channel / UNNotificationSound (the bundled
// assets/sounds/dclix_alert.wav), which the OS plays even when the app is backgrounded.
// The browser gives us nothing equivalent: `new Notification(...)` is SILENT in Chrome,
// Firefox and Safari — there is no `sound` option and `silent:false` only means "don't
// suppress", not "make noise". So on web we synthesise the same two-note chime with the
// Web Audio API alongside the visual notification. Synthesising it (rather than loading
// the .wav) keeps the web bundle free of an audio asset and of any decode/CORS failure
// mode, and it matches the native chime by construction — both are the same two notes.
import { Platform } from "react-native";

let ctx: AudioContext | null = null;
let unlocked = false;

function getCtx(): AudioContext | null {
  if (Platform.OS !== "web" || typeof window === "undefined") return null;
  const Ctor: typeof AudioContext | undefined =
    (window as any).AudioContext || (window as any).webkitAudioContext;
  if (!Ctor) return null;
  if (!ctx) {
    try {
      ctx = new Ctor();
    } catch {
      return null;
    }
  }
  return ctx;
}

/**
 * Browsers start an AudioContext "suspended" until a real user gesture resumes it.
 * Call this from any tap/click once per session; after that the poller can play the
 * chime on its own. Cheap and idempotent — safe to wire to a global listener.
 */
export function unlockWebAudio(): void {
  if (unlocked) return;
  const c = getCtx();
  if (!c) return;
  unlocked = true;
  if (c.state === "suspended") void c.resume().catch(() => {});
}

/** True once a gesture has resumed the context, so settings UI can explain silence. */
export function isWebAudioUnlocked(): boolean {
  const c = getCtx();
  return !!c && c.state === "running";
}

// Same notes as the generated .wav: A5 → D6, struck 160 ms apart with an
// exponential decay, so web and native are recognisably the same alert.
const NOTES: { freq: number; at: number; dur: number; gain: number }[] = [
  { freq: 880.0, at: 0.0, dur: 0.5, gain: 0.22 },
  { freq: 1174.66, at: 0.16, dur: 0.62, gain: 0.2 },
];

/** Play the alert chime on web. No-op on native and when audio is unavailable/blocked. */
export function playAlertChime(): void {
  const c = getCtx();
  if (!c) return;
  try {
    if (c.state === "suspended") void c.resume().catch(() => {});
    const t0 = c.currentTime;
    for (const n of NOTES) {
      const osc = c.createOscillator();
      const amp = c.createGain();
      osc.type = "sine";
      osc.frequency.value = n.freq;
      const start = t0 + n.at;
      // 6 ms attack then an exponential tail — a hard gate would click.
      amp.gain.setValueAtTime(0.0001, start);
      amp.gain.exponentialRampToValueAtTime(n.gain, start + 0.006);
      amp.gain.exponentialRampToValueAtTime(0.0001, start + n.dur);
      osc.connect(amp).connect(c.destination);
      osc.start(start);
      osc.stop(start + n.dur + 0.02);
    }
  } catch {
    /* audio is a nicety — never let it break the notification itself */
  }
}

/** Buzz the device on web, where the OS notification does not vibrate for us. */
export function vibrateWeb(): void {
  if (Platform.OS !== "web" || typeof navigator === "undefined") return;
  try {
    navigator.vibrate?.([0, 180, 90, 180]);
  } catch {
    /* unsupported on desktop browsers */
  }
}
