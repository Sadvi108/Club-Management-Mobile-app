import { Platform } from "react-native";
import * as WebBrowser from "expo-web-browser";

// Downloads a PDF as a real saved file (not just a viewer).
// These PDFs (ReceiptAsPDF) are public — no auth header needed.
// Web: fetch → blob → anchor with `download` (forces a Save, not an in-tab view).
// Native: expo-file-system writes the file to cache, then the share/save sheet opens it.
export async function downloadPdf(url: string, filename: string): Promise<void> {
  const safeName = filename.replace(/[^\w.\-]+/g, "_");

  if (Platform.OS === "web") {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Download failed (${res.status})`);
    const blob = await res.blob();
    if (!blob.size) throw new Error("Empty file received.");
    const objectUrl = URL.createObjectURL(blob);
    if (typeof document !== "undefined") {
      const a = document.createElement("a");
      a.href = objectUrl;
      a.download = safeName; // no target=_blank → browser saves the file
      a.rel = "noopener";
      document.body.appendChild(a);
      a.click();
      a.remove();
    }
    setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    return;
  }

  // Native: download to cache, then offer Save/Share.
  const FileSystem = require("expo-file-system/legacy");
  const Sharing = require("expo-sharing");
  const dest = (FileSystem.cacheDirectory || "") + safeName;
  const { uri, status } = await FileSystem.downloadAsync(url, dest);
  if (status !== 200) throw new Error(`Download failed (${status})`);
  if (await Sharing.isAvailableAsync()) {
    await Sharing.shareAsync(uri, { mimeType: "application/pdf", dialogTitle: safeName, UTI: "com.adobe.pdf" });
  } else {
    await WebBrowser.openBrowserAsync(uri);
  }
}
