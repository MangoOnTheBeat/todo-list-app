import { AnimatePresence, motion } from 'framer-motion';
import { Plus, X } from 'lucide-react';
import clsx from 'clsx';
import { getApp } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { OVERVIEW_STRIP_H, type OverviewSlot } from '@/system/overview';
import { TOPBAR_H } from '@/system/layout';
import { useShellStore } from '@/system/store/shellStore';
import { useWindowStore } from '@/system/store/windowStore';

/**
 * Overview chrome. The windows themselves are the live previews (WindowLayers re-targets
 * them into a grid); this layer adds the dimmed backdrop beneath them and the desktop
 * strip + captions above them.
 */
export function OverviewBackdrop() {
  const on = useShellStore((s) => s.overview);
  return (
    <AnimatePresence>
      {on && (
        <motion.div
          aria-hidden
          className="absolute inset-0 z-[1]"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.3 }}
          style={{ background: 'color-mix(in oklab, var(--wall-base) 45%, transparent)', backdropFilter: 'blur(24px) saturate(140%)' }}
          onClick={() => useShellStore.getState().setOverview(false)}
        />
      )}
    </AnimatePresence>
  );
}

export function OverviewChrome({ slots }: { slots: Map<string, OverviewSlot> }) {
  const on = useShellStore((s) => s.overview);
  const desktops = useWindowStore((s) => s.desktops);
  const activeId = useWindowStore((s) => s.activeDesktopId);
  const windows = useWindowStore((s) => s.windows);
  const { switchDesktop, addDesktop, removeDesktop, closeWindow } = useWindowStore.getState();

  return (
    <AnimatePresence>
      {on && (
        <motion.div key="overview-chrome" className="pointer-events-none absolute inset-0 z-[900]" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.12 } }}>
          <motion.nav
            aria-label="Desktops"
            initial={{ y: -30, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: -30, opacity: 0 }}
            transition={springs.panel}
            className="pointer-events-auto absolute inset-x-0 flex justify-center gap-3 overflow-x-auto px-4"
            style={{ top: TOPBAR_H + 14, height: OVERVIEW_STRIP_H - 10 }}
          >
            {desktops.map((d) => {
              const count = Object.values(windows).filter((w) => w.desktopId === d.id).length;
              const active = d.id === activeId;
              return (
                <div key={d.id} className="group relative shrink-0">
                  <button
                    onClick={() => switchDesktop(d.id)}
                    aria-current={active ? 'page' : undefined}
                    className={clsx(
                      'glass flex h-[64px] w-[112px] flex-col items-start justify-end overflow-hidden rounded-xl p-2 text-left transition-shadow',
                      active && 'ring-2 ring-accent shadow-[0_0_24px_-6px_var(--color-accent)]',
                    )}
                    style={{ background: 'linear-gradient(135deg, color-mix(in oklab, var(--wall-1) 60%, transparent), color-mix(in oklab, var(--wall-2) 60%, transparent))' }}
                  >
                    <span className="text-[11px] font-semibold text-white drop-shadow">{d.name}</span>
                    <span className="text-[10px] text-white/80">{count} {count === 1 ? 'window' : 'windows'}</span>
                  </button>
                  {desktops.length > 1 && (
                    <button
                      aria-label={`Remove ${d.name}`}
                      onClick={() => removeDesktop(d.id)}
                      className="glass absolute -right-1.5 -top-1.5 grid size-5 place-items-center rounded-full opacity-0 transition-opacity focus-visible:opacity-100 group-hover:opacity-100"
                    >
                      <X className="size-3" />
                    </button>
                  )}
                </div>
              );
            })}
            <button onClick={addDesktop} aria-label="New desktop" className="glass grid h-[64px] w-[64px] shrink-0 place-items-center rounded-xl text-fg-muted hover:text-fg">
              <Plus className="size-5" />
            </button>
          </motion.nav>

          {[...slots.entries()].map(([id, slot]) => {
            const w = windows[id];
            if (!w) return null;
            return (
              <motion.div
                key={id}
                initial={{ opacity: 0, y: -6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                transition={{ ...springs.panel, delay: 0.08 }}
                className="absolute flex items-center justify-center gap-1.5"
                style={{ left: slot.slot.x, top: slot.slot.y + slot.slot.h + 8, width: slot.slot.w }}
              >
                <span className="glass max-w-full truncate rounded-full px-3 py-1 text-xs font-medium">
                  {getApp(w.appId).name}
                  {w.title !== getApp(w.appId).name && <span className="text-fg-subtle"> · {w.title}</span>}
                </span>
                <button
                  aria-label={`Close ${w.title}`}
                  onClick={() => closeWindow(id)}
                  className="glass pointer-events-auto grid size-6 shrink-0 place-items-center rounded-full text-fg-muted hover:text-fg"
                >
                  <X className="size-3" />
                </button>
              </motion.div>
            );
          })}

          {slots.size === 0 && (
            <p className="absolute inset-x-0 top-1/2 text-center text-sm text-fg-muted">No open windows on this desktop</p>
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
