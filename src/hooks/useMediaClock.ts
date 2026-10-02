import { useEffect } from 'react';
import { useMediaStore } from '@/system/store/mediaStore';

/** Advances the simulated media session while playing. */
export function useMediaClock() {
  const playing = useMediaStore((s) => s.playing);
  useEffect(() => {
    if (!playing) return;
    let last = performance.now();
    const t = setInterval(() => {
      const now = performance.now();
      useMediaStore.getState().tick((now - last) / 1000);
      last = now;
    }, 250);
    return () => clearInterval(t);
  }, [playing]);
}
