import { useMemo, useRef, useState } from "react";
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, FlatList, Image, useWindowDimensions,
} from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";

// ─────────────────────────────────────────────────────────────────────────────
// User Guide — a walkthrough of the real app, reachable from the login screen
// and from Profile.
//
// The pictures are REAL SCREENSHOTS of the current build (assets/guide/*.png),
// captured from the running app by scripts/generate-guide-shots.js. They replaced
// hand-drawn mock previews, which drifted out of date every time a screen changed.
// Re-run that script whenever the UI moves on.
//
// The screenshots are deliberately of a DEMO account: the capture script rewrites
// the signed-in identity before shooting, so no real member's name, phone number,
// registration code or member QR ships inside the app.
//
// No API calls here: the guide must work before signing in.
// ─────────────────────────────────────────────────────────────────────────────

type Step = {
  key: string;
  icon: string;
  title: string;
  intro: string;
  shot: number; // require() of a bundled screenshot
  details: { n: number; title: string; text: string }[];
  tips?: string[];
  note?: string; // highlighted "read this or you'll get it wrong" callout
};

const STEPS: Step[] = [
  {
    key: "signin",
    icon: "log-in",
    title: "Signing in",
    intro:
      "Your academy issues one account per member. Everything you see in the app — fees, attendance, grading — belongs to that account.",
    shot: require("../assets/guide/login.png"),
    details: [
      {
        n: 1,
        title: "Student or Instructor",
        text: "Students stay on the Student tab. Instructors switch to Instructor, which also asks for a club code and branch — those come from your academy.",
      },
      {
        n: 2,
        title: "Student ID, phone or email",
        text: "Any one of the three works. If you are not sure what your student ID is, your academy can look it up for you.",
      },
      {
        n: 3,
        title: "Password",
        text: "Tap the eye to check what you typed. Forgot? sends a reset request to your academy — they confirm your identity before issuing a new one.",
      },
      {
        n: 4,
        title: "You stay signed in",
        text: "After one successful sign-in the app remembers this device, so you go straight to your dashboard next time. Logging out from Profile clears it.",
      },
    ],
    tips: [
      "Not a member yet? Contact your academy at the bottom of this screen — accounts are created by the club, not in the app.",
      "This guide is on the sign-in screen too, so you can read it before you have an account.",
    ],
  },
  {
    key: "home",
    icon: "home",
    title: "Your home dashboard",
    intro:
      "Home is the summary of everything that needs your attention today. It refreshes from the club system each time you open it.",
    shot: require("../assets/guide/home.png"),
    details: [
      {
        n: 1,
        title: "Your three headline numbers",
        text: "Open invoices, your current grade and total amount due. Tapping the card takes you to the detail behind it.",
      },
      {
        n: 2,
        title: "Shortcut row",
        text: "Training, Attendance, Timetable, Virtual ID and Profile — the five things members open most, one tap from the top of the screen.",
      },
      {
        n: 3,
        title: "Fees due",
        text: "Pay Now opens the payment screen with your outstanding invoices already listed. The card disappears when you owe nothing.",
      },
      {
        n: 4,
        title: "Today's class",
        text: "Your next session with its time, centre and instructor. Check In jumps straight to the QR scanner.",
      },
      {
        n: 5,
        title: "Quick Access + the bell",
        text: "Shortcuts to every feature, ending in More for the full catalogue. The bell badge counts unread club notifications.",
      },
    ],
  },
  {
    key: "checkin",
    icon: "qr-code",
    title: "Checking in with QR",
    intro:
      "Attendance is marked by scanning the QR poster displayed at your training centre. Tap Scan — the round button in the middle of the tab bar — and point your camera at it.",
    shot: require("../assets/guide/attendance.png"),
    note:
      "Scan the centre's poster, not your own Virtual ID. The centre code says WHERE you are training; your personal QR is only for identifying yourself at the counter and will be rejected by the check-in scanner.",
    details: [
      {
        n: 1,
        title: "Your attendance rate",
        text: "Present, absent and total sessions. Clubs commonly ask for 80% or better before you can enter gradings and events.",
      },
      {
        n: 2,
        title: "Scan QR to Check In",
        text: "Opens the camera. Allow camera access the first time. Hold steady until the code is recognised — you get a clear success or failure message on the spot.",
      },
      {
        n: 3,
        title: "If you are asked to pick a class",
        text: "When a centre runs more than one session at that hour, the app asks which class you are attending. Choose it and the check-in completes.",
      },
      {
        n: 4,
        title: "Recent attendance",
        text: "Every check-in the club has recorded, newest first, with a separate list of classes you missed.",
      },
    ],
    tips: [
      "Nothing recorded? Check with the front desk that you scanned the current poster — centres reprint them when details change.",
    ],
  },
  {
    key: "schedule",
    icon: "calendar",
    title: "Your timetable",
    intro:
      "Schedule shows the training week for the centres you belong to, so you can see at a glance which days you train.",
    shot: require("../assets/guide/schedule.png"),
    details: [
      {
        n: 1,
        title: "The week strip",
        text: "Tap any day to load its sessions. The highlighted day is the one you are viewing.",
      },
      {
        n: 2,
        title: "Session cards",
        text: "Start and end time, the training centre, your instructor and the grade the session is aimed at.",
      },
      {
        n: 3,
        title: "Rest days are normal",
        text: "A day with no sessions shows Rest Day rather than an empty screen — recovery is part of the programme.",
      },
      {
        n: 4,
        title: "Book a class",
        text: "The button in the corner opens booking, covered on the next page.",
      },
    ],
  },
  {
    key: "booking",
    icon: "add-circle",
    title: "Booking a class",
    intro:
      "Booking reserves your place in a session. Work down the screen: centre, then instructor, then month, then the session itself.",
    shot: require("../assets/guide/book-class.png"),
    details: [
      {
        n: 1,
        title: "Training centre and instructor",
        text: "Only the centres and instructors you are registered with appear. Changing either reloads the sessions below.",
      },
      {
        n: 2,
        title: "Month",
        text: "Switches which month you are booking into, so you can reserve ahead.",
      },
      {
        n: 3,
        title: "Available sessions",
        text: "Each row is a weekday slot with its time, centre and instructor. Select one, then pick the exact date it runs on.",
      },
      {
        n: 4,
        title: "My Bookings",
        text: "Everything you have reserved, with its status. The app blocks you from booking the same class twice on the same date.",
      },
    ],
    tips: [
      "Booked by mistake, or plans changed? Tell your academy — cancellations are handled by the club, not in the app.",
    ],
  },
  {
    key: "payments",
    icon: "wallet",
    title: "Fees and payments",
    intro:
      "Everything financial lives under Payments: what you owe now, months you want to settle early, and every receipt you have ever been issued.",
    shot: require("../assets/guide/payments.png"),
    details: [
      {
        n: 1,
        title: "Three tabs",
        text: "Pay is what is outstanding today. Advance Payment settles future months before they are invoiced. History is every past payment and receipt.",
      },
      {
        n: 2,
        title: "Who you are paying for",
        text: "If your family has more than one member at the academy, the name chips let you switch between them and pay each one's fees.",
      },
      {
        n: 3,
        title: "Pick your invoices",
        text: "Tick one or several — the running total updates as you go — then tap Pay to open the payment sheet.",
      },
      {
        n: 4,
        title: "How you pay",
        text: "Online card / FPX / e-wallet through the club's secure gateway, or Direct Bank-In, where you transfer manually and attach a photo of the slip from your gallery or camera.",
      },
      {
        n: 5,
        title: "Auto Pay and receipts",
        text: "Auto Pay settles fees each month automatically. Any receipt in History can be downloaded as an official PDF.",
      },
    ],
    note:
      "A Direct Bank-In payment is not settled the moment you upload the slip — your academy reviews it first, and the invoice stays pending until they approve it.",
  },
  {
    key: "notifications",
    icon: "notifications",
    title: "Notifications",
    intro:
      "Fee reminders, class changes and club announcements all arrive here, and as alerts on your phone.",
    shot: require("../assets/guide/notifications.png"),
    details: [
      {
        n: 1,
        title: "Unread first",
        text: "Unread messages are highlighted and counted on the home bell. Tap one to expand the full text — that also marks it read.",
      },
      {
        n: 2,
        title: "Mark all read",
        text: "The double-tick in the header clears the badge in one go.",
      },
      {
        n: 3,
        title: "Settings",
        text: "The sliders icon opens alert settings — sound, categories and quiet hours. That is the next page.",
      },
      {
        n: 4,
        title: "How often it checks",
        text: "While the app is open it looks for new messages every minute. Closed, your phone checks roughly every 15 minutes in the background.",
      },
    ],
  },
  {
    key: "alerts",
    icon: "options",
    title: "Alert settings",
    intro:
      "Control exactly how your phone behaves when the club sends something. Every option here is per-device, so your phone and your tablet can differ.",
    shot: require("../assets/guide/notification-settings.png"),
    details: [
      {
        n: 1,
        title: "Sound and vibration",
        text: "Turn the D-CLIX chime on or off, and whether alerts buzz. Turning both off still delivers the message silently to your tray.",
      },
      {
        n: 2,
        title: "Send a test notification",
        text: "Fires a sample alert immediately so you can hear the sound and confirm alerts are getting through before you rely on them.",
      },
      {
        n: 3,
        title: "Choose what alerts you",
        text: "Mute a whole category — fees, classes or announcements — and keep the rest. A muted category never alerts, though the messages still appear on the Notifications screen.",
      },
      {
        n: 4,
        title: "Quiet hours",
        text: "Silence alerts overnight between the hours you set. Nothing is lost: anything that arrives during the quiet window alerts you once it ends.",
      },
    ],
    tips: [
      "If alerts are blocked at the phone level, a warning appears at the top of this screen with a shortcut to your system settings.",
      "Using the app in a web browser? Sound only works after you have clicked the page once — every browser requires that before it will play audio.",
    ],
  },
  {
    key: "profile",
    icon: "person",
    title: "Profile and Virtual ID",
    intro:
      "Your membership card, your details, and the switches for how the app looks and who you are viewing.",
    shot: require("../assets/guide/profile.png"),
    details: [
      {
        n: 1,
        title: "Virtual ID",
        text: "Your personal member QR with your name, grade and registration number. Show it at the counter to identify yourself or claim member offers.",
      },
      {
        n: 2,
        title: "Switch student or club",
        text: "Parents with several children, and members of more than one academy, switch between them here. The whole app follows your selection.",
      },
      {
        n: 3,
        title: "Personal info",
        text: "Your contact details as the club holds them. Use the pencil at the top to update them and change your photo.",
      },
      {
        n: 4,
        title: "Appearance and sign-out",
        text: "Further down are the light and dark mode switch, this guide, and Logout.",
      },
    ],
    note:
      "The Virtual ID QR identifies you. It is not the check-in code — attendance is only recorded by scanning your centre's poster.",
  },
  {
    key: "chat",
    icon: "chatbubbles",
    title: "Chat and Help Desk",
    intro:
      "Chat Academy is the two-way channel to your club: their announcements to you, and your questions back to them.",
    shot: require("../assets/guide/chat.png"),
    details: [
      {
        n: 1,
        title: "Help Desk",
        text: "The pinned conversation at the top. Use it to start a new question with the club admin about anything — fees, schedules, membership.",
      },
      {
        n: 2,
        title: "Your conversations",
        text: "Every message the club has sent, newest first, as a thread you can open and read in full.",
      },
      {
        n: 3,
        title: "Replying",
        text: "Open a thread and send your answer. It reaches the academy's admin panel, and they follow up from there.",
      },
    ],
    tips: [
      "Replies land with the club's staff rather than an automated system, so expect a response in their office hours.",
    ],
  },
  {
    key: "everything",
    icon: "grid",
    title: "Finding everything else",
    intro:
      "More — the last tile in Quick Access — is the full catalogue of every screen in the app, grouped by what it is for.",
    shot: require("../assets/guide/more.png"),
    details: [
      {
        n: 1,
        title: "Training",
        text: "Your trainer, today's classes, the timetable, attendance, booking and the QR scanner.",
      },
      {
        n: 2,
        title: "Payments",
        text: "Fees due, payment history, advance payment, Auto Pay, purchase requests and your past purchases.",
      },
      {
        n: 3,
        title: "Progress and club",
        text: "Progress reports, belt and grading, plus events, competitions, offers, chat and the help desk.",
      },
      {
        n: 4,
        title: "Account",
        text: "Profile, student details, edit profile, notification settings and this guide.",
      },
    ],
    tips: [
      "Instructors get a different set of tabs — Collections, Reports and Settings in place of Schedule, Payments and Profile — but sign-in, QR check-in and notifications work exactly as described here.",
    ],
  },
];

