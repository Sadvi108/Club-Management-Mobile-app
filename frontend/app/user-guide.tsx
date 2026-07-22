import { useMemo, useRef, useState, type ReactElement } from "react";
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, FlatList, useWindowDimensions,
} from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";

// ─────────────────────────────────────────────────────────────────────────────
// User Guide — step-by-step walkthrough reachable from the login screen.
// Each step shows a miniature PREVIEW of the real screen (built from the same
// theme tokens, no screenshots needed) with numbered callouts pinned on top,
// and the matching numbered explanations written out below it.
// No API calls here: the guide must work before signing in.
// ─────────────────────────────────────────────────────────────────────────────

type Step = {
  key: string;
  icon: string;
  title: string;
  intro: string;
  mock: (p: MockProps) => ReactElement;
  details: { n: number; title: string, text: string }[];
};

type MockProps = { colors: any; mode: "light" | "dark" };

// Small numbered badge pinned over the mock ------------------------------------
function Pin({ n, top, left, right, colors }: { n: number; top: number; left?: number; right?: number; colors: any }) {
  return (
    <View style={[pinStyles.pin, { top, left, right, backgroundColor: colors.primary }]}>
      <Text style={pinStyles.pinTxt}>{n}</Text>
    </View>
  );
}
const pinStyles = StyleSheet.create({
  pin: {
    position: "absolute", zIndex: 5, width: 22, height: 22, borderRadius: 11,
    alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: "#fff",
    shadowColor: "#000", shadowOpacity: 0.25, shadowRadius: 4, shadowOffset: { width: 0, height: 2 }, elevation: 4,
  },
  pinTxt: { color: "#fff", fontSize: 11, fontWeight: "800" },
});

// ── Mini screen mocks (stylized replicas of the real screens) ────────────────
function MockHome({ colors, mode }: MockProps) {
  const s = mockStyles(colors, mode);
  return (
    <View style={s.screen}>
      <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={s.header}>
        <View style={s.headerRow}>
          <View style={s.avatar} />
          <View style={{ flex: 1 }}>
            <Text style={s.hSub}>Hello,</Text>
            <Text style={s.hName}>DARSHAN M.</Text>
          </View>
          <View style={s.bell}>
            <Ionicons name="notifications-outline" size={12} color="#fff" />
            <View style={s.bellDot} />
          </View>
        </View>
        <View style={s.statRow}>
          {[["1", "Invoices"], ["9", "Grade"], ["80", "Due (RM)"]].map(([v, l]) => (
            <View key={l} style={{ flex: 1, alignItems: "center" }}>
              <Text style={s.statNum}>{v}</Text>
              <Text style={s.statLbl}>{l}</Text>
            </View>
          ))}
        </View>
      </LinearGradient>
      <View style={s.dueCard}>
        <View style={{ flex: 1 }}>
          <Text style={s.dueLbl}>FEES DUE</Text>
          <Text style={s.dueAmt}>RM 80</Text>
        </View>
        <View style={s.payBtn}><Text style={s.payBtnTxt}>Pay Now</Text></View>
      </View>
      <View style={s.gridRow}>
        {["checkmark-done-circle", "flash", "person-circle", "calendar"].map((ic) => (
          <View key={ic} style={s.gridCell}><Ionicons name={ic as any} size={14} color={colors.primary} /></View>
        ))}
      </View>
      <View style={s.banner}><Text style={s.bannerTxt}>Up To 60% Off — F0001</Text></View>
    </View>
  );
}

