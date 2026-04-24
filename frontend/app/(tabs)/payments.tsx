import { useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Modal, Alert } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { colors, font, radius, shadow, spacing } from "../../src/theme";
import { student, payments } from "../../src/mockData";

const methods = [
  { id: "card", label: "Credit / Debit Card", icon: "card" },
  { id: "wallet", label: "UPI / Wallet", icon: "phone-portrait" },
  { id: "bank", label: "Bank Transfer", icon: "business" },
];

export default function Payments() {
  const [showPay, setShowPay] = useState(false);
  const [selected, setSelected] = useState("card");

  const confirmPay = () => {
    setShowPay(false);
    setTimeout(() => Alert.alert("Payment Successful", `RM ${student.nextPayment.amount} paid via ${methods.find(m => m.id === selected)?.label}`), 200);
  };

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <Text style={styles.title}>Fees & Payments</Text>
          <TouchableOpacity style={styles.iconBtn}>
            <Ionicons name="download-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.dueCard}>
          <View style={styles.dueRow}>
            <Ionicons name="alert-circle" size={18} color="#FDE68A" />
            <Text style={styles.dueLbl}>NEXT PAYMENT DUE</Text>
          </View>
          <Text style={styles.dueAmt}>RM {student.nextPayment.amount.toLocaleString()}</Text>
          <Text style={styles.dueLabel}>{student.nextPayment.label}</Text>
          <Text style={styles.dueDate}>Due by {student.nextPayment.dueDate}</Text>
          <TouchableOpacity style={styles.payBtn} onPress={() => setShowPay(true)} testID="payments-pay-now">
            <Text style={styles.payBtnTxt}>Pay Now</Text>
            <Ionicons name="arrow-forward" size={16} color={colors.primary} />
          </TouchableOpacity>
        </LinearGradient>

        {/* Packages */}
        <Text style={styles.section}>Quick Pay</Text>
        <View style={styles.pkgRow}>
          <View style={styles.pkgCard}>
            <Ionicons name="calendar" size={22} color={colors.primary} />
            <Text style={styles.pkgLbl}>Monthly</Text>
            <Text style={styles.pkgAmt}>RM 480</Text>
          </View>
          <View style={styles.pkgCard}>
            <Ionicons name="calendar-outline" size={22} color={colors.purple} />
            <Text style={styles.pkgLbl}>Quarterly</Text>
            <Text style={styles.pkgAmt}>RM 1,300</Text>
          </View>
          <View style={styles.pkgCard}>
            <Ionicons name="trophy" size={22} color={colors.accent} />
            <Text style={styles.pkgLbl}>Tournament</Text>
            <Text style={styles.pkgAmt}>RM 150</Text>
          </View>
        </View>

        {/* Payment history */}
        <View style={styles.sectionHead}>
          <Text style={styles.section}>Payment History</Text>
          <TouchableOpacity><Text style={styles.link}>Export</Text></TouchableOpacity>
        </View>

        {payments.map((p) => (
          <View key={p.id} style={styles.histCard} testID={`payment-${p.id}`}>
            <View style={styles.histIcon}>
              <Ionicons name="checkmark" size={18} color={colors.success} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.histLabel}>{p.label}</Text>
              <Text style={styles.histMeta}>{p.date} · {p.method}</Text>
            </View>
            <View style={{ alignItems: "flex-end" }}>
              <Text style={styles.histAmt}>RM {p.amount.toLocaleString()}</Text>
              <TouchableOpacity style={styles.receiptBtn} testID={`receipt-${p.id}`}>
                <Ionicons name="download-outline" size={12} color={colors.primary} />
                <Text style={styles.receiptTxt}>Receipt</Text>
              </TouchableOpacity>
            </View>
          </View>
        ))}
      </ScrollView>

      {/* Pay Modal */}
      <Modal visible={showPay} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <View style={styles.modalHandle} />
            <Text style={styles.modalTitle}>Complete Payment</Text>
            <Text style={styles.modalSub}>Choose payment method</Text>
            <Text style={styles.modalAmt}>RM {student.nextPayment.amount.toLocaleString()}</Text>

            {methods.map((m) => (
              <TouchableOpacity
                key={m.id}
                onPress={() => setSelected(m.id)}
                style={[styles.methodRow, selected === m.id && styles.methodRowActive]}
                testID={`pay-method-${m.id}`}
              >
                <View style={[styles.methodIcon, selected === m.id && { backgroundColor: colors.primary }]}>
                  <Ionicons name={m.icon as any} size={18} color={selected === m.id ? "#fff" : colors.primary} />
                </View>
                <Text style={styles.methodLbl}>{m.label}</Text>
                <Ionicons
                  name={selected === m.id ? "radio-button-on" : "radio-button-off"}
                  size={20}
                  color={selected === m.id ? colors.primary : colors.textMuted}
                />
              </TouchableOpacity>
            ))}

            <TouchableOpacity onPress={confirmPay} activeOpacity={0.9} testID="pay-confirm-btn">
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.confirmBtn}>
                <Ionicons name="lock-closed" size={14} color="#fff" />
                <Text style={styles.confirmTxt}>Confirm & Pay Securely</Text>
              </LinearGradient>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => setShowPay(false)} style={{ marginTop: 10, alignSelf: "center" }}>
              <Text style={{ color: colors.textSecondary, fontSize: 13 }}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, paddingVertical: 14 },
  title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
  iconBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },

  dueCard: { borderRadius: radius.xxl, padding: 22, ...shadow.strong },
  dueRow: { flexDirection: "row", gap: 6, alignItems: "center" },
  dueLbl: { color: "#FDE68A", fontSize: 11, fontWeight: "800", letterSpacing: 1.2 },
  dueAmt: { color: "#fff", fontSize: 38, fontWeight: "800", marginTop: 8, letterSpacing: -1 },
  dueLabel: { color: "rgba(255,255,255,0.9)", fontSize: 13, fontWeight: "500", marginTop: 2 },
  dueDate: { color: "rgba(255,255,255,0.75)", fontSize: 12, marginTop: 2 },
  payBtn: { flexDirection: "row", gap: 8, alignSelf: "flex-start", backgroundColor: "#fff", paddingHorizontal: 20, paddingVertical: 12, borderRadius: radius.md, alignItems: "center", marginTop: 18 },
  payBtnTxt: { color: colors.primary, fontWeight: "800", fontSize: 14 },

  section: { ...font.h3, color: colors.textPrimary, marginTop: 24, marginBottom: 14 },
  sectionHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-end" },
  link: { color: colors.primary, fontWeight: "700", fontSize: 12 },

  pkgRow: { flexDirection: "row", gap: 10 },
  pkgCard: { flex: 1, backgroundColor: "#fff", borderRadius: radius.lg, padding: 14, ...shadow.soft },
  pkgLbl: { fontSize: 11, color: colors.textSecondary, marginTop: 10, fontWeight: "600" },
  pkgAmt: { fontSize: 15, color: colors.textPrimary, fontWeight: "800", marginTop: 2 },

  histCard: { flexDirection: "row", gap: 12, alignItems: "center", backgroundColor: "#fff", padding: 14, borderRadius: radius.lg, marginBottom: 10, ...shadow.soft },
  histIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: "#D1FAE5", alignItems: "center", justifyContent: "center" },
  histLabel: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
  histMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  histAmt: { fontSize: 14, fontWeight: "800", color: colors.textPrimary },
  receiptBtn: { flexDirection: "row", gap: 3, alignItems: "center", marginTop: 4 },
  receiptTxt: { color: colors.primary, fontSize: 10, fontWeight: "700" },

  modalOverlay: { flex: 1, backgroundColor: "rgba(15,23,42,0.5)", justifyContent: "flex-end" },
  modalCard: { backgroundColor: "#fff", borderTopLeftRadius: 28, borderTopRightRadius: 28, padding: 22, paddingBottom: 36 },
  modalHandle: { width: 40, height: 4, backgroundColor: colors.border, borderRadius: 2, alignSelf: "center", marginBottom: 18 },
  modalTitle: { ...font.h2, color: colors.textPrimary },
  modalSub: { color: colors.textSecondary, fontSize: 12, marginTop: 4 },
  modalAmt: { ...font.h1, color: colors.primary, fontSize: 32, marginTop: 12, marginBottom: 10 },
  methodRow: { flexDirection: "row", gap: 12, alignItems: "center", padding: 14, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, marginBottom: 10 },
  methodRowActive: { borderColor: colors.primary, backgroundColor: "#EEF2FF" },
  methodIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: "#EEF2FF", alignItems: "center", justifyContent: "center" },
  methodLbl: { flex: 1, fontSize: 14, color: colors.textPrimary, fontWeight: "600" },
  confirmBtn: { flexDirection: "row", gap: 8, paddingVertical: 16, borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginTop: 10, ...shadow.strong },
  confirmTxt: { color: "#fff", fontWeight: "800", fontSize: 14 },
});
