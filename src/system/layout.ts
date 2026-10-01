import type { Display, Rect } from './types';

/** Shell metrics shared by the window manager and the shell chrome. */
export const TOPBAR_H = 36;
export const DOCK_RESERVE = 96;
export const GAP = 10;

/** Region of a display windows may occupy (excludes top bar and dock). */
export function workArea(display: Display): Rect {
  const b = display.bounds;
  return {
    x: b.x + GAP,
    y: b.y + TOPBAR_H + GAP,
    w: b.w - GAP * 2,
    h: b.h - TOPBAR_H - DOCK_RESERVE - GAP,
  };
}

export function clamp(v: number, min: number, max: number) {
  return Math.min(max, Math.max(min, v));
}

/** Keep enough of a window on-screen that it can always be grabbed again. */
export function clampToDisplay(rect: Rect, display: Display): Rect {
  const wa = workArea(display);
  const b = display.bounds;
  const keep = 96;
  return {
    ...rect,
    w: Math.min(rect.w, b.w),
    h: Math.min(rect.h, b.h - TOPBAR_H),
    x: clamp(rect.x, b.x - rect.w + keep, b.x + b.w - keep),
    y: clamp(rect.y, wa.y - GAP, b.y + b.h - 48),
  };
}

export function displayAt(displays: Display[], px: number, py: number): Display {
  return (
    displays.find(
      (d) => px >= d.bounds.x && px < d.bounds.x + d.bounds.w && py >= d.bounds.y && py < d.bounds.y + d.bounds.h,
    ) ?? displays.find((d) => d.primary)!
  );
}
