import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { X } from 'lucide-react';
import { commands } from '@/services/commands';
import { springs } from '@/system/motion';
import { useShellStore } from '@/system/store/shellStore';
import { useSystemStore } from '@/system/store/systemStore';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';
import { AuroraOrb } from './AuroraOrb';

/**
 * Proactive, context-aware action: when several free-floating windows pile up on a
 * desktop, offer once to tile them. Dismissing it silences that suggestion until the
 * situation changes.
 */
export function ContextNudge() {
  const enabled = useSystemStore((s) => s.aiEnabled && s.aiSuggestions);
  const windows = useWindowStore((s) => s.windows);
  const groups = useWindowStore((s) => s.groups);
  const active = useWindowStore((s) => s.activeDesktopId);
  const busy = useShellStore((s) => !!s.panel || s.overview || s.locked);
  const [dismissedAt, setDismissedAt] = useState(0);

  const loose = Object.values(windows).filter((w) => w.desktopId === active && !w.minimized && w.mode === 'normal' && !isHiddenTab({ groups }, w));
  const show = enabled && !busy && loose.length >= 4 && loose.length > dismissedAt;

  // Re-arm once things calm down.
  useEffect(() => {
    if (loose.length < 3) setDismissedAt(0);
  }, [loose.length]);

  return (
    <AnimatePresence>
      {show && (
        <motion.div
          role="status"
          initial={{ opacity: 0, y: -16, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -10, scale: 0.95 }}
          transition={springs.elastic}
          className="glass acrylic absolute left-1/2 top-12 z-[1100] flex -translate-x-1/2 items-center gap-2.5 rounded-full py-1.5 pl-2 pr-1.5 text-[13px]"
          style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window), 0 0 40px -14px var(--color-accent)' }}
        >
          <AuroraOrb size={20} />
          <span>{loose.length} windows are overlapping.</span>
          <button onClick={commands.tileWindows} className="rounded-full bg-accent px-3 py-1 text-xs font-semibold text-white">
            Tile them
          </button>
          <button aria-label="Dismiss suggestion" onClick={() => setDismissedAt(loose.length)} className="grid size-6 place-items-center rounded-full text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
            <X className="size-3.5" />
          </button>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
