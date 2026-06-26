import { Platform } from "react-native";
import * as WebBrowser from "expo-web-browser";

// ReceiptAsPDF / invoice PDFs are PUBLIC (no auth). Opening the URL lets the browser /
// device PDF viewer render the real document (logo + content) — this avoids the empty-file
// problem that came from fetching to a blob and saving it manually.
// Web: open in a new tab (URL points at the local CORS proxy).
// Native: open in the in-app browser (URL points at the live API directly).
export async function downloadPdf(url: string, _filename?: string): Promise<void> {
  if (Platform.OS === "web") {
    if (typeof window !== "undefined") window.open(url, "_blank");
    return;
  }
  await WebBrowser.openBrowserAsync(url);
}
