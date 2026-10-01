import { useEffect } from 'react';
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
