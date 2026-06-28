import { useMemo, useState } from "react";
import {
  View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, Image,
  ActivityIndicator, KeyboardAvoidingView, Platform, Modal,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import * as ImagePicker from "expo-image-picker";
import { radius, spacing, font, useTheme } from "../src/theme";
import { notify, safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";

function initialsOf(name?: string) {
  return (name || "?").trim().split(/\s+/).map((w) => w[0]).slice(0, 2).join("").toUpperCase();
}

export default function EditProfile() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user, updateUser } = useAuth();

  const [name, setName] = useState(user?.name?.trim() || "");
  const [email, setEmail] = useState(user?.emailAddress || "");
  const [phone, setPhone] = useState(user?.handPhone || "");
  const [gender, setGender] = useState(user?.gender || "");
  const [address, setAddress] = useState(user?.address1 || "");
  const [postal, setPostal] = useState(user?.postalCode || "");
  const [photo, setPhoto] = useState<ImagePicker.ImagePickerAsset | null>(null);
  const [saving, setSaving] = useState(false);
  const [picker, setPicker] = useState(false);

  const avatarUri = photo?.uri || user?.profilePic;

  async function toUploadFile(asset: ImagePicker.ImagePickerAsset): Promise<any> {
    const fname = asset.fileName || `dp_${Date.now()}.jpg`;
    const type = asset.mimeType || "image/jpeg";
    if (Platform.OS === "web") {
      const blob = await (await fetch(asset.uri)).blob();
      return new File([blob], fname, { type: blob.type || type });
    }
    return { uri: asset.uri, name: fname, type };
  }

  async function pick(from: "camera" | "gallery") {
    setPicker(false);
    try {
      const perm = from === "camera"
        ? await ImagePicker.requestCameraPermissionsAsync()
        : await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) { notify("Permission needed", `Allow ${from} access to set a photo.`); return; }
      const res = from === "camera"
        ? await ImagePicker.launchCameraAsync({ quality: 0.6, allowsEditing: true, aspect: [1, 1] })
        : await ImagePicker.launchImageLibraryAsync({ quality: 0.6, allowsEditing: true, aspect: [1, 1], mediaTypes: ImagePicker.MediaTypeOptions.Images });
      if (!res.canceled && res.assets?.[0]) setPhoto(res.assets[0]);
    } catch (e: any) {
      notify("Could not pick image", e?.message || "Try again.");
    }
  }

  async function save() {
    if (!user) return;
    if (!name.trim()) { notify("Name required", "Please enter your name."); return; }
    setSaving(true);
    try {
      const fields: Record<string, string | number> = {
        Id: user.id,
        UserId: user.userId,
        IcNo: user.icNo,
        Name: name.trim(),
        EmailAddress: email.trim(),
        HandPhone: phone.trim(),
        Gender: gender,
        Address1: address,
        Address2: user.address2 || "",
        Address3: user.address3 || "",
        Address4: user.address4 || "",
        PostalCode: postal,
        BranchId: user.branchId,
        ClubId: user.clubId,
      };
      const file = photo ? await toUploadFile(photo) : undefined;
      const dpUrl = await api.updateProfile(fields, file);
      updateUser({
        name: name.trim(),
        emailAddress: email.trim(),
        handPhone: phone.trim(),
        gender,
        address1: address,
        postalCode: postal,
        ...(dpUrl && typeof dpUrl === "string" ? { profilePic: dpUrl } : {}),
      });
      setSaving(false);
      await notify("Saved", "Your profile has been updated.");
      safeBack(router);
    } catch (e: any) {
      setSaving(false);
      notify("Update failed", e?.message || "Could not save your profile.");
    }
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router)} testID="ep-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title} numberOfLines={1}>Edit Profile</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
          {/* Avatar + camera */}
          <View style={styles.avatarWrap}>
            <TouchableOpacity onPress={() => setPicker(true)} activeOpacity={0.85} testID="ep-photo">
              {avatarUri ? (
                <Image source={{ uri: avatarUri }} style={styles.avatar} />
              ) : (
                <View style={[styles.avatar, styles.avatarEmpty]}>
                  <Text style={styles.avatarInitials}>{initialsOf(name)}</Text>
                </View>
              )}
              <View style={styles.camBadge}>
                <Ionicons name="camera" size={16} color="#fff" />
              </View>
            </TouchableOpacity>
            <Text style={styles.avatarHint}>Tap to change photo</Text>
          </View>

          <Field label="Name" value={name} onChange={setName} icon="person-outline" styles={styles} colors={colors} testID="ep-name" />
          <Field label="Email" value={email} onChange={setEmail} icon="mail-outline" keyboardType="email-address" styles={styles} colors={colors} testID="ep-email" />
          <Field label="Mobile No" value={phone} onChange={setPhone} icon="call-outline" keyboardType="phone-pad" styles={styles} colors={colors} testID="ep-phone" />

          <Text style={styles.fieldLabel}>Gender</Text>
          <View style={styles.genderRow}>
            {["Male", "Female"].map((g) => {
              const on = gender === g;
              return (
                <TouchableOpacity key={g} style={[styles.genderPill, on && styles.genderPillOn]} onPress={() => setGender(g)} testID={`ep-gender-${g}`}>
                  <Ionicons name={g === "Male" ? "male" : "female"} size={16} color={on ? "#fff" : colors.primary} />
                  <Text style={[styles.genderTxt, on && { color: "#fff" }]}>{g}</Text>
                </TouchableOpacity>
              );
            })}
          </View>

          <Field label="Address" value={address} onChange={setAddress} icon="location-outline" multiline styles={styles} colors={colors} testID="ep-address" />
          <Field label="Postal Code" value={postal} onChange={setPostal} icon="map-outline" keyboardType="number-pad" styles={styles} colors={colors} testID="ep-postal" />

          {/* read-only info */}
          <View style={styles.readonlyCard}>
            <Text style={styles.readonlyTitle}>Read-only</Text>
            <ReadRow label="IC No" value={user?.icNo} colors={colors} />
            <ReadRow label="Registration No" value={user?.code} colors={colors} />
            <ReadRow label="Grade" value={user?.currentGrade} colors={colors} />
          </View>

          <TouchableOpacity onPress={save} disabled={saving} activeOpacity={0.9} testID="ep-save">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.saveBtn, shadow.strong]}>
              {saving ? <ActivityIndicator color="#fff" /> : (
                <>
                  <Ionicons name="checkmark" size={18} color="#fff" />
                  <Text style={styles.saveTxt}>Save Changes</Text>
                </>
              )}
            </LinearGradient>
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>

      {/* Gallery / Camera sheet */}
      <Modal visible={picker} transparent animationType="slide" onRequestClose={() => setPicker(false)}>
        <TouchableOpacity style={styles.sheetBackdrop} activeOpacity={1} onPress={() => setPicker(false)}>
          <View style={styles.sheet}>
            <View style={styles.sheetHandle} />
            <View style={styles.sheetRow}>
              <TouchableOpacity style={styles.sheetOpt} onPress={() => pick("gallery")} testID="ep-gallery">
                <View style={[styles.sheetIcon, { backgroundColor: "#FB7185" }]}><Ionicons name="images" size={26} color="#fff" /></View>
                <Text style={styles.sheetLbl}>Gallery</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.sheetOpt} onPress={() => pick("camera")} testID="ep-camera">
                <View style={[styles.sheetIcon, { backgroundColor: "#34D399" }]}><Ionicons name="camera" size={26} color="#fff" /></View>
                <Text style={styles.sheetLbl}>Camera</Text>
              </TouchableOpacity>
            </View>
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

