import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { relativeTime } from '@/services/vfs';
import { getApp } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { useNotificationStore, type AuroraNotification } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';
import { useWindowStore } from '@/system/store/windowStore';

interface Props {
  n: AuroraNotification;
  /** Banner style (toast) vs. list style (center). */
  variant: 'toast' | 'list';
  onClose: () => void;
}

/** One notification. Swipe right to dismiss; actions open the relevant app. */
export function NotificationCard({ n, variant, onClose }: Props) {
  const dismiss = useNotificationStore((s) => s.dismiss);
  const app = getApp(n.appId);

  const act = (open?: Parameters<ReturnType<typeof useWindowStore.getState>['openApp']>[0]) => {
    if (open) {
      useShellStore.getState().closePanel();
      useWindowStore.getState().openApp(open);
    }
    dismiss(n.id);
  };

  return (
    <motion.article
      layout
      aria-label={`${app.name}: ${n.title}`}
      drag="x"
      dragConstraints={{ left: 0, right: 0 }}
      dragElastic={{ left: 0.05, right: 0.9 }}
      onDragEnd={(_, info) => {
        if (info.offset.x > 110 || info.velocity.x > 600) dismiss(n.id);
      }}
      initial={variant === 'toast' ? { opacity: 0, x: 80, scale: 0.92 } : { opacity: 0, y: -8 }}
      animate={{ opacity: 1, x: 0, y: 0, scale: 1 }}
      exit={{ opacity: 0, x: 120, transition: { duration: 0.2 } }}
      transition={springs.elastic}
      className={clsx(
        'group relative w-full cursor-grab touch-pan-y rounded-2xl p-3 active:cursor-grabbing',
        variant === 'toast' ? 'glass acrylic glass-sheen' : 'glass-well',
        n.priority === 'high' && 'ring-1 ring-[color-mix(in_oklab,var(--color-accent)_55%,transparent)]',
      )}
      style={variant === 'toast' ? { boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' } : undefined}
    >
      <div className="flex items-start gap-3">
        <AppIcon appId={n.appId} size={30} />
        <div className="min-w-0 flex-1">
          <div className="flex items-baseline gap-2">
            <span className="truncate text-[11px] font-medium uppercase tracking-wider text-fg-subtle">{app.name}</span>
            {n.priority === 'high' && <span className="rounded-full bg-accent-soft px-1.5 text-[10px] font-semibold text-accent">{n.reason ?? 'Time-sensitive'}</span>}
            <span className="ml-auto shrink-0 text-[11px] text-fg-subtle">{relativeTime(n.time)}</span>
          </div>
          <p className="mt-0.5 text-[13px] font-semibold leading-snug">{n.title}</p>
          <p className="mt-0.5 text-[13px] leading-snug text-fg-muted">{n.body}</p>
          {n.actions && (
            <div className="mt-2.5 flex flex-wrap gap-1.5">
              {n.actions.map((a) => (
                <button
                  key={a.label}
                  onClick={() => act(a.open)}
                  className="rounded-full bg-[color-mix(in_oklab,var(--text-1)_9%,transparent)] px-3 py-1 text-xs font-medium hover:bg-[color-mix(in_oklab,var(--text-1)_15%,transparent)]"
                >
                  {a.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
      <button
        aria-label="Dismiss notification"
        onClick={onClose}
        className="glass absolute -left-1.5 -top-1.5 grid size-5 place-items-center rounded-full opacity-0 transition-opacity focus-visible:opacity-100 group-hover:opacity-100"
      >
        <X className="size-3" />
      </button>
    </motion.article>
  );
}
