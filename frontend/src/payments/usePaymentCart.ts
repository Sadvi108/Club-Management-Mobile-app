import { useCallback, useMemo, useState } from "react";
import type { Invoice } from "../api/types";

// A cart item is a real invoice plus the account it belongs to and whether it is a prepay term.
export type CartItem = {
  key: string;            // unique: `${studentId}:${invoiceId}` or `term:${studentId}:${year}-${month}`
  studentId: number;
  studentName: string;
  invoice: Invoice;       // for prepay terms, a synthesized Invoice-shaped object
  isTerm: boolean;
};

export function usePaymentCart() {
  const [items, setItems] = useState<Record<string, CartItem>>({});

  const has = useCallback((key: string) => key in items, [items]);

  const toggle = useCallback((item: CartItem) => {
    setItems((prev) => {
      const next = { ...prev };
      if (next[item.key]) delete next[item.key];
      else next[item.key] = item;
      return next;
    });
  }, []);

  const clear = useCallback(() => setItems({}), []);

  const list = useMemo(() => Object.values(items), [items]);
  const total = useMemo(() => list.reduce((s, i) => s + (i.invoice.dueAmount || 0), 0), [list]);
  const hasTerm = useMemo(() => list.some((i) => i.isTerm), [list]);

  return { items: list, total, hasTerm, has, toggle, clear };
}
