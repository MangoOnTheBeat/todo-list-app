import { useEffect } from 'react';
import { voice } from '@/services/ai/voice';
import { commands } from '@/services/commands';
import { useShellStore } from '@/system/store/shellStore';
import { useWindowStore } from '@/system/store/windowStore';

function isEditable(t: EventTarget | null) {
  const el = t as HTMLElement | null;
  return !!el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName));
}

/**
 * System keyboard shortcuts. Chosen to avoid browser-reserved combos (Alt+Tab, Ctrl+W…):
 *   Ctrl+Alt+←/→        switch virtual desktop
 *   Ctrl+Alt+Shift+←/→  move focused window to neighbouring desktop
 *   Ctrl+Shift+←/→      snap focused window left/right
 *   Ctrl+Shift+↑        maximize / restore
 *   Ctrl+Shift+↓        minimize (or restore from maximized)
 *   Alt+` / Alt+Shift+` cycle window focus
 *   Ctrl+Shift+X        close focused window
 */
export const SHORTCUTS: { keys: string; action: string }[] = [
  { keys: 'Ctrl K', action: 'Search' },
  { keys: 'Ctrl J', action: 'Aurora AI' },
  { keys: 'Ctrl Alt V', action: 'Voice command' },
  { keys: 'Ctrl Alt A', action: 'Launcher' },
  { keys: 'Ctrl Alt ↑', action: 'Overview' },
  { keys: 'Ctrl Alt N', action: 'Notifications' },
  { keys: 'Ctrl Alt Q', action: 'Quick settings' },
  { keys: 'Ctrl Alt L', action: 'Lock' },
  { keys: 'Ctrl Alt ← →', action: 'Switch desktop' },
  { keys: 'Ctrl Alt Shift ← →', action: 'Move window to desktop' },
  { keys: 'Ctrl Shift ← →', action: 'Snap left / right' },
  { keys: 'Ctrl Shift ↑', action: 'Maximize / restore' },
  { keys: 'Ctrl Shift ↓', action: 'Minimize' },
  { keys: 'Alt `', action: 'Cycle windows' },
  { keys: 'Ctrl Shift X', action: 'Close window' },
];

export function useGlobalShortcuts() {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const shell = useShellStore.getState();
      if (shell.locked) return; // LockScreen owns the keyboard.

      if (e.key === 'Escape' && (shell.panel || shell.overview)) {
        e.preventDefault();
        if (shell.panel) shell.closePanel();
        else shell.setOverview(false);
        return;
      }
      if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        shell.togglePanel('search');
        return;
      }
      if ((e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.key.toLowerCase() === 'j') {
        e.preventDefault();
        shell.togglePanel('assistant');
        return;
      }
      if (e.ctrlKey && e.altKey && e.key.toLowerCase() === 'v') {
        e.preventDefault();
        voice.toggle();
        return;
      }
      if (e.key === 'MediaPlayPause') {
        commands.playPause();
        return;
      }
      if (e.ctrlKey && e.altKey && !e.shiftKey) {
        const map: Record<string, () => void> = {
          a: () => shell.togglePanel('launcher'),
          n: () => shell.togglePanel('notifications'),
          q: () => shell.togglePanel('quick'),
          l: () => shell.lock(),
          ArrowUp: () => shell.setOverview(true),
          ArrowDown: () => shell.setOverview(false),
        };
        const fn = map[e.key.length === 1 ? e.key.toLowerCase() : e.key];
        if (fn) {
          e.preventDefault();
          fn();
          return;
        }
      }

      const s = useWindowStore.getState();
      const id = s.focusedId;
      const win = id ? s.windows[id] : undefined;

      if (e.ctrlKey && e.altKey && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) {
        e.preventDefault();
        const dir = e.key === 'ArrowLeft' ? -1 : 1;
        if (e.shiftKey && win) {
          const idx = s.desktops.findIndex((d) => d.id === win.desktopId);
          const target = s.desktops[idx + dir];
          if (target) {
            s.moveWindowToDesktop(win.id, target.id);
            s.switchDesktop(target.id);
            useWindowStore.getState().focusWindow(win.id);
          }
        } else {
          s.switchDesktopRelative(dir);
        }
        return;
      }

      if (e.altKey && !e.ctrlKey && e.code === 'Backquote') {
        e.preventDefault();
        s.cycleFocus(e.shiftKey ? -1 : 1);
        return;
      }

      if (!win || isEditable(e.target) || !(e.ctrlKey && e.shiftKey) || e.altKey) return;
      switch (e.key) {
        case 'ArrowLeft':
          e.preventDefault();
          s.snapWindow(win.id, 'left');
          break;
        case 'ArrowRight':
          e.preventDefault();
          s.snapWindow(win.id, 'right');
          break;
        case 'ArrowUp':
          e.preventDefault();
          s.toggleMaximize(win.id);
          break;
        case 'ArrowDown':
          e.preventDefault();
          if (win.mode === 'normal') s.minimizeWindow(win.id);
          else if (win.restoreRect) s.commitRect(win.id, win.restoreRect);
          break;
        case 'X':
        case 'x':
          e.preventDefault();
          s.closeWindow(win.id);
          break;
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);
}
