import { useDeferredValue, useEffect, useMemo, useState } from 'react';
import { search, type SearchResult } from '@/services/search';

/** Query → ranked results, plus arrow-key / Enter handling for a combobox input. */
export function useSearchController(query: string, onRun: (r: SearchResult) => void) {
  const deferred = useDeferredValue(query);
  const response = useMemo(() => search(deferred), [deferred]);
  const [active, setActive] = useState(0);

  useEffect(() => setActive(0), [deferred]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    const n = response.flat.length;
    if (!n && e.key !== 'Enter') return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((a) => (a + 1) % n);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((a) => (a - 1 + n) % n);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      // Results render from a deferred query; if typing outpaced them, rank the live
      // query now so Enter never runs a stale result.
      const r = query === deferred ? response.flat[active] : search(query).flat[0];
      if (r) onRun(r);
    }
  };

  return { response, active, setActive, onKeyDown };
}
