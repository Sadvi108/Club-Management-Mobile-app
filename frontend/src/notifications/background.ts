// Background polling (native APK only): a WorkManager/BGTask job that runs ~every 15 min
// even with the app closed, restores the persisted session and raises local alerts for
// new notifications. Web + Expo Go don't support this — everything is guarded.
import { Platform } from "react-native";
import { storage } from "../api/storage";
import { secureStore } from "../api/secureStore";
import { setAuthToken } from "../api/http";
import { TOKEN_KEY, USER_KEY } from "../api/auth";
import { diffAndAlert } from "./service";

export const BG_NOTIF_TASK = "dclix-notification-poll";

// defineTask MUST run at module load: headless background launches execute the JS bundle
// without rendering React, then look the task up by name. (This module is imported from
// the root layout, so it's always in the bundle.)
if (Platform.OS !== "web") {
  try {
    const TaskManager: typeof import("expo-task-manager") = require("expo-task-manager");
    const BackgroundTask: typeof import("expo-background-task") = require("expo-background-task");
    if (!TaskManager.isTaskDefined(BG_NOTIF_TASK)) {
      TaskManager.defineTask(BG_NOTIF_TASK, async () => {
        try {
          // Headless context: React providers aren't mounted — restore the session by hand.
          // Token from the secure store; user (for the id) from AsyncStorage. Fall back to the
          // pre-2.4 combined blob for sessions saved before the split.
          let token = await secureStore.get(TOKEN_KEY);
          let userId: number | undefined;
          const userRaw = await storage.get(USER_KEY);
          if (userRaw) userId = JSON.parse(userRaw)?.id;
          if (!token || !userId) {
            const legacy = await storage.get("dclix.session.v1");
            if (legacy) {
              const s = JSON.parse(legacy);
              token = token || s?.token;
              userId = userId || s?.user?.id;
            }
          }
          if (!token || !userId) return BackgroundTask.BackgroundTaskResult.Success;
          setAuthToken(token);
          await diffAndAlert(userId);
          return BackgroundTask.BackgroundTaskResult.Success;
        } catch {
          return BackgroundTask.BackgroundTaskResult.Failed;
        }
      });
    }
  } catch {
    /* task manager unavailable (web bundle / Expo Go edge cases) */
  }
}

export async function registerBackgroundNotificationTask() {
  if (Platform.OS === "web") return;
  try {
    const TaskManager: typeof import("expo-task-manager") = require("expo-task-manager");
    const BackgroundTask: typeof import("expo-background-task") = require("expo-background-task");
    const registered = await TaskManager.isTaskRegisteredAsync(BG_NOTIF_TASK);
    if (!registered) {
      await BackgroundTask.registerTaskAsync(BG_NOTIF_TASK, { minimumInterval: 15 }); // minutes
    }
  } catch {
    /* background polling is best-effort (unsupported in Expo Go / web) */
  }
}
