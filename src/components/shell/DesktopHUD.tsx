import { useEffect, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { springs } from '@/system/motion';
import { useWindowStore } from '@/system/store/windowStore';

/** Brief on-screen indicator when the active desktop changes (also announced to screen readers). */
export function DesktopHUD() {
  const activeId = useWindowStore((s) => s.activeDesktopId);
  const desktops = useWindowStore((s) => s.desktops);
  const [visible, setVisible] = useState(false);
  const first = useRef(true);

  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    setVisible(true);
    const t = setTimeout(() => setVisible(false), 900);
    return () => clearTimeout(t);
  }, [activeId]);

  const idx = desktops.findIndex((d) => d.id === activeId);
  const name = desktops[idx]?.name ?? '';

  return (
    <>
      <div className="sr-only" aria-live="polite">
        {name}
      </div>
      <AnimatePresence>
        {visible && (
          <motion.div
            key={activeId}
            aria-hidden
            initial={{ opacity: 0, scale: 0.85, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.2 } }}
            transition={springs.elastic}
            className="glass acrylic pointer-events-none absolute left-1/2 top-1/2 z-[1100] -ml-[110px] -mt-12 flex w-[220px] flex-col items-center gap-3 rounded-3xl px-6 py-5"
          >
            <div className="flex gap-1.5">
              {desktops.map((d, i) => (
                <span key={d.id} className="h-1.5 rounded-full transition-all" style={{ width: i === idx ? 22 : 8, background: i === idx ? 'var(--color-accent)' : 'var(--glass-border)' }} />
              ))}
            </div>
            <span className="text-sm font-semibold tracking-tight">{name}</span>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
