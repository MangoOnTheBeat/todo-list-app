import { AnimatePresence, motion } from 'framer-motion';
import { springs } from '@/system/motion';
import { useWindowStore } from '@/system/store/windowStore';

/** The translucent ghost that shows where a dragged window will land. */
export function SnapPreview({ zIndex }: { zIndex: number }) {
  const preview = useWindowStore((s) => s.snapPreview);
  return (
    <AnimatePresence>
      {preview && (
        <motion.div
          key="snap-preview"
          aria-hidden
          className="pointer-events-none absolute left-0 top-0 rounded-[var(--radius-window)] border border-[color-mix(in_oklab,var(--color-accent)_60%,transparent)]"
          style={{
            zIndex,
            background: 'color-mix(in oklab, var(--color-accent) 16%, transparent)',
            backdropFilter: 'blur(14px) saturate(160%)',
            boxShadow: '0 0 60px -10px color-mix(in oklab, var(--color-accent) 55%, transparent), inset 0 1px 0 oklch(1 0 0 / 0.3)',
          }}
          initial={{ opacity: 0, x: preview.rect.x + preview.rect.w * 0.1, y: preview.rect.y + preview.rect.h * 0.1, width: preview.rect.w * 0.8, height: preview.rect.h * 0.8 }}
          animate={{ opacity: 1, x: preview.rect.x, y: preview.rect.y, width: preview.rect.w, height: preview.rect.h }}
          exit={{ opacity: 0, scale: 0.96, transition: { duration: 0.15 } }}
          transition={springs.window}
        />
      )}
    </AnimatePresence>
  );
}