// ── Screen ────────────────────────────────────────────────────────────────────
export default function UserGuide() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const [page, setPage] = useState(0);
  // Measured height of the pager area — each page's vertical ScrollView gets this exact
  // height, otherwise it has no bound inside the horizontal FlatList and can't scroll
  // (long steps were clipped behind the controls bar on small screens).
  const [pagerH, setPagerH] = useState(0);
  const listRef = useRef<FlatList<Step>>(null);

  // Explicit pixel size for the screenshot, not a percentage + aspectRatio: on
  // react-native-web the Image is a div with background-size:cover, and an aspectRatio
  // that the flex parent overrides leaves the box too tall — which crops the sides and
  // renders the screenshot hugely magnified. Fixed width and height keep the box exactly
  // the capture's 480x1039 shape, so `cover` has nothing to crop.
  const shotW = Math.min(200, Math.round(width * 0.55));
  const shotH = Math.round((shotW * 1039) / 480);

  const goto = (i: number) => {
    const clamped = Math.max(0, Math.min(STEPS.length - 1, i));
    listRef.current?.scrollToOffset({ offset: clamped * width, animated: true });
    setPage(clamped);
  };

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.hBtn} hitSlop={8} onPress={() => safeBack(router)} testID="guide-close">
            <Ionicons name="close" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.hTitle}>User Guide</Text>
          <TouchableOpacity hitSlop={8} onPress={() => safeBack(router)} testID="guide-skip">
            <Text style={styles.skip}>Skip</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <View style={{ flex: 1 }} onLayout={(e) => setPagerH(e.nativeEvent.layout.height)}>
        <FlatList
          ref={listRef}
          data={STEPS}
          keyExtractor={(s) => s.key}
          horizontal
          pagingEnabled
          style={{ flex: 1 }}
          showsHorizontalScrollIndicator={false}
          onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / width))}
          renderItem={({ item, index }) => (
            <ScrollView
              style={{ width, height: pagerH > 0 ? pagerH : undefined }}
              contentContainerStyle={styles.pageBody}
              showsVerticalScrollIndicator={false}
              nestedScrollEnabled
              testID={`guide-page-${item.key}`}
            >
              <View style={styles.stepBadge}>
                <Ionicons name={item.icon as any} size={14} color={colors.primary} />
                <Text style={styles.stepBadgeTxt}>
                  STEP {index + 1} OF {STEPS.length}
                </Text>
              </View>
              <Text style={styles.title}>{item.title}</Text>
              <Text style={styles.intro}>{item.intro}</Text>

              {/* Real screenshot of the current build, in a phone frame */}
              <View style={styles.frame}>
                <Image
                  source={item.shot}
                  style={{ width: shotW, height: shotH }}
                  resizeMode="cover"
                  accessibilityIgnoresInvertColors
                />
              </View>

              {item.details.map((d) => (
                <View key={d.n} style={styles.detailRow}>
                  <View style={styles.detailNum}>
                    <Text style={styles.detailNumTxt}>{d.n}</Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.detailTitle}>{d.title}</Text>
                    <Text style={styles.detailTxt}>{d.text}</Text>
                  </View>
                </View>
              ))}

              {!!item.note && (
                <View style={styles.note}>
                  <Ionicons name="alert-circle" size={18} color={colors.primary} />
                  <Text style={styles.noteTxt}>{item.note}</Text>
                </View>
              )}

              {item.tips?.map((t, i) => (
                <View key={i} style={styles.tipRow}>
                  <Ionicons name="bulb-outline" size={15} color={colors.textSecondary} />
                  <Text style={styles.tipTxt}>{t}</Text>
                </View>
              ))}
            </ScrollView>
          )}
        />
      </View>

      {/* Pager controls */}
      <View style={[styles.controls, { paddingBottom: Math.max(insets.bottom, 12) }]}>
        <TouchableOpacity
          style={[styles.navBtn, page === 0 && { opacity: 0.4 }]}
          disabled={page === 0}
          onPress={() => goto(page - 1)}
          testID="guide-back"
        >
          <Ionicons name="chevron-back" size={18} color={colors.textPrimary} />
        </TouchableOpacity>

        <View style={styles.dots}>
          {STEPS.map((s, i) => (
            <View key={s.key} style={[styles.dot, i === page && styles.dotActive]} />
          ))}
        </View>

        {page < STEPS.length - 1 ? (
          <TouchableOpacity onPress={() => goto(page + 1)} activeOpacity={0.9} testID="guide-next">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.nextBtn}>
              <Text style={styles.nextTxt}>Next</Text>
              <Ionicons name="chevron-forward" size={16} color="#fff" />
            </LinearGradient>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity onPress={() => safeBack(router)} activeOpacity={0.9} testID="guide-done">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.nextBtn}>
              <Text style={styles.nextTxt}>Got it</Text>
              <Ionicons name="checkmark" size={16} color="#fff" />
            </LinearGradient>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────
