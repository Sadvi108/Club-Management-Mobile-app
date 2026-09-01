import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme, radius } from "../src/theme";
import { ReportScaffold, SelectField, KV, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { TournamentRow } from "../src/api/types";

export default function ReportTournamentPast() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();
  const [name, setName] = useState<string>("");

  // `reportType: "past"` 400'd this route (it casts reportType to an int) and the error envelope
  // came back as the payload, crashing the screen on `allRows.forEach`. Same fix as the upcoming
  // screen — see app/r-tournament-upcoming.tsx.
  const { data, loading, error } = useApi<TournamentRow[]>(
    () =>
      token
        ? (api.tournamentSummary({ fromDate: null, toDate: null }) as Promise<TournamentRow[]>)
        : Promise.resolve([]),
    [token]
  );

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
      title="Tournament (Past)"
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
          testID="rep-tournament-past"
        />
      }
      renderItem={(item) => (
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
