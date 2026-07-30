import { useEffect, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
} from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { notify, safeBack } from "../src/ui/dialogs";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { TrainingSlot } from "../src/api/types";

const DOW = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const pad = (n: number) => (n < 10 ? `0${n}` : `${n}`);
const startTimeOf = (name?: string) => {
  const m = /(\d{1,2}:\d{2})/.exec(name || "");
  return m ? m[1] : "";
};
const isoDate = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

/**
 * Every date in the chosen month that falls on the slot's weekday, today onwards.
 *
 * The timetable the API returns is weekly and month-independent, and BookNow accepts any date
 * you send it — including one whose weekday doesn't match the slot (verified: a Friday slot
 * booked on a Tuesday returned 200). So the app picks the candidate dates and the student
 * chooses one, instead of a date being computed behind their back.
 */
function datesForDow(dowName: string, month: number, year: number): Date[] {
  const target = DOW.findIndex((d) => d.toLowerCase() === (dowName || "").toLowerCase());
  if (target < 0) return [];
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const out: Date[] = [];
  const d = new Date(year, month - 1, 1);
  while (d.getMonth() === month - 1) {
    if (d.getDay() === target && d.getTime() >= today.getTime()) out.push(new Date(d));
    d.setDate(d.getDate() + 1);
  }
  return out;
}

