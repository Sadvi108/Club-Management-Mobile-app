import { useCallback, useEffect, useRef, useState } from "react";

type State<T> = { data: T | null; loading: boolean; error: string | null };

/**
 * Minimal data-fetching hook: runs `fn` on mount + when deps change, exposes reload().
 *
 * Two behaviours worth knowing, both deliberate:
 *
 * 1. A failed fetch keeps whatever data was already on screen. It used to null `data`, which
 *    turned every error into a confident empty state — a failed HomePageStats rendered
 *    "RM 0 / 0 invoices due" and a failed schedule rendered "Rest Day". Screens must render
 *    `error` to tell the user something is stale; they no longer have to guard against the
 *    data vanishing underneath them.
 * 2. Calling reload() cancels the in-flight request. Previously each invocation owned its own
 *    `alive` flag and only the effect's own cleanup ever flipped one, so a manual reload could
 *    race a deps-driven run and the slower, older response would win.
 */
export function useApi<T>(fn: () => Promise<T>, deps: any[] = []): State<T> & { reload: () => void } {
  const [state, setState] = useState<State<T>>({ data: null, loading: true, error: null });
  const runIdRef = useRef(0);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const run = useCallback(() => {
    const runId = ++runIdRef.current;
    const isCurrent = () => runIdRef.current === runId;

    setState((s) => ({ ...s, loading: true, error: null }));
    fn()
      .then((data) => isCurrent() && setState({ data, loading: false, error: null }))
      .catch(
        (e) =>
          isCurrent() &&
          // keep the previous `data` — a stale value plus a visible error beats a fake zero
          setState((s) => ({ ...s, loading: false, error: e?.message || "Failed to load" }))
      );

    return () => {
      // Supersede this run so a late resolution cannot overwrite newer state.
      if (isCurrent()) runIdRef.current++;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => run(), [run]);

  return { ...state, reload: run };
}
