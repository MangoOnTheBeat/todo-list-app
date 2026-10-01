import { useEffect } from 'react';
import { useWindowStore } from '@/system/store/windowStore';

/**
 * Keeps the primary display's bounds in sync with the viewport. A multi-monitor host
 * (e.g. the Window Management API's getScreenDetails) would call setDisplayBounds per screen.
 */
export function useDisplaySync() {
  const setDisplayBounds = useWindowStore((s) => s.setDisplayBounds);
  useEffect(() => {
    let frame = 0;
    const sync = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() =>
        setDisplayBounds('display-primary', { x: 0, y: 0, w: window.innerWidth, h: window.innerHeight }),
      );
    };
    window.addEventListener('resize', sync);
    return () => {
      window.removeEventListener('resize', sync);
      cancelAnimationFrame(frame);
    };
  }, [setDisplayBounds]);
}
