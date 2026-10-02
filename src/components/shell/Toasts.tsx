import { useEffect, useRef } from 'react';
import { AnimatePresence } from 'framer-motion';
import { useNotificationStore } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';
import { NotificationCard } from './NotificationCard';

const LIFETIME = 6000;

/** Banner stack. Each banner retires itself after a while unless hovered. */
export function Toasts() {
  const toasts = useNotificationStore((s) => s.toasts);
  const items = useNotificationStore((s) => s.items);
  const dismissToast = useNotificationStore((s) => s.dismissToast);
  const hidden = useShellStore((s) => s.panel === 'notifications' || s.locked);

  return (
    <div aria-live="polite" className="pointer-events-none absolute right-3 top-12 z-[1250] flex w-[min(360px,calc(100vw-24px))] flex-col gap-2">
      <AnimatePresence>
        {!hidden &&
          toasts.map((id) => {
            const n = items.find((x) => x.id === id);
            return n ? <Toast key={id} id={id} onExpire={() => dismissToast(id)} n={n} /> : null;
          })}
      </AnimatePresence>
    </div>
  );
}

function Toast({ id, n, onExpire }: { id: string; n: Parameters<typeof NotificationCard>[0]['n']; onExpire: () => void }) {
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const start = () => {
    clearTimeout(timer.current);
    timer.current = setTimeout(onExpire, n.priority === 'high' ? LIFETIME * 1.6 : LIFETIME);
  };
  useEffect(() => {
    start();
    return () => clearTimeout(timer.current);
  }, [id]);
  return (
    <div className="pointer-events-auto" onMouseEnter={() => clearTimeout(timer.current)} onMouseLeave={start}>
      <NotificationCard n={n} variant="toast" onClose={onExpire} />
    </div>
  );
}
