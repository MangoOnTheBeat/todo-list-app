import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { getApp } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';
import type { AppId } from '@/system/types';

/**
 * Window previews for a dock app: one mini frame per window, drawn to the window's real
 * aspect ratio and tinted with the app's colours. Click to jump to it (switching desktop
 * if needed); × closes it.
 */
export function DockPreviews({ appId }: { appId: AppId }) {
  const all = useWindowStore((s) => s.windows);
  const windows = Object.values(all).filter((w) => w.appId === appId);
  const s = useWindowStore.getState();
  const app = getApp(appId);
  const [from, to] = app.gradient;

  return (
    <motion.div
      role="menu"
      aria-label={`${app.name} windows`}
      initial={{ opacity: 0, y: 10, scale: 0.92 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: 6, scale: 0.95, transition: { duration: 0.12 } }}
      transition={springs.panel}
      className="glass acrylic absolute bottom-full mb-3 flex origin-bottom gap-2 rounded-2xl p-2"
      style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
    >
      {windows.map((w) => {
        const aspect = w.rect.w / w.rect.h;
        const h = 84;
        const width = Math.max(100, Math.min(170, h * aspect));
        const desk = s.desktops.find((d) => d.id === w.desktopId);
        const focused = s.focusedId === w.id;
        return (
          <div key={w.id} className="group relative">
            <button
              role="menuitem"
              onClick={() => {
                const st = useWindowStore.getState();
                if (w.desktopId !== st.activeDesktopId) st.switchDesktop(w.desktopId);
                st.focusWindow(w.id);
              }}
              className={clsx('flex flex-col gap-1.5 rounded-xl p-1.5 text-left hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)]', focused && 'bg-[color-mix(in_oklab,var(--color-accent)_14%,transparent)]')}
            >
              <span
                className="relative block overflow-hidden rounded-lg border hairline"
                style={{ width, height: h, background: `linear-gradient(150deg, color-mix(in oklab, ${from} 35%, var(--glass-tint)), color-mix(in oklab, ${to} 25%, var(--glass-tint)))`, opacity: w.minimized ? 0.55 : 1 }}
              >
                {/* Mini title bar + content skeleton */}
                <span className="absolute inset-x-0 top-0 flex h-3.5 items-center gap-1 bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] px-1.5">
                  <span className="size-1.5 rounded-full bg-fg-subtle" />
                  <span className="h-1 w-8 rounded-full bg-fg-subtle/60" />
                </span>
                <span className="absolute inset-0 grid place-items-center pt-3">
                  <AppIcon appId={appId} size={26} />
                </span>
              </span>
              <span className="max-w-[170px] truncate px-0.5 text-[11px] font-medium" style={{ width }}>
                {w.title}
              </span>
              <span className="px-0.5 text-[10px] text-fg-subtle">
                {desk?.name}
                {w.minimized ? ' · minimised' : isHiddenTab(s, w) ? ' · tab' : ''}
              </span>
            </button>
            <button
              aria-label={`Close ${w.title}`}
              onClick={() => useWindowStore.getState().closeWindow(w.id)}
              className="glass absolute -right-1 -top-1 grid size-5 place-items-center rounded-full opacity-0 transition-opacity focus-visible:opacity-100 group-hover:opacity-100"
            >
              <X className="size-3" />
            </button>
          </div>
        );
      })}
    </motion.div>
  );
}