function Field({ label, value, onChange, icon, styles, colors, multiline, keyboardType, testID }: any) {
  return (
    <>
      <Text style={styles.fieldLabel}>{label}</Text>
      <View style={[styles.inputRow, multiline && { alignItems: "flex-start" }]}>
        <Ionicons name={icon} size={18} color={colors.primary} style={multiline ? { marginTop: 12 } : undefined} />
        <TextInput
          style={[styles.input, multiline && { height: 70, textAlignVertical: "top" }]}
          value={value}
          onChangeText={onChange}
          placeholder={label}
          placeholderTextColor={colors.textMuted}
          multiline={multiline}
          keyboardType={keyboardType}
          autoCapitalize={keyboardType === "email-address" ? "none" : "sentences"}
          testID={testID}
        />
      </View>
    </>
  );
}

function ReadRow({ label, value, colors }: any) {
  return (
    <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: 8, gap: spacing.md }}>
      <Text style={{ fontSize: 13, color: colors.textSecondary }} numberOfLines={1}>{label}</Text>
      <Text style={{ flex: 1, fontSize: 13, color: colors.textPrimary, fontWeight: "600", textAlign: "right" }} numberOfLines={1}>{value || "—"}</Text>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    avatarWrap: { alignItems: "center", marginBottom: 20 },
    avatar: { width: 110, height: 110, borderRadius: 55, backgroundColor: colors.surfaceAlt },
    avatarEmpty: { alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: colors.border },
    avatarInitials: { fontSize: 36, fontWeight: "800", color: colors.primary },
    camBadge: { position: "absolute", right: 2, bottom: 2, width: 34, height: 34, borderRadius: 17, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center", borderWidth: 3, borderColor: colors.background },
    avatarHint: { fontSize: 12, color: colors.textSecondary, marginTop: 10, fontWeight: "600" },

    fieldLabel: { fontSize: 13, fontWeight: "700", color: colors.textSecondary, marginBottom: 8, marginTop: 6 },
    inputRow: { flexDirection: "row", alignItems: "center", gap: 10, backgroundColor: colors.surface, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 14, marginBottom: 14 },
    input: { flex: 1, color: colors.textPrimary, fontSize: 15, paddingVertical: 12 },

    genderRow: { flexDirection: "row", gap: 12, marginBottom: 14 },
    genderPill: { flex: 1, flexDirection: "row", gap: 8, alignItems: "center", justifyContent: "center", paddingVertical: 12, borderRadius: radius.md, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
    genderPillOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    genderTxt: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },

    readonlyCard: { backgroundColor: colors.surfaceAlt, borderRadius: radius.md, padding: 14, marginTop: 6, marginBottom: 20 },
    readonlyTitle: { fontSize: 11, fontWeight: "800", color: colors.textMuted, letterSpacing: 1, marginBottom: 6 },

    saveBtn: { flexDirection: "row", gap: 8, paddingVertical: 16, borderRadius: radius.md, alignItems: "center", justifyContent: "center", minHeight: 54 },
    saveTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },

    sheetBackdrop: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" },
    sheet: { backgroundColor: colors.surface, borderTopLeftRadius: radius.xxl, borderTopRightRadius: radius.xxl, paddingTop: 12, paddingBottom: 40, paddingHorizontal: spacing.xl },
    sheetHandle: { alignSelf: "center", width: 44, height: 5, borderRadius: 3, backgroundColor: colors.border, marginBottom: 24 },
    sheetRow: { flexDirection: "row", justifyContent: "space-around" },
    sheetOpt: { alignItems: "center", gap: 10 },
    sheetIcon: { width: 64, height: 64, borderRadius: 20, alignItems: "center", justifyContent: "center" },
    sheetLbl: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
  });
}
