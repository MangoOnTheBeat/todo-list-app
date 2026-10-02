import { GAP, SECONDARY_BAR_H, TOPBAR_H, workArea } from './layout';
import type { Display, Rect, SnapZone } from './types';

/** Resolve a named zone to a concrete rect inside a display's work area (with gutters). */
export function zoneRect(zone: SnapZone, display: Display): Rect {
  const wa = workArea(display);
  const g = GAP / 2;
  const halfW = wa.w / 2;
  const halfH = wa.h / 2;
  const third = wa.w / 3;
  const col = (x: number, w: number, y = wa.y, h = wa.h): Rect => ({ x: x + g, y: y + g, w: w - GAP, h: h - GAP });

  switch (zone) {
    case 'maximize':
      return { ...wa };
    case 'left':
      return col(wa.x, halfW);
    case 'right':
      return col(wa.x + halfW, halfW);
    case 'top-left':
      return col(wa.x, halfW, wa.y, halfH);
    case 'top-right':
      return col(wa.x + halfW, halfW, wa.y, halfH);
    case 'bottom-left':
      return col(wa.x, halfW, wa.y + halfH, halfH);
    case 'bottom-right':
      return col(wa.x + halfW, halfW, wa.y + halfH, halfH);
    case 'left-third':
      return col(wa.x, third);
    case 'center-third':
      return col(wa.x + third, third);
    case 'right-third':
      return col(wa.x + third * 2, third);
    case 'left-two-thirds':
      return col(wa.x, third * 2);
    case 'right-two-thirds':
      return col(wa.x + third, third * 2);
  }
}

const EDGE = 14;
const CORNER = 110;

/** Which zone (if any) a dragged window should snap to, given the pointer position. */
export function detectZone(px: number, py: number, display: Display): SnapZone | null {
  const b = display.bounds;
  const left = px <= b.x + EDGE;
  const right = px >= b.x + b.w - EDGE;
  const bar = display.primary ? TOPBAR_H : SECONDARY_BAR_H;
  const top = py <= b.y + bar + 4;
  const nearTop = py <= b.y + bar + CORNER;
  const nearBottom = py >= b.y + b.h - CORNER;

  if (left) return nearTop ? 'top-left' : nearBottom ? 'bottom-left' : 'left';
  if (right) return nearTop ? 'top-right' : nearBottom ? 'bottom-right' : 'right';
  if (top) return 'maximize';
  return null;
}

/** Templates offered by the snap-layouts flyout. Each inner array is one template's zones. */
export const SNAP_LAYOUTS: { label: string; zones: SnapZone[]; grid: string }[] = [
  { label: 'Halves', zones: ['left', 'right'], grid: 'grid-cols-2' },
  { label: 'Wide + narrow', zones: ['left-two-thirds', 'right-third'], grid: 'grid-cols-[2fr_1fr]' },
  { label: 'Thirds', zones: ['left-third', 'center-third', 'right-third'], grid: 'grid-cols-3' },
  {
    label: 'Quarters',
    zones: ['top-left', 'top-right', 'bottom-left', 'bottom-right'],
    grid: 'grid-cols-2 grid-rows-2',
  },
];
