import { motion, LayoutGroup } from 'framer-motion';
import { BatteryMedium, Plus, Volume2, Wifi } from 'lucide-react';
import clsx from 'clsx';
import { getApp } from '@/system/appRegistry';
import { TOPBAR_H } from '@/system/layout';
import { springs } from '@/system/motion';
import { selectFocusedApp, useWindowStore } from '@/system/store/windowStore';
import { useClock } from '@/hooks/useClock';
import auroraMark from '@/assets/aurora-mark.svg';

/**
 * Slim system bar. Three floating groups rather than one slab, so the wallpaper shows
 * through the gaps and the bar reads as part of the spatial scene.
 */
export function TopBar() {
  const focusedApp = useWindowStore(selectFocusedApp);
  const now = useClock();

  return (
    <header
      className="pointer-events-none absolute inset-x-0 top-0 z-[1000] flex items-center justify-between gap-3 px-2.5 pt-1.5"
      style={{ height: TOPBAR_H }}
    >
      <div className="glass pointer-events-auto flex h-7 items-center gap-2 rounded-full pl-1 pr-3.5 text-[13px]">
        <motion.button
          whileHover={{ rotate: -8, scale: 1.08 }}
          whileTap={{ scale: 0.9 }}
          transition={springs.elastic}
          aria-label="Aurora menu"
          onClick={() => useWindowStore.getState().openApp('welcome')}
          className="grid size-6 place-items-center rounded-full"
        >
          <img src={auroraMark} alt="" className="size-5 rounded-md" />
        </motion.button>
        <span className="font-semibold tracking-tight">{focusedApp ? getApp(focusedApp).name : 'Desktop'}</span>
      </div>

      <DesktopSwitcher />

      <div className="glass pointer-events-auto flex h-7 items-center gap-3 rounded-full px-3.5 text-[13px] text-fg-muted">
        <Wifi className="size-3.5" aria-label="Wi-Fi connected" />
        <Volume2 className="size-3.5" aria-label="Volume" />
        <span className="flex items-center gap-1" aria-label="Battery 82 percent">
          <BatteryMedium className="size-4" />
          <span className="tabular-nums">82%</span>
        </span>
        <time className="font-medium tabular-nums text-fg" dateTime={now.toISOString()}>
          {now.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })}
          <span className="mx-1.5 text-fg-subtle">·</span>
          {now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}
        </time>
      </div>
    </header>
  );
}

function DesktopSwitcher() {
  const desktops = useWindowStore((s) => s.desktops);
  const activeId = useWindowStore((s) => s.activeDesktopId);
  const windows = useWindowStore((s) => s.windows);
  const { switchDesktop, addDesktop, removeDesktop } = useWindowStore.getState();

  return (
    <nav aria-label="Virtual desktops" className="glass pointer-events-auto flex h-7 items-center gap-1 rounded-full px-1">
      <LayoutGroup id="desktops">
        {desktops.map((d, i) => {
          const active = d.id === activeId;
          const count = Object.values(windows).filter((w) => w.desktopId === d.id).length;
          return (
            <button
              key={d.id}
              onClick={() => switchDesktop(d.id)}
              onAuxClick={(e) => e.button === 1 && removeDesktop(d.id)}
              aria-current={active ? 'page' : undefined}
              aria-label={`${d.name}, ${count} windows${desktops.length > 1 ? '. Middle-click to remove' : ''}`}
              className={clsx('relative h-5 rounded-full px-2.5 text-[11px] font-medium transition-colors', active ? 'text-white' : 'text-fg-muted hover:text-fg')}
            >
              {active && (
                <motion.span
                  layoutId="desktop-pill"
                  transition={springs.snappy}
                  className="absolute inset-0 rounded-full bg-accent shadow-[0_0_14px_-2px_var(--color-accent)]"
                />
              )}
              <span className="relative tabular-nums">{i + 1}</span>
            </button>
          );
        })}
      </LayoutGroup>
      <button
        onClick={addDesktop}
        aria-label="New desktop"
        className="grid size-5 place-items-center rounded-full text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] hover:text-fg"
      >
        <Plus className="size-3" />
      </button>
    </nav>
  );
}