function MockPayments({ colors, mode }: MockProps) {
  const s = mockStyles(colors, mode);
  return (
    <View style={s.screen}>
      <Text style={s.pageTitle}>Fees & Payments</Text>
      <View style={s.segRow}>
        {["Pay", "Advance", "History"].map((t, i) => (
          <View key={t} style={[s.seg, i === 0 && { backgroundColor: colors.primary }]}>
            <Text style={[s.segTxt, i === 0 && { color: "#fff" }]}>{t}</Text>
          </View>
        ))}
      </View>
      <View style={s.invCard}>
        <Ionicons name="checkbox" size={14} color={colors.primary} />
        <View style={{ flex: 1, marginLeft: 6 }}>
          <Text style={s.invTitle}>Monthly fee July-2026</Text>
          <Text style={s.invSub}>Due RM 80.00</Text>
        </View>
        <Text style={s.invPdf}>PDF</Text>
      </View>
      <View style={s.methodRow}><Ionicons name="globe-outline" size={12} color={colors.primary} /><Text style={s.methodTxt}>Online (FPX / Card)</Text><Ionicons name="checkmark-circle" size={13} color={colors.success} /></View>
      <View style={s.methodRow}><Ionicons name="wallet-outline" size={12} color={colors.textMuted} /><Text style={s.methodTxt}>Boost</Text></View>
      <View style={s.methodRow}><Ionicons name="receipt-outline" size={12} color={colors.textMuted} /><Text style={s.methodTxt}>Direct Bank-In (slip)</Text></View>
      <View style={s.ctaBar}><Text style={s.ctaTxt}>Pay · RM 80.00</Text></View>
    </View>
  );
}

function MockQR({ colors, mode }: MockProps) {
  const s = mockStyles(colors, mode);
  return (
    <View style={[s.screen, { backgroundColor: "#0F172A" }]}>
      <Text style={[s.pageTitle, { color: "#fff" }]}>Scan to Check In</Text>
      <View style={s.qrFrame}>
        {/* corner marks */}
        {[{ top: -2, left: -2 }, { top: -2, right: -2 }, { bottom: -2, left: -2 }, { bottom: -2, right: -2 }].map((pos, i) => (
          <View key={i} style={[s.qrCorner, pos]} />
        ))}
        <Ionicons name="qr-code" size={44} color="rgba(255,255,255,0.5)" />
        <View style={s.scanLine} />
      </View>
      <Text style={s.qrHint}>Point the camera at your training-center QR</Text>
      <View style={s.qrResult}>
        <Ionicons name="checkmark-circle" size={13} color={colors.success} />
        <Text style={s.qrResultTxt}>Attendance marked · SMK KK2</Text>
      </View>
    </View>
  );
}

function MockSchedule({ colors, mode }: MockProps) {
  const s = mockStyles(colors, mode);
  return (
    <View style={s.screen}>
      <Text style={s.pageTitle}>Schedule</Text>
      <View style={s.weekRow}>
        {["S", "M", "T", "W", "T", "F", "S"].map((d, i) => (
          <View key={i} style={[s.day, i === 0 && { backgroundColor: colors.primary }]}>
            <Text style={[s.dayTxt, i === 0 && { color: "#fff" }]}>{d}</Text>
            {i === 0 && <View style={s.dayDot} />}
          </View>
        ))}
      </View>
      <View style={s.classCard}>
        <View style={[s.classBar, { backgroundColor: colors.primary }]} />
        <View style={{ flex: 1 }}>
          <Text style={s.invSub}>8:00 – 9:30 · Sunday</Text>
          <Text style={s.invTitle}>Normal training · SMK KK2</Text>
          <Text style={s.invSub}>with Master MSV</Text>
        </View>
      </View>
      <View style={[s.ctaBar, { alignSelf: "flex-end", paddingHorizontal: 12 }]}>
        <Ionicons name="add" size={12} color="#fff" />
        <Text style={s.ctaTxt}>Book a Class</Text>
      </View>
    </View>
  );
}

function MockChat({ colors, mode }: MockProps) {
  const s = mockStyles(colors, mode);
  return (
    <View style={s.screen}>
      <Text style={s.pageTitle}>Chat Academy</Text>
      <View style={s.bubbleTheirs}>
        <Text style={s.bubbleTag}>REMINDER</Text>
        <Text style={s.bubbleTxt}>Please settle your July fees</Text>
      </View>
      <View style={s.bubbleMine}><Text style={[s.bubbleTxt, { color: "#fff" }]}>Noted, paying this week</Text></View>
      <View style={s.notifCard}>
        <Ionicons name="notifications" size={12} color={colors.primary} />
        <Text style={s.notifTxt}>New notification → alert on your phone</Text>
      </View>
      <View style={s.composer}>
        <Text style={s.composerTxt}>Type a message…</Text>
        <View style={s.sendBtn}><Ionicons name="send" size={10} color="#fff" /></View>
      </View>
    </View>
  );
}

