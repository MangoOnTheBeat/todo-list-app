import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Search } from 'lucide-react';
import { SearchResults } from '@/components/ui/SearchResults';
import { useSearchController } from '@/hooks/useSearchController';
import type { SearchResult } from '@/services/search';
import { springs } from '@/system/motion';
import { useShellStore } from '@/system/store/shellStore';

/** Spotlight-style universal search: apps, windows, files, actions, settings, maths. */
export function SearchOverlay() {
  const seed = useShellStore((s) => s.searchSeed);
  const close = useShellStore((s) => s.closePanel);
  const [query, setQuery] = useState(seed);
  const inputRef = useRef<HTMLInputElement>(null);

  const run = (r: SearchResult) => {
    close();
    r.run();
  };
  const { response, active, setActive, onKeyDown } = useSearchController(query, run);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  // Keep the active option scrolled into view.
  useEffect(() => {
    document.getElementById(`search-opt-${active}`)?.scrollIntoView({ block: 'nearest' });
  }, [active]);

  return (
    <motion.div
      role="dialog"
      aria-label="Search"
      initial={{ opacity: 0, y: -16, scale: 0.97 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -10, scale: 0.98, transition: { duration: 0.14 } }}
      transition={springs.panel}
      className="glass acrylic glass-sheen absolute left-1/2 top-[14vh] z-[1300] flex max-h-[min(560px,72vh)] w-[min(640px,calc(100vw-32px))] -translate-x-1/2 flex-col overflow-hidden rounded-[var(--radius-panel)]"
      style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
    >
      <div className="flex items-center gap-3 border-b hairline px-4">
        <Search aria-hidden className="size-5 shrink-0 text-accent" />
        <input
          ref={inputRef}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={onKeyDown}
          role="combobox"
          aria-expanded
          aria-controls="search-list"
          aria-activedescendant={response.flat.length ? `search-opt-${active}` : undefined}
          aria-label="Search Aurora"
          placeholder="Search apps, files, actions — or type 12*7"
          className="h-14 min-w-0 flex-1 bg-transparent text-lg tracking-tight outline-none placeholder:text-fg-subtle"
        />
        <kbd className="glass-well shrink-0 rounded-md px-1.5 py-0.5 font-mono text-[10px] text-fg-subtle">esc</kbd>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto p-2">
        <SearchResults response={response} active={active} onHover={setActive} onRun={run} idPrefix="search" />
      </div>
      <footer className="flex items-center gap-4 border-t hairline px-4 py-2 text-[11px] text-fg-subtle">
        <span>↑↓ to move</span>
        <span>↵ to open</span>
        <span className="ml-auto">Try “schedule lunch friday at 1” or “pdfs from last week”</span>
      </footer>
    </motion.div>
  );
}
