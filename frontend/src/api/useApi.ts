import { useCallback, useEffect, useState } from "react";

type State<T> = { data: T | null; loading: boolean; error: string | null };

// Minimal data-fetching hook: runs `fn` on mount + when deps change, exposes reload().
export function useApi<T>(fn: () => Promise<T>, deps: any[] = []): State<T> & { reload: () => void } {
  const [state, setState] = useState<State<T>>({ data: null, loading: true, error: null });

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const run = useCallback(() => {
    let alive = true;
    setState((s) => ({ ...s, loading: true, error: null }));
    fn()
      .then((data) => alive && setState({ data, loading: false, error: null }))
      .catch((e) =>
        alive && setState({ data: null, loading: false, error: e?.message || "Failed to load" })
      );
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => run(), [run]);

  return { ...state, reload: run };
}
