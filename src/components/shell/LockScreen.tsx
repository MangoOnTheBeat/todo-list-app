import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { Lock } from 'lucide-react';
import { MediaCard } from '@/components/ui/MediaCard';
import { useClock } from '@/hooks/useClock';
import { springs } from '@/system/motion';
import { useMediaStore } from '@/system/store/mediaStore';
import { useNotificationStore } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';

/** Glass lock screen over the live desktop. Any click or key slides it away. */
export function LockScreen() {
  const locked = useShellStore((s) => s.locked);
  const unlock = useShellStore((s) => s.unlock);
  const now = useClock();
  const unread = useNotificationStore((s) => s.items.filter((n) => !n.read).length);
  const hasMedia = useMediaStore((s) => s.playing || s.position > 0);

  useEffect(() => {
    if (!locked) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Tab') return;
      e.preventDefault();
      unlock();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [locked, unlock]);

  return (
    <AnimatePresence>
      {locked && (
        <motion.div
          role="dialog"
          aria-modal
          aria-label="Locked"
          className="absolute inset-0 z-[2000] flex flex-col items-center overflow-hidden px-4"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ y: '-100%', transition: { ...springs.gentle } }}
          transition={{ duration: 0.4 }}
          style={{ background: 'color-mix(in oklab, var(--wall-base) 35%, transparent)', backdropFilter: 'blur(48px) saturate(150%)' }}
          onClick={(e) => (e.target as HTMLElement).closest('[data-lock-keep]') || unlock()}
        >
          <motion.div initial={{ y: 30, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ ...springs.gentle, delay: 0.1 }} className="mt-[14vh] text-center">
            <Lock aria-hidden className="mx-auto mb-4 size-4 text-fg-muted" />
            <p className="text-base font-medium text-fg-muted">{now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</p>
            <p className="font-semibold leading-none tracking-[-0.04em] tabular-nums" style={{ fontSize: 'clamp(64px, 14vw, 148px)' }}>
              {now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' }).replace(/\s?[AP]M$/i, '')}
            </p>
            {unread > 0 && <p className="mt-4 text-sm text-fg-muted">{unread} new {unread === 1 ? 'notification' : 'notifications'}</p>}
          </motion.div>

          {hasMedia && (
            <motion.div data-lock-keep initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ ...springs.gentle, delay: 0.2 }} className="glass mt-8 w-[min(340px,100%)] rounded-3xl p-2">
              <MediaCard compact />
            </motion.div>
          )}

          <motion.p
            className="absolute bottom-10 text-sm text-fg-muted"
            animate={{ opacity: [0.4, 1, 0.4] }}
            transition={{ duration: 2.4, repeat: Infinity }}
          >
            Click or press any key to unlock
          </motion.p>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