function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    hBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    hTitle: { ...font.h3, color: colors.textPrimary },
    skip: { color: colors.primary, fontWeight: "800", fontSize: 13, padding: 10 },

    pageBody: { paddingHorizontal: spacing.xl, paddingBottom: 36 },
    stepBadge: { flexDirection: "row", alignItems: "center", gap: 6, alignSelf: "flex-start", backgroundColor: colors.primary + "14", paddingHorizontal: 10, paddingVertical: 5, borderRadius: 10 },
    stepBadgeTxt: { color: colors.primary, fontSize: 10, fontWeight: "800", letterSpacing: 0.8 },
    title: { ...font.h2, color: colors.textPrimary, marginTop: 10 },
    intro: { fontSize: 13.5, color: colors.textSecondary, lineHeight: 19, marginTop: 4, marginBottom: 14 },

    // Sized by its child (see shotW/shotH) so the frame always matches the capture.
    frame: { alignSelf: "center", borderRadius: 18, borderWidth: 6, borderColor: mode === "dark" ? "#334155" : "#1F2937", overflow: "hidden", marginBottom: 18, ...shadow.card },

    detailRow: { flexDirection: "row", gap: 12, marginBottom: 14 },
    detailNum: { width: 24, height: 24, borderRadius: 12, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center", marginTop: 1 },
    detailNumTxt: { color: "#fff", fontSize: 12, fontWeight: "800" },
    detailTitle: { fontSize: 14, fontWeight: "800", color: colors.textPrimary, marginBottom: 2 },
    detailTxt: { fontSize: 13, color: colors.textSecondary, lineHeight: 19 },

    note: { flexDirection: "row", gap: 10, alignItems: "flex-start", backgroundColor: colors.primary + "12", borderRadius: radius.md, borderWidth: 1, borderColor: colors.primary + "40", padding: 12, marginTop: 2, marginBottom: 12 },
    noteTxt: { flex: 1, fontSize: 12.5, color: colors.textPrimary, lineHeight: 18 },

    tipRow: { flexDirection: "row", gap: 10, alignItems: "flex-start", marginBottom: 10 },
    tipTxt: { flex: 1, fontSize: 12.5, color: colors.textSecondary, lineHeight: 18, fontStyle: "italic" },

    controls: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingTop: 10, borderTopWidth: 1, borderTopColor: colors.border, backgroundColor: colors.surface },
    navBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    dots: { flexDirection: "row", gap: 5, alignItems: "center" },
    dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.border },
    dotActive: { width: 18, backgroundColor: colors.primary },
    nextBtn: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 20, paddingVertical: 12, borderRadius: radius.full },
    nextTxt: { color: "#fff", fontSize: 14, fontWeight: "800" },
  });
}
