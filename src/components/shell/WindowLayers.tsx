import { AnimatePresence, motion } from 'framer-motion';
import { Window } from '@/components/window/Window';
import { SnapPreview } from '@/components/window/SnapPreview';
import { springs } from '@/system/motion';
import { useWindowStore } from '@/system/store/windowStore';

/**
 * One layer per virtual desktop, laid out side by side. Switching desktops slides the
 * strip and recedes the outgoing layer in depth. Inactive layers stay mounted (apps keep
 * their state) but are hidden and `inert` once off-screen.
 */
export function WindowLayers() {
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
                <Window key={id} id={id} depth={ids.length - 1 - idx} zIndex={10 + idx * 2} />
              ))}
            </AnimatePresence>
            {active && <SnapPreview zIndex={10 + (ids.length - 1) * 2 - 1} />}
          </motion.div>
        );
      })}
    </>
  );
}