function MockProfile({ colors, mode }: MockProps) {
  const s = mockStyles(colors, mode);
  return (
    <View style={s.screen}>
      <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[s.header, { alignItems: "center", paddingVertical: 12 }]}>
        <View style={[s.avatar, { width: 30, height: 30, borderRadius: 15 }]} />
        <Text style={[s.hName, { marginTop: 4 }]}>DARSHAN M.</Text>
        <View style={s.idCard}>
          <Ionicons name="qr-code" size={26} color={colors.textPrimary} />
          <Text style={s.idTxt}>Virtual ID</Text>
        </View>
      </LinearGradient>
      {[
        ["qr-code-outline", "Scan QR to Check In"],
        ["headset-outline", "Help Desk"],
        ["bag-handle-outline", "My Purchases"],
      ].map(([ic, l]) => (
        <View key={l} style={s.rowItem}>
          <Ionicons name={ic as any} size={13} color={colors.primary} />
          <Text style={s.rowTxt}>{l}</Text>
          <Ionicons name="chevron-forward" size={11} color={colors.textMuted} />
        </View>
      ))}
    </View>
  );
}

// ── Steps content ─────────────────────────────────────────────────────────────
const STEPS: Step[] = [
  {
    key: "home",
    icon: "home",
    title: "Your Home Dashboard",
    intro: "Everything important the moment you open the app — live from your academy.",
    mock: (p) => (
      <View>
        <MockHome {...p} />
        <Pin n={1} top={64} left={10} colors={p.colors} />
        <Pin n={2} top={104} right={12} colors={p.colors} />
        <Pin n={3} top={158} left={10} colors={p.colors} />
        <Pin n={4} top={18} right={10} colors={p.colors} />
      </View>
    ),
    details: [
      { n: 1, title: "Live stats", text: "Pending invoices, your current belt grade and total dues — refreshed from the club system every time you open Home." },
      { n: 2, title: "Fees due card", text: "One tap on Pay Now takes you straight to the payment screen with your outstanding invoices ready." },
      { n: 3, title: "Quick Access grid", text: "Shortcuts to every feature. The More tile opens the full catalog: training, payments, progress, club and account." },
      { n: 4, title: "Notification bell", text: "The badge shows unread club notifications. New ones also pop up as alerts on your phone." },
    ],
  },
  {
    key: "payments",
    icon: "wallet",
    title: "Pay Fees In-App",
    intro: "Settle dues online, pay months in advance, and keep every receipt.",
    mock: (p) => (
      <View>
        <MockPayments {...p} />
        <Pin n={1} top={34} left={10} colors={p.colors} />
        <Pin n={2} top={64} right={12} colors={p.colors} />
        <Pin n={3} top={118} left={10} colors={p.colors} />
        <Pin n={4} top={62} left={10} colors={p.colors} />
      </View>
    ),
    details: [
      { n: 1, title: "Three tabs", text: "Pay = current dues. Advance Payment = settle future months early (once your academy issues them). History = every past payment." },
      { n: 2, title: "Receipt PDFs", text: "Download an official PDF for any invoice or receipt straight to your phone." },
      { n: 3, title: "Payment methods", text: "Online (FPX / card / e-wallets via the secure Billplz gateway), Boost, or Direct Bank-In where you upload your transfer slip photo." },
      { n: 4, title: "Select & pay", text: "Tick one or many invoices — the total updates live and one tap opens the payment gateway." },
    ],
  },
  {
    key: "qr",
    icon: "qr-code",
    title: "QR Check-In",
    intro: "Attendance in two seconds — scan the code displayed at your training center.",
    mock: (p) => (
      <View>
        <MockQR {...p} />
        <Pin n={1} top={70} right={30} colors={p.colors} />
        <Pin n={2} top={196} left={10} colors={p.colors} />
      </View>
    ),
    details: [
      { n: 1, title: "Scan the center QR", text: "Open Scan from the middle tab button, point at the QR at your center — attendance is marked instantly against your account." },
      { n: 2, title: "Instant confirmation", text: "A clear success or failure message tells you on the spot whether check-in worked." },
    ],
  },
  {
    key: "schedule",
    icon: "calendar",
    title: "Schedule & Class Booking",
    intro: "See your training week and book extra classes with your instructor.",
    mock: (p) => (
      <View>
        <MockSchedule {...p} />
        <Pin n={1} top={36} left={10} colors={p.colors} />
        <Pin n={2} top={84} left={10} colors={p.colors} />
        <Pin n={3} top={148} right={12} colors={p.colors} />
      </View>
    ),
    details: [
      { n: 1, title: "Week strip", text: "Dots mark training days. Tap any day to see its classes." },
      { n: 2, title: "Class details", text: "Time, center and instructor for each session — with a Check In shortcut on today's class." },
      { n: 3, title: "Book a Class", text: "Pick a center, instructor and time slot, confirm — your booking is registered with the academy." },
    ],
  },
  {
    key: "chat",
    icon: "chatbubbles",
    title: "Chat, Help Desk & Alerts",
    intro: "Talk to your club and never miss an announcement.",
    mock: (p) => (
      <View>
        <MockChat {...p} />
        <Pin n={1} top={36} left={10} colors={p.colors} />
        <Pin n={2} top={80} right={12} colors={p.colors} />
        <Pin n={3} top={116} left={10} colors={p.colors} />
      </View>
    ),
    details: [
      { n: 1, title: "Club messages as chats", text: "Reminders, class activities and announcements arrive as conversations in Chat Academy (home → Chat Academy tile)." },
      { n: 2, title: "Reply & Help Desk", text: "Answer any message, or start a new conversation with the club admin through the pinned Help Desk thread." },
      { n: 3, title: "Device alerts", text: "New notifications raise a real alert on your phone — even with the app in the background (allow notifications on first launch)." },
    ],
  },
  {
    key: "profile",
    icon: "person",
    title: "Profile & Virtual ID",
    intro: "Your membership card, personal details and settings in one place.",
    mock: (p) => (
      <View>
        <MockProfile {...p} />
        <Pin n={1} top={52} right={30} colors={p.colors} />
        <Pin n={2} top={128} left={10} colors={p.colors} />
        <Pin n={3} top={162} left={10} colors={p.colors} />
      </View>
    ),
    details: [
      { n: 1, title: "Virtual member ID", text: "Your personal QR — show it at the counter to identify yourself or redeem app-user offers." },
      { n: 2, title: "Help Desk & purchases", text: "Contact the club, review your purchase requests, and check student details." },
      { n: 3, title: "Edit profile & dark mode", text: "Update your details and photo, switch between light and dark theme, or log out." },
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
          >
            <View style={styles.stepBadge}>
              <Ionicons name={item.icon as any} size={14} color={colors.primary} />
              <Text style={styles.stepBadgeTxt}>STEP {index + 1} OF {STEPS.length}</Text>
            </View>
            <Text style={styles.title}>{item.title}</Text>
            <Text style={styles.intro}>{item.intro}</Text>

            {/* Preview mock in a phone frame with callout pins */}
            <View style={styles.frame}>{item.mock({ colors, mode })}</View>

            {item.details.map((d) => (
              <View key={d.n} style={styles.detailRow}>
                <View style={styles.detailNum}><Text style={styles.detailNumTxt}>{d.n}</Text></View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.detailTitle}>{d.title}</Text>
                  <Text style={styles.detailTxt}>{d.text}</Text>
                </View>
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
          {STEPS.map((_, i) => (
            <View key={i} style={[styles.dot, i === page && styles.dotActive]} />
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

    frame: { alignSelf: "center", width: "78%", borderRadius: 18, borderWidth: 6, borderColor: mode === "dark" ? "#334155" : "#1F2937", overflow: "hidden", marginBottom: 18, ...shadow.card },

    detailRow: { flexDirection: "row", gap: 12, marginBottom: 14 },
    detailNum: { width: 24, height: 24, borderRadius: 12, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center", marginTop: 1 },
    detailNumTxt: { color: "#fff", fontSize: 12, fontWeight: "800" },
    detailTitle: { fontSize: 14, fontWeight: "800", color: colors.textPrimary },
    detailTxt: { fontSize: 12.5, color: colors.textSecondary, lineHeight: 18, marginTop: 2 },

    controls: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingTop: 10, backgroundColor: colors.background, borderTopWidth: 1, borderTopColor: colors.border },
    navBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    dots: { flexDirection: "row", gap: 6 },
    dot: { width: 7, height: 7, borderRadius: 4, backgroundColor: colors.border },
    dotActive: { backgroundColor: colors.primary, width: 18 },
    nextBtn: { flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 22, paddingVertical: 12, borderRadius: radius.md },
    nextTxt: { color: "#fff", fontWeight: "800", fontSize: 14 },
  });
}

// Shared styles for the miniature screen mocks
function mockStyles(colors: any, mode: "light" | "dark") {
  return StyleSheet.create({
    screen: { backgroundColor: colors.background, paddingBottom: 12 },
    header: { padding: 10, borderBottomLeftRadius: 12, borderBottomRightRadius: 12 },
    headerRow: { flexDirection: "row", alignItems: "center", gap: 8 },
    avatar: { width: 24, height: 24, borderRadius: 12, backgroundColor: "rgba(255,255,255,0.35)" },
    hSub: { color: "rgba(255,255,255,0.85)", fontSize: 8 },
    hName: { color: "#fff", fontSize: 11, fontWeight: "800" },
    bell: { width: 22, height: 22, borderRadius: 11, backgroundColor: "rgba(255,255,255,0.25)", alignItems: "center", justifyContent: "center" },
    bellDot: { position: "absolute", top: 2, right: 2, width: 6, height: 6, borderRadius: 3, backgroundColor: "#EF4444" },
    statRow: { flexDirection: "row", marginTop: 8, backgroundColor: "rgba(255,255,255,0.18)", borderRadius: 8, paddingVertical: 6 },
    statNum: { color: "#fff", fontSize: 11, fontWeight: "800" },
    statLbl: { color: "rgba(255,255,255,0.85)", fontSize: 7 },

    dueCard: { flexDirection: "row", alignItems: "center", margin: 8, marginBottom: 0, padding: 8, borderRadius: 10, backgroundColor: mode === "dark" ? "#241416" : "#FDECEC" },
    dueLbl: { fontSize: 7, fontWeight: "800", color: mode === "dark" ? "#FF8A93" : "#B10E18" },
    dueAmt: { fontSize: 13, fontWeight: "800", color: mode === "dark" ? "#FFB3B8" : "#8F0B13" },
    payBtn: { backgroundColor: colors.primary, borderRadius: 6, paddingHorizontal: 8, paddingVertical: 5 },
    payBtnTxt: { color: "#fff", fontSize: 8, fontWeight: "800" },

    gridRow: { flexDirection: "row", gap: 6, paddingHorizontal: 8, marginTop: 8 },
    gridCell: { flex: 1, aspectRatio: 1.15, borderRadius: 8, backgroundColor: colors.surface, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: colors.border },
    banner: { margin: 8, marginBottom: 0, height: 34, borderRadius: 8, backgroundColor: "#1F2937", alignItems: "center", justifyContent: "center" },
    bannerTxt: { color: "#FF8A93", fontSize: 8, fontWeight: "800" },

    pageTitle: { fontSize: 12, fontWeight: "800", color: colors.textPrimary, margin: 10, marginBottom: 6 },
    segRow: { flexDirection: "row", gap: 4, paddingHorizontal: 10 },
    seg: { flex: 1, borderRadius: 6, paddingVertical: 5, backgroundColor: colors.surfaceAlt, alignItems: "center" },
    segTxt: { fontSize: 8, fontWeight: "800", color: colors.textSecondary },
    invCard: { flexDirection: "row", alignItems: "center", margin: 10, marginBottom: 6, padding: 8, borderRadius: 8, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
    invTitle: { fontSize: 9, fontWeight: "800", color: colors.textPrimary },
    invSub: { fontSize: 8, color: colors.textSecondary },
    invPdf: { fontSize: 8, fontWeight: "800", color: colors.primary },
    methodRow: { flexDirection: "row", alignItems: "center", gap: 6, marginHorizontal: 10, marginBottom: 4, padding: 6, borderRadius: 6, backgroundColor: colors.surfaceAlt },
    methodTxt: { flex: 1, fontSize: 8.5, fontWeight: "700", color: colors.textPrimary },
    ctaBar: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 4, margin: 10, marginTop: 6, borderRadius: 8, backgroundColor: colors.primary, paddingVertical: 7 },
    ctaTxt: { color: "#fff", fontSize: 9, fontWeight: "800" },

    qrFrame: { alignSelf: "center", width: 110, height: 110, alignItems: "center", justifyContent: "center", marginTop: 12 },
    qrCorner: { position: "absolute", width: 18, height: 18, borderColor: "#F5333F", borderTopWidth: 3, borderLeftWidth: 3, borderRadius: 2 },
    scanLine: { position: "absolute", left: 6, right: 6, top: "52%", height: 2, backgroundColor: "#F5333F", opacity: 0.9 },
    qrHint: { color: "rgba(255,255,255,0.75)", fontSize: 8.5, textAlign: "center", marginTop: 12, paddingHorizontal: 16 },
    qrResult: { flexDirection: "row", alignItems: "center", gap: 5, alignSelf: "center", marginTop: 10, backgroundColor: "rgba(255,255,255,0.12)", borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 },
    qrResultTxt: { color: "#fff", fontSize: 8.5, fontWeight: "700" },

    weekRow: { flexDirection: "row", gap: 4, paddingHorizontal: 10 },
    day: { flex: 1, borderRadius: 6, paddingVertical: 6, backgroundColor: colors.surfaceAlt, alignItems: "center" },
    dayTxt: { fontSize: 8, fontWeight: "800", color: colors.textSecondary },
    dayDot: { width: 3, height: 3, borderRadius: 2, backgroundColor: "#fff", marginTop: 2 },
    classCard: { flexDirection: "row", gap: 8, alignItems: "center", margin: 10, padding: 8, borderRadius: 8, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
    classBar: { width: 3, height: 34, borderRadius: 2 },

    bubbleTheirs: { alignSelf: "flex-start", maxWidth: "78%", marginHorizontal: 10, marginBottom: 6, padding: 7, borderRadius: 9, borderTopLeftRadius: 3, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
    bubbleMine: { alignSelf: "flex-end", maxWidth: "78%", marginHorizontal: 10, marginBottom: 6, padding: 7, borderRadius: 9, borderBottomRightRadius: 3, backgroundColor: colors.primary },
    bubbleTag: { fontSize: 6.5, fontWeight: "800", color: colors.primary, letterSpacing: 0.4, marginBottom: 2 },
    bubbleTxt: { fontSize: 8.5, color: colors.textPrimary, lineHeight: 12 },
    notifCard: { flexDirection: "row", alignItems: "center", gap: 5, marginHorizontal: 10, marginBottom: 6, padding: 6, borderRadius: 7, backgroundColor: colors.primary + "14" },
    notifTxt: { fontSize: 8, fontWeight: "700", color: colors.textPrimary, flex: 1 },
    composer: { flexDirection: "row", alignItems: "center", gap: 6, marginHorizontal: 10, padding: 6, borderRadius: 9, backgroundColor: colors.surfaceAlt },
    composerTxt: { flex: 1, fontSize: 8.5, color: colors.textMuted },
    sendBtn: { width: 18, height: 18, borderRadius: 9, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },

    idCard: { marginTop: 8, backgroundColor: "#fff", borderRadius: 8, paddingHorizontal: 14, paddingVertical: 6, alignItems: "center" },
    idTxt: { fontSize: 7, fontWeight: "800", color: "#1F2937", marginTop: 2 },
    rowItem: { flexDirection: "row", alignItems: "center", gap: 8, marginHorizontal: 10, marginTop: 6, padding: 8, borderRadius: 8, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
    rowTxt: { flex: 1, fontSize: 9, fontWeight: "700", color: colors.textPrimary },
  });
}
