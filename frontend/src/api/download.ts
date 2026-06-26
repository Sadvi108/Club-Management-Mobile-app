import { Platform } from "react-native";
import { getAuthToken } from "./http";

// Downloads an authed PDF. Web: fetch→blob→open in a new tab (works through the CORS proxy).
// Native: expo-file-system writes the file with the bearer header, then expo-sharing opens it.
export async function downloadPdf(url: string, filename: string): Promise<void> {
  const token = getAuthToken();
  const headers: Record<string, string> = { accept: "application/pdf" };
  if (token) headers["Authorization"] = "bearer " + token;

  if (Platform.OS === "web") {
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error(`Download failed (${res.status})`);
    const blob = await res.blob();
    const objectUrl = URL.createObjectURL(blob);
    if (typeof window !== "undefined") {
      const a = document.createElement("a");
      a.href = objectUrl;
      a.target = "_blank";
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
    }
    setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    return;
  }

  // Native
  const FileSystem = require("expo-file-system");
  const Sharing = require("expo-sharing");
  const dest = FileSystem.cacheDirectory + filename;
  const { uri, status } = await FileSystem.downloadAsync(url, dest, { headers });
  if (status !== 200) throw new Error(`Download failed (${status})`);
  if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: "application/pdf" });
}
