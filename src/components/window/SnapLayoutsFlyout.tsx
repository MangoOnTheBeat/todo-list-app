import { motion } from 'framer-motion';
import clsx from 'clsx';
import { springs } from '@/system/motion';
import { SNAP_LAYOUTS } from '@/system/snap';
import { useWindowStore } from '@/system/store/windowStore';

/** Grid of layout templates; clicking a cell snaps the window into that zone. */
export function SnapLayoutsFlyout({ windowId, onClose }: { windowId: string; onClose: () => void }) {
  const snapWindow = useWindowStore((s) => s.snapWindow);
  return (
    <motion.div
      role="menu"
      aria-label="Snap layouts"
      initial={{ opacity: 0, y: -6, scale: 0.94 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -4, scale: 0.97, transition: { duration: 0.12 } }}
      transition={springs.panel}
      onKeyDown={(e) => e.key === 'Escape' && onClose()}
      className="glass acrylic absolute right-0 top-9 z-50 grid w-[264px] origin-top-right grid-cols-2 gap-2.5 rounded-2xl p-3"
    >
      {SNAP_LAYOUTS.map((layout) => (
        <div key={layout.label} className={clsx('grid h-14 gap-1 rounded-lg p-1 glass-well', layout.grid)}>
          {layout.zones.map((zone) => (
            <button
              key={zone}
              role="menuitem"
              aria-label={`${layout.label}: ${zone.replace(/-/g, ' ')}`}
              onClick={() => {
                snapWindow(windowId, zone);
                onClose();
              }}
              className="rounded-[5px] bg-[color-mix(in_oklab,var(--text-1)_14%,transparent)] transition-colors hover:bg-accent focus-visible:bg-accent"
            />
          ))}
        </div>
      ))}
    </motion.div>
  );
}
