import { TOPBAR_H, DOCK_RESERVE } from './layout';
import type { Rect } from './types';

export interface OverviewSlot {
  /** Translation from the window's real position to its slot. */
  dx: number;
  dy: number;
  scale: number;
  /** Slot rect in screen space (for labels). */
  slot: Rect;
}

export const OVERVIEW_STRIP_H = 104;

/**
 * Exposé-style layout: pick the grid (cols × rows) that maximises the average window scale,
 * then centre each window, scaled uniformly, in its cell. Windows are never scaled up.
 */
export function overviewLayout(windows: { id: string; rect: Rect }[], viewport: { w: number; h: number }) {
  const area: Rect = {
    x: 48,
    y: TOPBAR_H + OVERVIEW_STRIP_H + 24,
    w: viewport.w - 96,
    h: viewport.h - TOPBAR_H - OVERVIEW_STRIP_H - DOCK_RESERVE - 40,
  };
  const n = windows.length;
  const out = new Map<string, OverviewSlot>();
  if (n === 0) return out;

  let best = { cols: 1, rows: n, score: -1 };
  for (let cols = 1; cols <= n; cols++) {
    const rows = Math.ceil(n / cols);
    const cw = area.w / cols;
    const ch = area.h / rows;
    const score = windows.reduce((acc, w) => acc + Math.min(1, (cw - 32) / w.rect.w, (ch - 48) / w.rect.h), 0);
    if (score > best.score) best = { cols, rows, score };
  }

  const { cols, rows } = best;
  const cw = area.w / cols;
  const ch = area.h / rows;
  windows.forEach((w, i) => {
    const row = Math.floor(i / cols);
    // Centre a partially-filled last row.
    const inRow = row === rows - 1 ? n - row * cols : cols;
    const col = i % cols;
    const rowOffset = ((cols - inRow) * cw) / 2;
    const scale = Math.min(1, (cw - 32) / w.rect.w, (ch - 48) / w.rect.h);
    const sw = w.rect.w * scale;
    const sh = w.rect.h * scale;
    const sx = area.x + rowOffset + col * cw + (cw - sw) / 2;
    const sy = area.y + row * ch + (ch - 24 - sh) / 2;
    out.set(w.id, { dx: sx - w.rect.x, dy: sy - w.rect.y, scale, slot: { x: sx, y: sy, w: sw, h: sh } });
  });
  return out;
}
