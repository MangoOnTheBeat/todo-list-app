import { useMediaStore } from '@/system/store/mediaStore';
import { useNotificationStore } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';
import { useSystemStore } from '@/system/store/systemStore';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';
import type { SnapZone } from '@/system/types';

/**
 * System commands as plain functions. Search, Quick Settings, keyboard shortcuts and the
 * AI assistant (Phase 4) all invoke the same verbs, so behaviour stays consistent.
 */
export const commands = {
  toggleDarkMode() {
    const s = useSystemStore.getState();
    const isDark = s.theme === 'dark' || (s.theme === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    s.setTheme(isDark ? 'light' : 'dark');
  },
  toggleDnd() {
    const n = useNotificationStore.getState();
    n.setDnd(!n.dnd);
  },
  toggleNightLight() {
    const s = useSystemStore.getState();
    s.set('nightLight', !s.nightLight);
  },
  toggleFocusMode() {
    const s = useSystemStore.getState();
    s.set('focusMode', !s.focusMode);
    // Focus mode implies Do Not Disturb.
    useNotificationStore.getState().setDnd(!s.focusMode);
  },
  newDesktop: () => useWindowStore.getState().addDesktop(),
  overview: () => useShellStore.getState().setOverview(!useShellStore.getState().overview),
  lock: () => useShellStore.getState().lock(),
  playPause: () => useMediaStore.getState().toggle(),
  nextTrack: () => useMediaStore.getState().next(),

  /** Arrange every visible window on the current desktop into a tidy layout. */
  tileWindows() {
    const s = useWindowStore.getState();
    const ids = s.order.filter((id) => {
      const w = s.windows[id];
      return w.desktopId === s.activeDesktopId && !w.minimized && !isHiddenTab(s, w);
    });
    const layouts: Record<number, SnapZone[]> = {
      1: ['maximize'],
      2: ['left', 'right'],
      3: ['left-third', 'center-third', 'right-third'],
      4: ['top-left', 'top-right', 'bottom-left', 'bottom-right'],
    };
    const zones = layouts[Math.min(ids.length, 4)] ?? [];
    // Most recently used windows get the first (largest/leftmost) slots.
    [...ids].reverse().slice(0, 4).forEach((id, i) => s.snapWindow(id, zones[i]));
  },

  minimizeAll() {
    const s = useWindowStore.getState();
    Object.values(s.windows)
      .filter((w) => w.desktopId === s.activeDesktopId)
      .forEach((w) => s.minimizeWindow(w.id));
  },
};
