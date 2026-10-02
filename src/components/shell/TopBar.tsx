import { motion, LayoutGroup } from 'framer-motion';
import { BatteryMedium, LayoutGrid, Plus, Search, Volume2, VolumeX, Wifi, WifiOff } from 'lucide-react';
import clsx from 'clsx';
import { EqBars } from '@/components/ui/CoverArt';
import { getApp } from '@/system/appRegistry';
import { TOPBAR_H } from '@/system/layout';
import { springs } from '@/system/motion';
import { useMediaStore } from '@/system/store/mediaStore';
import { useNotificationStore } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';
import { useSystemStore } from '@/system/store/systemStore';
import { selectFocusedApp, useWindowStore } from '@/system/store/windowStore';
import { useClock } from '@/hooks/useClock';
import auroraMark from '@/assets/aurora-mark.svg?inline';

const pillButton = 'pointer-events-auto transition-colors hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)]';

/**
 * Slim system bar. Floating groups rather than one slab, so the wallpaper shows
 * through the gaps and the bar reads as part of the spatial scene.
 */
export function TopBar() {
  const focusedApp = useWindowStore(selectFocusedApp);
  const { panel, togglePanel, overview, setOverview } = useShellStore();
  const now = useClock();
  const playing = useMediaStore((s) => s.playing);
  const unread = useNotificationStore((s) => s.items.filter((n) => !n.read).length);
  const dnd = useNotificationStore((s) => s.dnd);
  const { wifi, airplane, volume } = useSystemStore();
  const online = wifi && !airplane;

  return (
    <header className="pointer-events-none absolute inset-x-0 top-0 z-[1000] flex items-center justify-between gap-2 px-2.5 pt-1.5" style={{ height: TOPBAR_H }}>
      <div className="glass pointer-events-auto flex h-7 min-w-0 items-center gap-1.5 rounded-full pl-1 pr-1 text-[13px]">
        <motion.button
          whileHover={{ rotate: -8, scale: 1.08 }}
          whileTap={{ scale: 0.9 }}
          transition={springs.elastic}
          aria-label="Launcher"
          aria-expanded={panel === 'launcher'}
          onClick={() => togglePanel('launcher')}
          className="grid size-6 shrink-0 place-items-center rounded-full"
        >
          <img src={auroraMark} alt="" className="size-5 rounded-md" />
        </motion.button>
        <span className="max-w-[28vw] truncate px-1 font-semibold tracking-tight">{focusedApp ? getApp(focusedApp).name : 'Desktop'}</span>
        <button aria-label="Search" aria-expanded={panel === 'search'} onClick={() => togglePanel('search')} className={clsx(pillButton, 'grid size-6 shrink-0 place-items-center rounded-full text-fg-muted')}>
          <Search className="size-3.5" />
        </button>
      </div>

      <div className="flex items-center gap-1.5">
        <button
          aria-label="Overview"
          aria-pressed={overview}
          onClick={() => setOverview(!overview)}
          className={clsx('glass grid size-7 place-items-center rounded-full', pillButton, overview ? 'text-accent' : 'text-fg-muted')}
        >
          <LayoutGrid className="size-3.5" />
        </button>
        <DesktopSwitcher />
      </div>

      <div className="glass pointer-events-auto flex h-7 items-center rounded-full text-[13px] text-fg-muted">
        <button
          aria-label="Quick settings"
          aria-expanded={panel === 'quick'}
          onClick={() => togglePanel('quick')}
          className={clsx(pillButton, 'flex h-full items-center gap-2.5 rounded-full pl-3 pr-2')}
        >
          {playing && <EqBars playing />}
          {online ? <Wifi className="size-3.5" aria-label="Wi-Fi connected" /> : <WifiOff className="size-3.5" aria-label="Offline" />}
          {volume === 0 ? <VolumeX className="size-3.5" /> : <Volume2 className="size-3.5" />}
          <span className="flex items-center gap-1">
            <BatteryMedium className="size-4" />
            <span className="hidden tabular-nums sm:inline">82%</span>
          </span>
        </button>
        <button
          aria-label={`Notifications${unread ? `, ${unread} unread` : ''}`}
          aria-expanded={panel === 'notifications'}
          onClick={() => togglePanel('notifications')}
          className={clsx(pillButton, 'relative flex h-full items-center rounded-full pl-2 pr-3.5')}
        >
          <time className="font-medium tabular-nums text-fg" dateTime={now.toISOString()}>
            <span className="hidden sm:inline">
              {now.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })}
              <span className="mx-1.5 text-fg-subtle">·</span>
            </span>
            {now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}
          </time>
          {(unread > 0 || dnd) && (
            <motion.span
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={springs.elastic}
              className={clsx('absolute right-1 top-1 size-2 rounded-full', dnd ? 'bg-fg-subtle' : 'bg-accent shadow-[0_0_8px_var(--color-accent)]')}
            />
          )}
        </button>
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
              {active && <motion.span layoutId="desktop-pill" transition={springs.snappy} className="absolute inset-0 rounded-full bg-accent shadow-[0_0_14px_-2px_var(--color-accent)]" />}
              <span className="relative tabular-nums">{i + 1}</span>
            </button>
          );
        })}
      </LayoutGroup>
      <button onClick={addDesktop} aria-label="New desktop" className="grid size-5 place-items-center rounded-full text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] hover:text-fg">
        <Plus className="size-3" />
      </button>
    </nav>
  );
}
