import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Lock, Search, Settings2 } from 'lucide-react';
import { AppIcon } from '@/components/ui/AppIcon';
import { SearchResults } from '@/components/ui/SearchResults';
import { useSearchController } from '@/hooks/useSearchController';
import type { SearchResult } from '@/services/search';
import { fileIcon } from '@/services/search/providers';
import { appForFile, relativeTime } from '@/services/vfs';
import { recentFiles } from '@/system/store/fileStore';
import { allApps } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { useShellStore } from '@/system/store/shellStore';
import { useWindowStore } from '@/system/store/windowStore';

const grid = { animate: { transition: { staggerChildren: 0.018, delayChildren: 0.05 } } };
const cell = { initial: { opacity: 0, y: 10, scale: 0.9 }, animate: { opacity: 1, y: 0, scale: 1, transition: springs.snappy } };

/** The Aurora launcher: rises from the dock with apps, recent files and a search field. */
export function Launcher() {
  const close = useShellStore((s) => s.closePanel);
  const lock = useShellStore((s) => s.lock);
  const openApp = useWindowStore((s) => s.openApp);
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const launch = (fn: () => void) => {
    close();
    fn();
  };
  const run = (r: SearchResult) => launch(r.run);
  const { response, active, setActive, onKeyDown } = useSearchController(query, run);

  useEffect(() => inputRef.current?.focus(), []);

  return (
    <motion.div
      role="dialog"
      aria-label="Launcher"
      initial={{ opacity: 0, y: 40, scale: 0.94 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: 30, scale: 0.96, transition: { duration: 0.16 } }}
      transition={springs.panel}
      className="glass acrylic glass-sheen absolute bottom-[100px] left-1/2 z-[1300] flex max-h-[calc(100vh-150px)] w-[min(620px,calc(100vw-32px))] -translate-x-1/2 origin-bottom flex-col overflow-hidden rounded-[28px]"
      style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
    >
      <div className="p-5 pb-3">
        <div className="glass-well flex h-11 items-center gap-2.5 rounded-full px-4">
          <Search aria-hidden className="size-4 text-fg-subtle" />
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={onKeyDown}
            role="combobox"
            aria-expanded={!!query}
            aria-controls="launch-list"
            aria-activedescendant={query && response.flat.length ? `launch-opt-${active}` : undefined}
            aria-label="Search apps and files"
            placeholder="Type to search apps, files and actions"
            className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-fg-subtle"
          />
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-5 pb-4">
        {query ? (
          <SearchResults response={response} active={active} onHover={setActive} onRun={run} idPrefix="launch" />
        ) : (
          <>
            <h2 className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-fg-subtle">Apps</h2>
            <motion.ul variants={grid} initial="initial" animate="animate" className="grid grid-cols-4 gap-1 sm:grid-cols-6">
              {allApps.map((a) => (
                <motion.li key={a.id} variants={cell}>
                  <motion.button
                    whileHover={{ y: -3 }}
                    whileTap={{ scale: 0.92 }}
                    transition={springs.snappy}
                    onClick={() => launch(() => openApp(a.id))}
                    className="flex w-full flex-col items-center gap-1.5 rounded-2xl px-1 py-2.5 hover:bg-[color-mix(in_oklab,var(--text-1)_6%,transparent)]"
                  >
                    <AppIcon appId={a.id} size={46} />
                    <span className="w-full truncate text-center text-[11px] text-fg-muted">{a.name}</span>
                  </motion.button>
                </motion.li>
              ))}
            </motion.ul>

            <h2 className="mb-2 mt-5 text-xs font-semibold uppercase tracking-[0.12em] text-fg-subtle">Recent</h2>
            <ul className="grid gap-1 sm:grid-cols-2">
              {recentFiles(4).map((f) => {
                const Icon = fileIcon[f.kind];
                return (
                  <li key={f.id}>
                    <button
                      onClick={() => launch(() => openApp(appForFile(f.kind), { args: { fileId: f.id } }))}
                      className="flex w-full items-center gap-3 rounded-xl p-2 text-left hover:bg-[color-mix(in_oklab,var(--text-1)_6%,transparent)]"
                    >
                      <span className="glass-well grid size-9 shrink-0 place-items-center rounded-lg text-accent">
                        <Icon className="size-4" />
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-[13px] font-medium">{f.name}</span>
                        <span className="block text-[11px] text-fg-subtle">{relativeTime(f.modified)}</span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          </>
        )}
      </div>

      <footer className="flex items-center gap-3 border-t hairline px-5 py-3">
        <span
          aria-hidden
          className="grid size-8 place-items-center rounded-full text-xs font-semibold text-white"
          style={{ background: 'linear-gradient(135deg, oklch(0.75 0.14 200), var(--color-accent))' }}
        >
          AG
        </span>
        <span className="text-[13px] font-medium">Aurora Guest</span>
        <div className="ml-auto flex gap-1">
          <FooterButton label="Settings" onClick={() => launch(() => openApp('settings'))}>
            <Settings2 className="size-4" />
          </FooterButton>
          <FooterButton label="Lock" onClick={lock}>
            <Lock className="size-4" />
          </FooterButton>
        </div>
      </footer>
    </motion.div>
  );
}

function FooterButton({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <button aria-label={label} title={label} onClick={onClick} className="grid size-8 place-items-center rounded-full text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] hover:text-fg">
      {children}
    </button>
  );
}
