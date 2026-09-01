import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme, radius } from "../src/theme";
import { ReportScaffold, SelectField, KV, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { TournamentRow } from "../src/api/types";

export default function ReportTournamentUpcoming() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();
  const [name, setName] = useState<string>("");

  // `reportType: "upcoming"` used to be sent here. The route casts reportType to an int, so it
  // answered `{"status":400,...,"error":"Error converting data type nvarchar to int."}`, and the
  // error envelope was handed back as the payload — `allRows.forEach` then threw on an object and
  // took the screen down. Both halves are fixed (src/api/http.ts + api.tournamentSummary); the
  // request now carries no reportType, which is what actually returns rows.
  const { data, loading, error } = useApi<TournamentRow[]>(
    () =>
      token
        ? (api.tournamentSummary({ fromDate: null, toDate: null }) as Promise<TournamentRow[]>)
        : Promise.resolve([]),
    [token]
  );

  // Never assume the shape of a report payload — one bad response should not crash a screen.
  const allRows = useMemo(() => (Array.isArray(data) ? data : []), [data]);

  const nameOptions: Option[] = useMemo(() => {
    const seen = new Set<string>();
    const opts: Option[] = [{ id: "", text: "All" }];
    allRows.forEach((r) => {
      const n = (r.name || "").trim();
      if (n && !seen.has(n)) {
        seen.add(n);
        opts.push({ id: n, text: n });
      }
    });
    return opts;
  }, [allRows]);

  const rows = name ? allRows.filter((r) => (r.name || "").trim() === name) : allRows;

  return (
    <ReportScaffold<TournamentRow>
      title="Upcoming Tournament"
      loading={loading}
      error={error}
      data={rows}
      emptyText="No tournament data."
      keyExtractor={(item, i) => `${item.id}-${i}`}
      filters={
        <SelectField
          label="Tournament Name"
          placeholder="All"
          value={name}
          options={nameOptions}
          onChange={(id) => setName(String(id))}
          testID="rep-tournament-upcoming"
        />
      }
      renderItem={(item) => (
        // The route returns a medal summary grouped by gender — name/ageGroup/category come back
        // empty on live data, so the gender group is the honest heading when there is no name.
        <View style={styles.card}>
          <Text style={styles.cardTitle} numberOfLines={2}>
            {item.name?.trim() || item.category?.trim() || item.gender?.trim() || "Tournament"}
          </Text>
          {!!item.ageGroup && <KV label="Age Group" value={item.ageGroup} />}
          {!!item.gender && <KV label="Gender" value={item.gender} />}
          <KV label="Players" value={item.playerCount ?? 0} />
          <Text style={styles.medals}>
            Gold {item.medalGold ?? 0} · Silver {item.medalSilver ?? 0} · Bronze {item.medalBronze ?? 0}
          </Text>
        </View>
      )}
    />
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginBottom: 2 },
    medals: { fontSize: 12, color: colors.textSecondary, fontWeight: "700", marginTop: 8 },
  });
}
