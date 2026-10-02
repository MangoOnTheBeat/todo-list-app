import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { BellOff, ChevronDown, X } from 'lucide-react';
import { AuroraOrb } from '@/components/assistant/AuroraOrb';
import { digest } from '@/services/ai/notifications';
import { useSystemStore } from '@/system/store/systemStore';
import clsx from 'clsx';
import { useClock } from '@/hooks/useClock';
import { AppIcon } from '@/components/ui/AppIcon';
import { getApp } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { useNotificationStore, type AuroraNotification } from '@/system/store/notificationStore';
import type { AppId } from '@/system/types';
import { NotificationCard } from './NotificationCard';

/** Right-edge sheet: date header, mini calendar, and notifications grouped by app. */
export function NotificationCenter() {
  const { items, dnd, setDnd, clearAll, clearApp, dismiss, markAllRead } = useNotificationStore();
  const now = useClock();
  const smart = useSystemStore((s) => s.aiEnabled && s.aiSmartNotifications);
  const [bundleOpen, setBundleOpen] = useState(false);
  // Read-state snapshot from when the center opened, so the digest describes what was new.
  const [unreadAtOpen] = useState(() => items.filter((n) => !n.read).length);

  useEffect(() => {
    markAllRead();
  }, [markAllRead, items.length]);

  const bundled = smart ? items.filter((n) => n.bundled) : [];
  const main = smart ? [...items.filter((n) => !n.bundled)].sort((a, b) => Number(b.priority === 'high') - Number(a.priority === 'high')) : items;
  const groups = new Map<AppId, AuroraNotification[]>();
  for (const n of main) groups.set(n.appId, [...(groups.get(n.appId) ?? []), n]);
  const summary = smart && items.length >= 2 ? digest(items, (id) => getApp(id).name) : [];

  return (
    <motion.aside
      role="dialog"
      aria-label="Notification center"
      initial={{ opacity: 0, x: 60 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: 60, transition: { duration: 0.18 } }}
      transition={springs.panel}
      className="glass acrylic glass-sheen absolute bottom-[100px] right-2.5 top-11 z-[1300] flex w-[min(380px,calc(100vw-20px))] flex-col overflow-hidden rounded-[var(--radius-panel)]"
      style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
    >
      <header className="px-5 pb-3 pt-5">
        <p className="text-xs font-medium uppercase tracking-[0.14em] text-accent">{now.toLocaleDateString(undefined, { weekday: 'long' })}</p>
        <p className="text-2xl font-semibold tracking-tight">{now.toLocaleDateString(undefined, { month: 'long', day: 'numeric' })}</p>
        <MiniCalendar now={now} />
      </header>

      <div className="flex items-center gap-2 border-y hairline px-5 py-2">
        <h2 className="text-sm font-semibold">Notifications</h2>
        <button
          onClick={() => setDnd(!dnd)}
          aria-pressed={dnd}
          className={clsx('ml-auto flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium', dnd ? 'bg-accent text-white' : 'glass-well text-fg-muted')}
        >
          <BellOff className="size-3" />
          Do Not Disturb
        </button>
        {items.length > 0 && (
          <button onClick={clearAll} className="rounded-full px-2 py-1 text-xs text-fg-muted hover:text-fg">
            Clear all
          </button>
        )}
      </div>

      <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-4 py-4">
        {summary.length > 0 && (
          <section aria-label="Summary" className="rounded-2xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-accent-soft p-3.5">
            <p className="flex items-center gap-2 text-xs font-semibold">
              <AuroraOrb size={16} /> Summary{unreadAtOpen ? ` · ${unreadAtOpen} new` : ''}
            </p>
            <ul className="mt-1.5 space-y-1 text-[12px] leading-relaxed text-fg-muted">
              {summary.map((l) => (
                <li key={l}>{l}</li>
              ))}
            </ul>
          </section>
        )}
        {items.length === 0 && (
          <div className="grid h-full place-items-center text-center">
            <div>
              <p className="text-sm font-medium">You're all caught up</p>
              <p className="mt-1 text-xs text-fg-subtle">New notifications will collect here.</p>
            </div>
          </div>
        )}
        <AnimatePresence initial={false}>
          {[...groups.entries()].map(([appId, list]) => (
            <motion.section key={appId} layout exit={{ opacity: 0, height: 0 }} transition={springs.panel} aria-label={getApp(appId).name}>
              <div className="mb-1.5 flex items-center px-1">
                <span className="text-xs font-semibold text-fg-muted">{getApp(appId).name}</span>
                <span className="ml-1.5 text-[11px] text-fg-subtle">{list.length}</span>
                <button aria-label={`Clear ${getApp(appId).name} notifications`} onClick={() => clearApp(appId)} className="ml-auto grid size-5 place-items-center rounded-full text-fg-subtle hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
                  <X className="size-3" />
                </button>
              </div>
              <div className="space-y-2">
                <AnimatePresence initial={false}>
                  {list.map((n) => (
                    <NotificationCard key={n.id} n={n} variant="list" onClose={() => dismiss(n.id)} />
                  ))}
                </AnimatePresence>
              </div>
            </motion.section>
          ))}
        </AnimatePresence>

        {bundled.length > 0 && (
          <section aria-label="Low priority">
            <button onClick={() => setBundleOpen((v) => !v)} aria-expanded={bundleOpen} className="flex w-full items-center gap-2 rounded-xl px-2 py-1.5 text-xs font-semibold text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]">
              <span className="flex -space-x-1.5">
                {[...new Set(bundled.map((n) => n.appId))].slice(0, 3).map((a) => (
                  <span key={a} className="rounded-md ring-2 ring-[var(--glass-tint)]">
                    <AppIconSmall appId={a} />
                  </span>
                ))}
              </span>
              Low priority · {bundled.length}
              <ChevronDown className={clsx('ml-auto size-3.5 transition-transform', bundleOpen && 'rotate-180')} />
            </button>
            <AnimatePresence initial={false}>
              {bundleOpen && (
                <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="space-y-2 overflow-hidden pt-2">
                  {bundled.map((n) => (
                    <NotificationCard key={n.id} n={n} variant="list" onClose={() => dismiss(n.id)} />
                  ))}
                </motion.div>
              )}
            </AnimatePresence>
          </section>
        )}
      </div>
    </motion.aside>
  );
}

function AppIconSmall({ appId }: { appId: AppId }) {
  return <AppIcon appId={appId} size={16} />;
}

function MiniCalendar({ now }: { now: Date }) {
  const year = now.getFullYear();
  const month = now.getMonth();
  // Monday-first grid.
  const lead = (new Date(year, month, 1).getDay() + 6) % 7;
  const days = new Date(year, month + 1, 0).getDate();
  const cells = [...Array(lead).fill(null), ...Array.from({ length: days }, (_, i) => i + 1)];
  return (
    <div className="mt-3 grid grid-cols-7 gap-y-1 text-center text-[11px]" aria-label={now.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}>
      {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => (
        <span key={i} className="font-medium text-fg-subtle">
          {d}
        </span>
      ))}
      {cells.map((d, i) => (
        <span
          key={i}
          className={clsx(
            'mx-auto grid size-6 place-items-center rounded-full tabular-nums',
            d === now.getDate() ? 'bg-accent font-semibold text-white shadow-[0_0_12px_-2px_var(--color-accent)]' : 'text-fg-muted',
          )}
        >
          {d ?? ''}
        </span>
      ))}
    </div>
  );
}
