import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ImageBackground, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter, useLocalSearchParams } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

function fmtDate(iso?: string) {
  if (!iso) return "—";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

// Offers are redeemed by showing this screen at the counter (per the offer text itself),
// so the detail doubles as the redeemable voucher: image, terms, validity + member strip.
export default function OfferDetail() {
  const router = useRouter();
  const { code } = useLocalSearchParams<{ code?: string }>();
  const { colors, shadow, mode } = useTheme();
  const { user } = useAuth();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  // Offers only exist inside HomePageStats — refetch and select by code (ids are all 0).
  const stats = useApi(() => api.homePageStats(), []);
  const offers = stats.data?.myoffers ?? [];
  const offer = offers.find((o) => o.code === code) ?? offers[0];
  const img = offer?.attachments?.[0]?.documentUrl || offer?.previewImages?.[0]?.documentUrl;
  const expired = offer?.expiryDate ? new Date(offer.expiryDate).getTime() < Date.now() : false;

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="offer-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Offer</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ paddingBottom: 40 }} showsVerticalScrollIndicator={false}>
        {stats.loading && !offer && <ActivityIndicator color={colors.primary} style={{ marginVertical: 60 }} />}
        {stats.error && <Text style={styles.errTxt}>{stats.error}</Text>}
        {!stats.loading && !offer && (
          <View style={styles.empty}>
            <Ionicons name="pricetag-outline" size={48} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>Offer not found</Text>
          </View>
        )}

        {offer && (
          <>
            <ImageBackground source={img ? { uri: img } : undefined} style={styles.hero} imageStyle={{ borderRadius: radius.xl }}>
              <LinearGradient colors={["rgba(15,23,42,0)", "rgba(15,23,42,0.85)"]} style={[StyleSheet.absoluteFillObject, { borderRadius: radius.xl }]} />
              <View style={styles.heroBottom}>
                <View style={styles.codePill}><Text style={styles.codeTxt}>{(offer.code || "OFFER").toUpperCase()}</Text></View>
                <Text style={styles.heroTitle}>{offer.name}</Text>
              </View>
            </ImageBackground>

            <View style={styles.card}>
              <Text style={styles.sectionLbl}>DETAILS</Text>
              <Text style={styles.desc}>{(offer.description || "").replace(/\r\n/g, "\n").trim() || "No further details."}</Text>

              <View style={styles.metaRow}>
                <View style={styles.metaItem}>
                  <Ionicons name="calendar-outline" size={16} color={expired ? colors.danger : colors.primary} />
                  <View>
                    <Text style={styles.metaLbl}>Valid till</Text>
                    <Text style={[styles.metaVal, expired && { color: colors.danger }]}>{fmtDate(offer.expiryDate)}{expired ? " (expired)" : ""}</Text>
                  </View>
                </View>
                <View style={styles.metaItem}>
                  <Ionicons name="business-outline" size={16} color={colors.primary} />
                  <View>
                    <Text style={styles.metaLbl}>Academy</Text>
                    <Text style={styles.metaVal} numberOfLines={1}>{user?.clubName || "Your Academy"}</Text>
                  </View>
                </View>
              </View>
            </View>

            {/* Redeem strip — what the shop keeper needs to see */}
            <View style={styles.redeem}>
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.redeemGrad}>
                <Ionicons name="qr-code-outline" size={28} color="#fff" />
                <View style={{ flex: 1 }}>
                  <Text style={styles.redeemTitle}>Show this screen to redeem</Text>
                  <Text style={styles.redeemSub} numberOfLines={1}>
                    {user?.name?.trim() || "Member"} · {offer.code}
                  </Text>
                </View>
              </LinearGradient>
            </View>
          </>
        )}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    errTxt: { color: colors.danger, fontSize: 13, margin: spacing.xl },
    empty: { alignItems: "center", paddingVertical: 70, gap: 8 },
    emptyTxt: { ...font.h4, color: colors.textPrimary },

    hero: { height: 220, marginHorizontal: spacing.xl, borderRadius: radius.xl, overflow: "hidden", justifyContent: "flex-end", backgroundColor: colors.surfaceAlt },
    heroBottom: { padding: 16 },
    codePill: { alignSelf: "flex-start", backgroundColor: "rgba(255,255,255,0.95)", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10, marginBottom: 8 },
    codeTxt: { color: colors.primary, fontSize: 10, fontWeight: "800", letterSpacing: 1 },
    heroTitle: { color: "#fff", fontSize: 20, fontWeight: "800" },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, marginHorizontal: spacing.xl, marginTop: 16, padding: 16, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    sectionLbl: { fontSize: 10, fontWeight: "800", letterSpacing: 1, color: colors.textMuted, marginBottom: 8 },
    desc: { fontSize: 13.5, color: colors.textSecondary, lineHeight: 20 },
    metaRow: { flexDirection: "row", gap: 16, marginTop: 16 },
    metaItem: { flex: 1, flexDirection: "row", gap: 8, alignItems: "center" },
    metaLbl: { fontSize: 10, color: colors.textMuted, fontWeight: "700" },
    metaVal: { fontSize: 12.5, color: colors.textPrimary, fontWeight: "700", marginTop: 1 },

    redeem: { marginHorizontal: spacing.xl, marginTop: 16 },
    redeemGrad: { borderRadius: radius.xl, padding: 18, flexDirection: "row", alignItems: "center", gap: 14 },
    redeemTitle: { color: "#fff", fontSize: 14, fontWeight: "800" },
    redeemSub: { color: "rgba(255,255,255,0.9)", fontSize: 12, marginTop: 2, fontWeight: "600" },
  });
}
