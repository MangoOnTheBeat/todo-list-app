import { useMemo } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { OverviewBackdrop } from './Overview';
import { Window } from '@/components/window/Window';
import { SnapPreview } from '@/components/window/SnapPreview';
import { springs } from '@/system/motion';
import { overviewLayout, type OverviewSlot } from '@/system/overview';
import { useShellStore } from '@/system/store/shellStore';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';

/**
 * One layer per virtual desktop, laid out side by side. Switching desktops slides the
 * strip and recedes the outgoing layer in depth. Inactive layers stay mounted (apps keep
 * their state) but are hidden and `inert` once off-screen.
 */
export function WindowLayers({ slots }: { slots: Map<string, OverviewSlot> }) {
  const desktops = useWindowStore((s) => s.desktops);
  const activeId = useWindowStore((s) => s.activeDesktopId);
  const order = useWindowStore((s) => s.order);
  const windows = useWindowStore((s) => s.windows);
  const activeIdx = desktops.findIndex((d) => d.id === activeId);

  return (
    <>
      {desktops.map((desk, i) => {
        const active = i === activeIdx;
        const ids = order.filter((id) => windows[id]?.desktopId === desk.id);
        return (
          <motion.div
            key={desk.id}
            aria-label={desk.name}
            inert={!active}
            className="absolute inset-0"
            initial={false}
            animate={
              active
                ? { x: '0%', scale: 1, opacity: 1, visibility: 'visible' }
                : { x: `${(i - activeIdx) * 100}%`, scale: 0.9, opacity: 0.4, transitionEnd: { visibility: 'hidden' } }
            }
            transition={springs.gentle}
          >
            <AnimatePresence>
              {ids.map((id, idx) => (
                <Window key={id} id={id} depth={ids.length - 1 - idx} zIndex={10 + idx * 2} overview={active ? slots.get(id) : undefined} />
              ))}
            </AnimatePresence>
            {active && <SnapPreview zIndex={10 + (ids.length - 1) * 2 - 1} />}
            {active && <OverviewBackdrop />}
          </motion.div>
        );
      })}
    </>
  );
}

/** Live-preview grid targets for the active desktop while Overview is open. */
export function useOverviewSlots() {
  const on = useShellStore((s) => s.overview);
  const windows = useWindowStore((s) => s.windows);
  const groups = useWindowStore((s) => s.groups);
  const activeId = useWindowStore((s) => s.activeDesktopId);
  const display = useWindowStore((s) => s.displays[0]);
  return useMemo(() => {
    if (!on) return new Map<string, OverviewSlot>();
    const visible = Object.values(windows)
      .filter((w) => w.desktopId === activeId && !w.minimized && !isHiddenTab({ groups }, w))
      .sort((a, b) => a.createdAt - b.createdAt);
    return overviewLayout(visible, display.bounds);
  }, [on, windows, groups, activeId, display]);
}
