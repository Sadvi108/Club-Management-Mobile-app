import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Switch, Platform, Linking } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack, notify } from "../src/ui/dialogs";
import { useNotifications } from "../src/notifications/NotificationsProvider";
import { CATEGORIES, type Category } from "../src/notifications/prefs";

const HOURS = Array.from({ length: 24 }, (_, i) => i);
const fmtHour = (h: number) => `${String(h).padStart(2, "0")}:00`;

export default function NotificationSettings() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { prefs, updatePrefs, permission, requestPermission, testAlert } = useNotifications();
  const [testing, setTesting] = useState(false);
  const [picking, setPicking] = useState<"start" | "end" | null>(null);

  const blocked = permission === "denied";
  const unsupported = permission === "unsupported";

  async function onTest() {
    setTesting(true);
    try {
      if (permission !== "granted") {
        const st = await requestPermission();
        if (st !== "granted") {
          await notify(
            "Notifications are off",
            Platform.OS === "web"
              ? "Allow notifications for this site in your browser, then try again."
              : "Enable notifications for D-CLIX in your device settings, then try again."
          );
          return;
        }
      }
      const shown = await testAlert();
      if (!shown) {
        // The test alert deliberately ignores quiet hours and category mutes, so the
        // master switch is the only setting that can block it — anything else here is
        // the platform refusing, not a preference.
        await notify(
          "Nothing was sent",
          !prefs.enabled
            ? "Push notifications are turned off above."
            : "This device would not show the notification. Check that alerts are allowed for D-CLIX."
        );
      }
    } finally {
      setTesting(false);
    }
  }

  async function openSystemSettings() {
    try {
      await Linking.openSettings();
    } catch {
      await notify("Open your device settings", "Find D-CLIX in the app list and allow notifications.");
    }
  }

  const setCategory = (key: Category, on: boolean) =>
    updatePrefs({ categories: { ...prefs.categories, [key]: on } });

  const setQuiet = (patch: Partial<typeof prefs.quietHours>) =>
    updatePrefs({ quietHours: { ...prefs.quietHours, ...patch } });

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="nset-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <View style={styles.titleWrap}>
            <Text style={styles.title}>Notification settings</Text>
          </View>
          {/* invisible twin of the back button, so the title sits dead centre */}
          <View style={styles.headerSpacer} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
        {/* Permission banner — nothing below matters while the OS is blocking us. */}
        {blocked && (
          <TouchableOpacity style={styles.banner} onPress={openSystemSettings} activeOpacity={0.85} testID="nset-permission">
            <Ionicons name="warning" size={20} color={colors.danger} />
            <View style={{ flex: 1 }}>
              <Text style={styles.bannerTitle}>Alerts are blocked</Text>
              <Text style={styles.bannerSub}>
                {Platform.OS === "web"
                  ? "This browser is blocking notifications for the site. Allow them in the address-bar site settings."
                  : "Tap to open system settings and allow notifications for D-CLIX."}
              </Text>
            </View>
            {Platform.OS !== "web" && <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />}
          </TouchableOpacity>
        )}
        {unsupported && (
          <View style={[styles.banner, { borderColor: colors.border }]}>
            <Ionicons name="information-circle" size={20} color={colors.textSecondary} />
            <Text style={[styles.bannerSub, { flex: 1 }]}>
              This device or browser cannot show system notifications. You will still see everything on the
              Notifications screen.
            </Text>
          </View>
        )}

        {/* Master + alert style */}
        <View style={styles.card}>
          <ToggleRow
            styles={styles}
            colors={colors}
            icon="notifications"
            title="Push notifications"
            sub="Alerts on your lock screen and notification tray"
            value={prefs.enabled}
            onChange={(v) => updatePrefs({ enabled: v })}
            testID="nset-enabled"
          />
          <View style={styles.divider} />
          <ToggleRow
            styles={styles}
            colors={colors}
            icon="volume-high"
            title="Sound"
            sub="Play the D-CLIX chime"
            value={prefs.sound}
            disabled={!prefs.enabled}
            onChange={(v) => updatePrefs({ sound: v })}
            testID="nset-sound"
          />
          <View style={styles.divider} />
          <ToggleRow
            styles={styles}
            colors={colors}
            icon="phone-portrait"
            title="Vibration"
            sub="Buzz when an alert arrives"
            value={prefs.vibrate}
            disabled={!prefs.enabled}
            onChange={(v) => updatePrefs({ vibrate: v })}
            testID="nset-vibrate"
          />
        </View>

        <TouchableOpacity
          style={[styles.testBtn, testing && { opacity: 0.6 }]}
          onPress={onTest}
          disabled={testing}
          activeOpacity={0.85}
          testID="nset-test"
        >
          <Ionicons name="play-circle" size={20} color="#fff" />
          <Text style={styles.testTxt}>{testing ? "Sending…" : "Send a test notification"}</Text>
        </TouchableOpacity>

        {/* Categories */}
        <Text style={styles.sectionTitle}>What to alert me about</Text>
        <View style={styles.card}>
          {CATEGORIES.map((c, i) => (
            <View key={c.key}>
              {i > 0 && <View style={styles.divider} />}
              <ToggleRow
                styles={styles}
                colors={colors}
                icon={c.icon}
                title={c.label}
                sub={c.hint}
                value={prefs.categories[c.key]}
                disabled={!prefs.enabled}
                onChange={(v) => setCategory(c.key, v)}
                testID={`nset-cat-${c.key}`}
              />
            </View>
          ))}
        </View>

        {/* Quiet hours */}
        <Text style={styles.sectionTitle}>Quiet hours</Text>
        <View style={styles.card}>
          <ToggleRow
            styles={styles}
            colors={colors}
            icon="moon"
            title="Silence overnight"
            sub={
              prefs.quietHours.enabled
                ? `No alerts from ${fmtHour(prefs.quietHours.startHour)} to ${fmtHour(prefs.quietHours.endHour)}`
                : "Alerts arrive at any hour"
            }
            value={prefs.quietHours.enabled}
            disabled={!prefs.enabled}
            onChange={(v) => setQuiet({ enabled: v })}
            testID="nset-quiet"
          />
          {prefs.quietHours.enabled && (
            <>
              <View style={styles.divider} />
              <View style={styles.rangeRow}>
                <TouchableOpacity
                  style={[styles.hourChip, picking === "start" && styles.hourChipActive]}
                  onPress={() => setPicking(picking === "start" ? null : "start")}
                  testID="nset-quiet-start"
                >
                  <Text style={styles.hourChipLbl}>From</Text>
                  <Text style={styles.hourChipVal}>{fmtHour(prefs.quietHours.startHour)}</Text>
                </TouchableOpacity>
                <Ionicons name="arrow-forward" size={16} color={colors.textMuted} />
                <TouchableOpacity
                  style={[styles.hourChip, picking === "end" && styles.hourChipActive]}
                  onPress={() => setPicking(picking === "end" ? null : "end")}
                  testID="nset-quiet-end"
                >
                  <Text style={styles.hourChipLbl}>To</Text>
                  <Text style={styles.hourChipVal}>{fmtHour(prefs.quietHours.endHour)}</Text>
                </TouchableOpacity>
              </View>
              {picking && (
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hourScroll}>
                  {HOURS.map((h) => {
                    const active =
                      picking === "start" ? h === prefs.quietHours.startHour : h === prefs.quietHours.endHour;
                    return (
                      <TouchableOpacity
                        key={h}
                        style={[styles.hourPill, active && styles.hourPillActive]}
                        onPress={() => {
                          setQuiet(picking === "start" ? { startHour: h } : { endHour: h });
                          setPicking(null);
                        }}
                      >
                        <Text style={[styles.hourPillTxt, active && { color: "#fff" }]}>{fmtHour(h)}</Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
              )}
            </>
          )}
        </View>

        {/* Honest about what the platform can and cannot do. */}
        <Text style={styles.sectionTitle}>How delivery works</Text>
        <View style={styles.card}>
          <InfoRow
            styles={styles}
            colors={colors}
            icon="logo-android"
            text="Android: alerts arrive with the app open or closed. Long-press an alert to fine-tune its channel in system settings."
          />
          <View style={styles.divider} />
          <InfoRow
            styles={styles}
            colors={colors}
            icon="logo-apple"
            text="iOS: alerts arrive with the app open or closed, using the bundled chime and your ringer switch."
          />
          <View style={styles.divider} />
          <InfoRow
            styles={styles}
            colors={colors}
            icon="globe-outline"
            text="Web: alerts arrive while a D-CLIX tab is open, even in the background. Sound needs one click on the page first, which browsers require before any audio can play."
          />
        </View>
        <Text style={styles.footnote}>
          The club server delivers notifications to the app, which checks for new ones every minute while open and
          about every 15 minutes in the background.
        </Text>
      </ScrollView>
    </View>
  );
}

function ToggleRow({
  styles,
  colors,
  icon,
  title,
  sub,
  value,
  onChange,
  disabled,
  testID,
}: {
  styles: any;
  colors: any;
  icon: string;
  title: string;
  sub: string;
  value: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  testID?: string;
}) {
  return (
    <View style={[styles.row, disabled && { opacity: 0.45 }]}>
      <View style={styles.rowIcon}>
        <Ionicons name={icon as any} size={18} color={colors.primary} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={styles.rowTitle}>{title}</Text>
        <Text style={styles.rowSub}>{sub}</Text>
      </View>
      <Switch
        testID={testID}
        value={value}
        disabled={disabled}
        onValueChange={onChange}
        trackColor={{ false: colors.border, true: colors.primary }}
        thumbColor="#fff"
        ios_backgroundColor={colors.border}
      />
    </View>
  );
}

function InfoRow({ styles, colors, icon, text }: { styles: any; colors: any; icon: string; text: string }) {
  return (
    <View style={styles.row}>
      <View style={styles.rowIcon}>
        <Ionicons name={icon as any} size={18} color={colors.textSecondary} />
      </View>
      <Text style={[styles.rowSub, { flex: 1 }]}>{text}</Text>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    headerSpacer: { width: 42, height: 42 },
    titleWrap: { flex: 1, alignItems: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    banner: { flexDirection: "row", alignItems: "center", gap: 12, backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 14, borderWidth: 1, borderColor: colors.danger + "66" },
    bannerTitle: { fontSize: 14, fontWeight: "800", color: colors.textPrimary },
    bannerSub: { fontSize: 12, color: colors.textSecondary, marginTop: 2, lineHeight: 17 },

    sectionTitle: { ...font.h4, color: colors.textPrimary, marginTop: 18, marginBottom: 10 },
    card: { backgroundColor: colors.surface, borderRadius: radius.lg, paddingHorizontal: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    divider: { height: 1, backgroundColor: colors.border },

    row: { flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 14 },
    rowIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    rowTitle: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    rowSub: { fontSize: 12, color: colors.textSecondary, marginTop: 2, lineHeight: 17 },

    testBtn: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, backgroundColor: colors.primary, borderRadius: radius.lg, paddingVertical: 14, marginTop: 14 },
    testTxt: { color: "#fff", fontSize: 14, fontWeight: "800" },

    rangeRow: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 14, paddingVertical: 14 },
    hourChip: { flex: 1, backgroundColor: colors.surfaceAlt, borderRadius: radius.md, paddingVertical: 10, alignItems: "center", borderWidth: 1, borderColor: "transparent" },
    hourChipActive: { borderColor: colors.primary },
    hourChipLbl: { fontSize: 11, color: colors.textSecondary, fontWeight: "700" },
    hourChipVal: { fontSize: 16, color: colors.textPrimary, fontWeight: "800", marginTop: 2 },
    hourScroll: { gap: 8, paddingBottom: 14 },
    hourPill: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: radius.full, backgroundColor: colors.surfaceAlt },
    hourPillActive: { backgroundColor: colors.primary },
    hourPillTxt: { fontSize: 12, fontWeight: "700", color: colors.textPrimary },

    footnote: { fontSize: 11, color: colors.textMuted, marginTop: 14, lineHeight: 16 },
  });
}
