import { useEffect, useRef, useState } from 'react';
import { AnimatePresence, motion, useAnimationControls, useMotionValue, useSpring, useTransform, type MotionValue } from 'framer-motion';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { getApp, pinnedApps } from '@/system/appRegistry';
import { dockRegistry } from '@/system/dockRegistry';
import { springs } from '@/system/motion';
import { useSystemStore } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppId } from '@/system/types';

const BASE = 46;
const MAX = 70;
const RANGE = 150;

/**
 * Floating dock with distance-based magnification. Pointer x is a single motion value;
 * each icon derives its size from its distance to it through a spring, so magnification
 * is smooth at any refresh rate and never re-renders React.
 */
export function Dock() {
  const mouseX = useMotionValue(Infinity);
  const windows = useWindowStore((s) => s.windows);
  const activeDesk = useWindowStore((s) => s.activeDesktopId);
  const running = new Set(Object.values(windows).map((w) => w.appId));
  const pinnedIds = pinnedApps.map((a) => a.id);
  const extra = [...running].filter((id) => !pinnedIds.includes(id));

  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-3 z-[1000] flex origin-bottom justify-center max-[560px]:scale-[0.76]">
      <motion.nav
        aria-label="Dock"
        onMouseMove={(e) => mouseX.set(e.clientX)}
        onMouseLeave={() => mouseX.set(Infinity)}
        initial={{ y: 90, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ ...springs.elastic, delay: 0.25 }}
        className="glass glass-sheen pointer-events-auto relative flex items-end gap-2 rounded-[26px] px-2.5 pb-2 pt-2"
        style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
      >
        {pinnedIds.map((id) => (
          <DockIcon key={id} appId={id} mouseX={mouseX} running={running.has(id)} activeDesk={activeDesk} />
        ))}
        <AnimatePresence>
          {extra.length > 0 && (
            <motion.div
              key="sep"
              initial={{ opacity: 0, scaleY: 0 }}
              animate={{ opacity: 1, scaleY: 1 }}
              exit={{ opacity: 0, scaleY: 0 }}
              className="mx-1 mb-1.5 h-9 w-px self-end bg-[var(--glass-border)]"
            />
          )}
          {extra.map((id) => (
            <motion.div
              key={id}
              initial={{ opacity: 0, scale: 0.4, width: 0 }}
              animate={{ opacity: 1, scale: 1, width: 'auto' }}
              exit={{ opacity: 0, scale: 0.4, width: 0 }}
              transition={springs.elastic}
            >
              <DockIcon appId={id} mouseX={mouseX} running activeDesk={activeDesk} />
            </motion.div>
          ))}
        </AnimatePresence>
      </motion.nav>
    </div>
  );
}

function DockIcon({ appId, mouseX, running, activeDesk }: { appId: AppId; mouseX: MotionValue<number>; running: boolean; activeDesk: string }) {
  const ref = useRef<HTMLButtonElement>(null);
  const magnify = useSystemStore((s) => s.dockMagnification && !s.reduceMotion);
  const focusedApp = useWindowStore((s) => (s.focusedId ? s.windows[s.focusedId]?.appId : null));
  const controls = useAnimationControls();
  const [hover, setHover] = useState(false);
  const app = getApp(appId);

  const distance = useTransform(mouseX, (mx) => {
    const r = ref.current?.getBoundingClientRect();
    return r ? mx - (r.x + r.width / 2) : Infinity;
  });
  const target = useTransform(distance, [-RANGE, 0, RANGE], [BASE, magnify ? MAX : BASE, BASE], { clamp: true });
  const size = useSpring(target, { mass: 0.12, stiffness: 220, damping: 15 });
  const lift = useTransform(size, [BASE, MAX], [0, -8]);

  useEffect(() => dockRegistry.register(appId, () => ref.current?.getBoundingClientRect()), [appId]);

  const onClick = () => {
    const s = useWindowStore.getState();
    const mine = s.order.map((id) => s.windows[id]).filter((w) => w.appId === appId);
    const here = mine.filter((w) => w.desktopId === activeDesk);
    if (mine.length === 0) {
      // Launch bounce: elastic hop that signals "starting".
      controls.start({ y: [0, -18, 0, -7, 0], transition: { duration: 0.7, times: [0, 0.3, 0.55, 0.75, 1] } });
      s.openApp(appId);
      return;
    }
    const top = here[here.length - 1] ?? mine[mine.length - 1];
    if (top.desktopId !== s.activeDesktopId) s.switchDesktop(top.desktopId);
    if (s.focusedId === top.id && !top.minimized) s.minimizeWindow(top.id);
    else s.focusWindow(top.id);
  };

  const isFocused = focusedApp === appId;

  return (
    <motion.div className="relative flex flex-col items-center" style={{ y: lift }} animate={controls}>
      <AnimatePresence>
        {hover && (
          <motion.span
            role="tooltip"
            initial={{ opacity: 0, y: 6, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 4, scale: 0.95, transition: { duration: 0.1 } }}
            transition={springs.snappy}
            className="glass acrylic pointer-events-none absolute -top-10 whitespace-nowrap rounded-lg px-2.5 py-1 text-xs font-medium"
          >
            {app.name}
          </motion.span>
        )}
      </AnimatePresence>
      <motion.button
        ref={ref}
        onClick={onClick}
        onHoverStart={() => setHover(true)}
        onHoverEnd={() => setHover(false)}
        onFocus={() => setHover(true)}
        onBlur={() => setHover(false)}
        whileTap={{ scale: 0.86 }}
        aria-label={`${app.name}${running ? ', running' : ''}`}
        aria-pressed={isFocused}
        className="rounded-[26%] outline-offset-4"
        style={{ width: size, height: size }}
      >
        <SizedIcon appId={appId} size={size} />
      </motion.button>
      <motion.span
        aria-hidden
        className={clsx('mt-1 h-1 rounded-full', running ? 'bg-fg' : 'bg-transparent')}
        animate={{ width: isFocused ? 14 : running ? 4 : 0, opacity: running ? (isFocused ? 1 : 0.55) : 0 }}
        transition={springs.snappy}
        style={isFocused ? { background: 'var(--color-accent)', boxShadow: '0 0 8px var(--color-accent)' } : undefined}
      />
    </motion.div>
  );
}

/** Renders the tile at the spring-driven size by scaling a fixed-size icon (cheap, crisp). */
function SizedIcon({ appId, size }: { appId: AppId; size: MotionValue<number> }) {
  const scale = useTransform(size, (s) => s / MAX);
  return (
    <motion.div style={{ scale, transformOrigin: 'top left', width: MAX, height: MAX }}>
      <AppIcon appId={appId} size={MAX} />
    </motion.div>
  );
}