export default function BookClass() {
  const router = useRouter();
  const { user, token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const insets = useSafeAreaInsets();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const studentId = user?.id ?? 0;

  // Only fire authed calls once the session token exists (avoids a 401 → logout race on a cold
  // open), and refetch when the token is restored from storage.
  const centers = useApi(() => (token ? api.trainingCenters() : Promise.resolve([])), [token]);
  const instructors = useApi(() => (token ? api.instructors() : Promise.resolve([])), [token]);
  const info = useApi(() => (token ? api.myInfo() : Promise.resolve(null)), [token]);

  const [tCenterId, setTCenterId] = useState(0);
  const [instructorId, setInstructorId] = useState(0);
  const [monthOffset, setMonthOffset] = useState(0); // 0 = this month, 1 = next month
  const [selectedSlot, setSelectedSlot] = useState<number | null>(null);
  const [selectedDate, setSelectedDate] = useState<string | null>(null); // yyyy-mm-dd
  const [booking, setBooking] = useState(false);

  const base = new Date();
  const target = new Date(base.getFullYear(), base.getMonth() + monthOffset, 1);
  const month = target.getMonth() + 1;
  const year = target.getFullYear();
  const monthLabel = target.toLocaleDateString("en-GB", { month: "long", year: "numeric" });

  // Default the center to the student's own training center, instructor to the first available.
  // Wait for MyInfo to resolve before choosing so we can match the student's center (else we'd
  // lock onto the first center in the list before the match is known).
  useEffect(() => {
    if (tCenterId || info.loading || !centers.data?.length) return;
    const mine = centers.data.find(
      (c) => c.text === info.data?.tCenterName || c.value === info.data?.tCenterName
    );
    setTCenterId(mine?.id ?? centers.data[0].id);
  }, [centers.data, info.data, info.loading]);
  // Default to the student's own instructor when the API tells us who that is — picking the
  // first name in the list lands on an instructor who often teaches nothing at this centre.
  useEffect(() => {
    if (instructorId || info.loading || !instructors.data?.length) return;
    const mine = instructors.data.find(
      (i) => i.id === info.data?.instructorId || i.text === info.data?.instructorName
    );
    setInstructorId(mine?.id ?? instructors.data[0].id);
  }, [instructors.data, info.data, info.loading]);

  const slots = useApi(
    () =>
      token && tCenterId && instructorId
        ? api.trainingSlots(month, year, tCenterId, instructorId)
        : Promise.resolve([] as TrainingSlot[]),
    [token, tCenterId, instructorId, month, year]
  );
  const bookings = useApi(
    () => (token ? api.getBookings(studentId) : Promise.resolve([])),
    [token, studentId]
  );

  // The student's package — BookNow takes the packageType from here rather than a guess.
  const pkg = useApi(
    () => (token && studentId ? api.packageInfo(studentId) : Promise.resolve(null)),
    [token, studentId]
  );

  // Drop the selection whenever the slot list changes.
  useEffect(() => {
    setSelectedSlot(null);
    setSelectedDate(null);
  }, [tCenterId, instructorId, month, year]);

  const slotList = slots.data ?? [];
  const chosen = slotList.find((s) => s.id === selectedSlot) || null;
  const centerName = (centers.data ?? []).find((c) => c.id === tCenterId)?.text || "";
  const instructorName = (instructors.data ?? []).find((i) => i.id === instructorId)?.text || "";

  // Candidate dates for the chosen slot, and the first one preselected.
  const dateOptions = useMemo(
    () => (chosen ? datesForDow(chosen.dayOfWeek, month, year) : []),
    [chosen, month, year]
  );
  // Preselect the first date the student hasn't already booked, so the default choice is
  // actionable rather than immediately warning about a duplicate.
  useEffect(() => {
    if (!chosen) return;
    const taken = new Set(
      (bookings.data ?? [])
        .filter((b) => b.timeId === chosen.id)
        .map((b) => (b.trainingDate || "").slice(0, 10))
    );
    const free = dateOptions.find((d) => !taken.has(isoDate(d)));
    setSelectedDate((prev) =>
      prev && dateOptions.some((d) => isoDate(d) === prev)
        ? prev
        : free
          ? isoDate(free)
          : dateOptions[0]
            ? isoDate(dateOptions[0])
            : null
    );
  }, [chosen, dateOptions, bookings.data]);

  // Upcoming bookings first (soonest first), then past ones (most recent first).
  const myBookings = useMemo(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return (bookings.data ?? [])
      .map((b) => ({ b, t: new Date(b.trainingDate).getTime() }))
      .map((x) => ({ ...x, past: !isNaN(x.t) && x.t < today.getTime() }))
      .sort((a, z) => (a.past === z.past ? (a.past ? z.t - a.t : a.t - z.t) : a.past ? 1 : -1));
  }, [bookings.data]);

  // The API happily creates a second identical booking, so check here.
  const alreadyBooked = useMemo(() => {
    if (!chosen || !selectedDate) return false;
    return (bookings.data ?? []).some(
      (b) => b.timeId === chosen.id && (b.trainingDate || "").slice(0, 10) === selectedDate
    );
  }, [bookings.data, chosen, selectedDate]);

  async function confirmBooking() {
    if (!chosen || !studentId || booking) return;
    if (!selectedDate) {
      notify("Pick a date", "Choose which date you want to attend this class.");
      return;
    }
    if (alreadyBooked) {
      notify("Already booked", "You've already booked this class on that date. Pick another date.");
      return;
    }
    setBooking(true);
    try {
      const start = startTimeOf(chosen.name) || "00:00";
      await api.bookNow({
        id: 0,
        tCenterId,
        instructorId,
        studentId,
        packageType: pkg.data?.packageType || null,
        sessionId: 0,
        remarks: "Booked via app",
        timeSlots: [
          {
            bookingId: 0,
            timeId: chosen.id,
            trainingDate: `${selectedDate}T${start}:00`,
            status: "",
            title: "",
            name: chosen.name,
            centerName: chosen.centerName,
            instructorName: chosen.instructorName,
          },
        ],
      });
      const when = new Date(`${selectedDate}T00:00:00`);
      setSelectedSlot(null);
      setSelectedDate(null);
      bookings.reload();
      notify(
        "Class booked",
        `${chosen.name}\n${when.toLocaleDateString("en-GB", { weekday: "long", day: "2-digit", month: "short" })} · ${chosen.centerName}`
      );
    } catch (e: any) {
      notify("Booking failed", e?.message || "Please try again.");
    } finally {
      setBooking(false);
    }
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.iconBtn} onPress={() => safeBack(router)} testID="book-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Book a Class</Text>
          <View style={styles.iconBtn} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 150 + insets.bottom }} showsVerticalScrollIndicator={false}>
        {/* Center */}
        <Text style={styles.label}>Training Center</Text>
        {centers.loading ? (
          <ActivityIndicator color={colors.primary} style={{ marginVertical: 12 }} />
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            {(centers.data ?? []).map((c) => {
              const on = c.id === tCenterId;
              return (
                <TouchableOpacity key={c.id} onPress={() => setTCenterId(c.id)} style={[styles.chip, on && styles.chipOn]} testID={`book-center-${c.id}`}>
                  <Text style={[styles.chipTxt, on && styles.chipTxtOn]} numberOfLines={1}>{c.text || c.value}</Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        )}

        {/* Instructor */}
        <Text style={styles.label}>Instructor</Text>
        {instructors.loading ? (
          <ActivityIndicator color={colors.primary} style={{ marginVertical: 12 }} />
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            {(instructors.data ?? []).map((c) => {
              const on = c.id === instructorId;
              return (
                <TouchableOpacity key={c.id} onPress={() => setInstructorId(c.id)} style={[styles.chip, on && styles.chipOn]} testID={`book-instr-${c.id}`}>
                  <Text style={[styles.chipTxt, on && styles.chipTxtOn]} numberOfLines={1}>{c.text || c.value}</Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        )}

        {/* Month */}
        <Text style={styles.label}>Month</Text>
        <View style={styles.monthRow}>
          {[0, 1].map((off) => {
            const d = new Date(base.getFullYear(), base.getMonth() + off, 1);
            const on = off === monthOffset;
            return (
              <TouchableOpacity key={off} onPress={() => setMonthOffset(off)} style={[styles.monthPill, on && styles.chipOn]} testID={`book-month-${off}`}>
                <Text style={[styles.chipTxt, on && styles.chipTxtOn]}>{d.toLocaleDateString("en-GB", { month: "long" })}</Text>
              </TouchableOpacity>
            );
          })}
        </View>

        {/* Slots */}
        <Text style={styles.section}>Available Sessions · {monthLabel}</Text>
        {slots.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 20 }} />}
        {slots.error && <Text style={styles.errTxt}>{slots.error}</Text>}
        {!slots.loading && slotList.length === 0 && (
          <View style={styles.emptyCard}>
            <Ionicons name="calendar-outline" size={40} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>No sessions here</Text>
            <Text style={styles.emptySub}>
              {instructorName ? `${instructorName} doesn't teach at ` : "No timetable at "}
              {centerName || "this centre"}. Pick another instructor or centre above.
            </Text>
          </View>
        )}
        {slotList.map((s) => {
          const on = s.id === selectedSlot;
          return (
            <TouchableOpacity
              key={s.id}
              onPress={() => setSelectedSlot(s.id)}
              activeOpacity={0.85}
              style={[styles.slotCard, on && styles.slotCardOn]}
              testID={`book-slot-${s.id}`}
            >
              <View style={[styles.slotDow, on && { backgroundColor: colors.primary }]}>
                <Text style={[styles.slotDowTxt, on && { color: "#fff" }]}>{(s.dayOfWeek || "").slice(0, 3).toUpperCase()}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.slotTitle} numberOfLines={2}>{s.name}</Text>
                <Text style={styles.slotMeta} numberOfLines={1}>
                  {s.centerName} · {s.instructorName}
                  {s.classLimit > 0 ? ` · max ${s.classLimit}` : ""}
                </Text>
              </View>
              <Ionicons name={on ? "radio-button-on" : "radio-button-off"} size={22} color={on ? colors.primary : colors.textMuted} />
            </TouchableOpacity>
          );
        })}

        {/* Date — the API takes any date, so the student picks which one */}
        {chosen && (
          <>
            <Text style={styles.section}>Pick a date</Text>
            {dateOptions.length === 0 ? (
              <Text style={styles.emptySub}>
                No {chosen.dayOfWeek} left in {monthLabel}. Choose next month above.
              </Text>
            ) : (
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
                {dateOptions.map((d) => {
                  const key = isoDate(d);
                  const on = key === selectedDate;
                  const taken = (bookings.data ?? []).some(
                    (b) => b.timeId === chosen.id && (b.trainingDate || "").slice(0, 10) === key
                  );
                  return (
                    <TouchableOpacity
                      key={key}
                      onPress={() => setSelectedDate(key)}
                      style={[styles.dateChip, on && styles.chipOn, taken && { opacity: 0.55 }]}
                      testID={`book-date-${key}`}
                    >
                      <Text style={[styles.dateDay, on && styles.chipTxtOn]}>{d.getDate()}</Text>
                      <Text style={[styles.dateMon, on && styles.chipTxtOn]}>
                        {taken ? "booked" : d.toLocaleDateString("en-GB", { month: "short" })}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            )}
            {alreadyBooked && (
              <Text style={styles.warnTxt}>You already have this class booked on that date.</Text>
            )}
          </>
        )}

        {/* My bookings */}
        <Text style={styles.section}>My Bookings</Text>
        {bookings.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 16 }} />}
        {!bookings.loading && (bookings.data?.length ?? 0) === 0 && (
          <Text style={styles.emptySub}>No bookings yet.</Text>
        )}
        {/* Upcoming first, then past — NextBookings returns [] even when a future booking
            exists, so the split is done here from the full list. */}
        {myBookings.map(({ b, past }, i) => (
          <View key={`${b.bookingId}-${i}`} style={[styles.bookCard, past && { opacity: 0.55 }]}>
            <View style={styles.bookIcon}>
              <Ionicons name={past ? "time-outline" : "checkmark-done"} size={18} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.slotTitle} numberOfLines={1}>{b.title || "Class"}</Text>
              <Text style={styles.slotMeta} numberOfLines={1}>
                {new Date(b.trainingDate).toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short" })} · {b.centerName}
                {past ? " · past" : ""}
              </Text>
            </View>
            <Text style={[styles.statusTag, { color: /confirm|approv/i.test(b.status) ? colors.success : colors.warning }]}>{b.status || "Pending"}</Text>
          </View>
        ))}
      </ScrollView>

      {/* Confirm */}
      <View style={[styles.footer, { backgroundColor: colors.background, borderTopColor: colors.border, paddingBottom: Math.max(insets.bottom + 12, 28) }]}>
        <TouchableOpacity
          onPress={confirmBooking}
          disabled={!chosen || !selectedDate || alreadyBooked || booking}
          activeOpacity={0.9}
          testID="book-confirm"
        >
          <LinearGradient
            colors={colors.gradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
            style={[
              styles.confirmBtn,
              shadow.strong,
              (!chosen || !selectedDate || alreadyBooked || booking) && { opacity: 0.5 },
            ]}
          >
            {booking ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <>
                <Ionicons name="add-circle" size={20} color="#fff" />
                <Text style={styles.confirmTxt}>
                  {!chosen
                    ? "Select a session"
                    : alreadyBooked
                      ? "Already booked"
                      : !selectedDate
                        ? "Pick a date"
                        : `Confirm · ${new Date(`${selectedDate}T00:00:00`).toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short" })}`}
                </Text>
              </>
            )}
          </LinearGradient>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingVertical: 10 },
    iconBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    label: { ...font.tiny, color: colors.textSecondary, marginTop: 18, marginBottom: 10, textTransform: "uppercase" },
    chipRow: { gap: 8, paddingRight: spacing.xl },
    chip: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: radius.full, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, maxWidth: 200 },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipTxt: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    chipTxtOn: { color: "#fff" },

    monthRow: { flexDirection: "row", gap: 10 },
    monthPill: { flex: 1, alignItems: "center", paddingVertical: 12, borderRadius: radius.md, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },

    section: { ...font.h4, color: colors.textPrimary, marginTop: 24, marginBottom: 12 },
    errTxt: { color: colors.danger, fontSize: 13, marginBottom: 10 },
    emptyCard: { alignItems: "center", paddingVertical: 40 },
    emptyTxt: { ...font.h4, color: colors.textPrimary, marginTop: 12 },
    emptySub: { fontSize: 13, color: colors.textSecondary, marginTop: 6 },

    slotCard: { flexDirection: "row", alignItems: "center", gap: 12, backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 10, borderWidth: 1, borderColor: colors.border, ...shadow.soft },
    slotCardOn: { borderColor: colors.primary, borderWidth: 2 },
    slotDow: { width: 44, height: 44, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    slotDowTxt: { fontSize: 12, fontWeight: "800", color: colors.primary },
    slotTitle: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    slotMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 3 },
    fullTag: { fontSize: 12, fontWeight: "700", color: colors.danger },
    warnTxt: { fontSize: 12, color: colors.warning, marginTop: 10, fontWeight: "600" },
    dateChip: {
      minWidth: 62, alignItems: "center", paddingVertical: 10, paddingHorizontal: 12,
      borderRadius: radius.md, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border,
    },
    dateDay: { fontSize: 17, fontWeight: "800", color: colors.textPrimary },
    dateMon: { fontSize: 11, fontWeight: "600", color: colors.textSecondary, marginTop: 2 },

    bookCard: { flexDirection: "row", alignItems: "center", gap: 12, backgroundColor: colors.surface, borderRadius: radius.md, padding: 13, marginBottom: 9, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border, ...shadow.soft },
    bookIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    statusTag: { fontSize: 12, fontWeight: "700" },

    footer: { position: "absolute", left: 0, right: 0, bottom: 0, padding: spacing.xl, paddingBottom: 28, borderTopWidth: 1 },
    confirmBtn: { flexDirection: "row", gap: 8, alignItems: "center", justifyContent: "center", paddingVertical: 16, borderRadius: radius.full },
    confirmTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
  });
}
