import { create } from 'zustand';
import { triage } from '@/services/ai/notifications';
import { uid } from '../ids';
import { useSystemStore } from './systemStore';
import type { AppId } from '../types';

export type Priority = 'low' | 'normal' | 'high';

export interface NotificationAction {
  label: string;
  /** Opens/focuses this app when chosen. */
  open?: AppId;
  args?: Record<string, unknown>;
}

export interface AuroraNotification {
  id: string;
  appId: AppId;
  title: string;
  body: string;
  time: number;
  priority: Priority;
  read: boolean;
  actions?: NotificationAction[];
  /** Set by smart triage: lives in the collapsed low-priority bundle. */
  bundled?: boolean;
  /** Why triage changed its priority (shown as a small label). */
  reason?: string;
}

type NewNotification = Omit<AuroraNotification, 'id' | 'time' | 'read' | 'priority'> & {
  priority?: Priority;
  /** Add silently to the center without a banner (e.g. backlog at boot). */
  silent?: boolean;
  time?: number;
};

interface NotificationStore {
  items: AuroraNotification[];
  /** Ids currently shown as banners, newest last. */
  toasts: string[];
  dnd: boolean;

  post: (n: NewNotification) => string;
  dismiss: (id: string) => void;
  dismissToast: (id: string) => void;
  clearApp: (appId: AppId) => void;
  clearAll: () => void;
  markAllRead: () => void;
  setDnd: (on: boolean) => void;
}

const MAX_TOASTS = 3;

export const useNotificationStore = create<NotificationStore>()((set, get) => ({
  items: [],
  toasts: [],
  dnd: false,

  post({ silent, priority: requested = 'normal', time, ...n }) {
    const id = uid('n');
    const sys = useSystemStore.getState();
    const smart = sys.aiEnabled && sys.aiSmartNotifications;
    const t = smart ? triage({ ...n, priority: requested }) : { priority: requested, bundle: false, reason: undefined };
    const priority = t.priority;
    const item: AuroraNotification = { ...n, id, priority, time: time ?? Date.now(), read: false, bundled: t.bundle, reason: smart && priority !== requested ? t.reason : undefined };
    // Do Not Disturb holds banners back, except for high-priority items (they break through).
    // Bundled (low-value) items never interrupt.
    const banner = !silent && !t.bundle && (!get().dnd || priority === 'high');
    set((s) => ({
      items: [item, ...s.items],
      toasts: banner ? [...s.toasts, id].slice(-MAX_TOASTS) : s.toasts,
    }));
    return id;
  },
  dismiss: (id) => set((s) => ({ items: s.items.filter((n) => n.id !== id), toasts: s.toasts.filter((t) => t !== id) })),
  dismissToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t !== id) })),
  clearApp: (appId) =>
    set((s) => {
      const keep = s.items.filter((n) => n.appId !== appId);
      return { items: keep, toasts: s.toasts.filter((t) => keep.some((n) => n.id === t)) };
    }),
  clearAll: () => set({ items: [], toasts: [] }),
  markAllRead: () => set((s) => ({ items: s.items.map((n) => (n.read ? n : { ...n, read: true })) })),
  setDnd: (dnd) => set({ dnd }),
}));
