import { useEffect } from 'react';
import { useSystemStore } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';
import type { Display } from '@/system/types';

export const BEZEL = 14;

/**
 * Publishes the display layout. Normally one display = the viewport. With "Simulate a
 * second display" on (and room for it), the viewport is split into a primary display and
 * an external one separated by a bezel — exercising the same multi-monitor path a real
 * host (e.g. the Window Management API's getScreenDetails) would feed.
 */
export function computeDisplays(w: number, h: number, dual: boolean): Display[] {
  const scale = window.devicePixelRatio || 1;
  if (!dual || w < 900) return [{ id: 'display-primary', name: 'Built-in Display', bounds: { x: 0, y: 0, w, h }, primary: true, scale }];
  const pw = Math.round(w * 0.6) - BEZEL / 2;
  return [
    { id: 'display-primary', name: 'Built-in Display', bounds: { x: 0, y: 0, w: pw, h }, primary: true, scale },
    { id: 'display-2', name: 'Studio Display', bounds: { x: pw + BEZEL, y: 0, w: w - pw - BEZEL, h }, primary: false, scale },
  ];
}

export function useDisplaySync() {
  const dual = useSystemStore((s) => s.dualDisplay);
  useEffect(() => {
    let frame = 0;
    const sync = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => useWindowStore.getState().setDisplays(computeDisplays(window.innerWidth, window.innerHeight, dual)));
    };
    sync();
    window.addEventListener('resize', sync);
    return () => {
      window.removeEventListener('resize', sync);
      cancelAnimationFrame(frame);
    };
  }, [dual]);
}
