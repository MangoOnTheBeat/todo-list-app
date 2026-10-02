import { useEffect, useState } from 'react';
import { getApp } from '@/system/appRegistry';
import { useWindowStore } from '@/system/store/windowStore';

/**
 * Screen-reader narration for window lifecycle changes that happen visually
 * (open, close, minimize, snap), via a polite live region.
 */
export function Announcer() {
  const [message, setMessage] = useState('');
  useEffect(
    () =>
      useWindowStore.subscribe((s, prev) => {
        for (const id of Object.keys(s.windows)) {
          const w = s.windows[id];
          const p = prev.windows[id];
          const name = w.title === getApp(w.appId).name ? w.title : `${getApp(w.appId).name}, ${w.title}`;
          if (!p) return setMessage(`${name} opened`);
          if (w.minimized && !p.minimized) return setMessage(`${name} minimized`);
          if (w.snap !== p.snap && w.snap) return setMessage(w.snap === 'maximize' ? `${name} maximized` : `${name} snapped ${w.snap.replace(/-/g, ' ')}`);
          if (w.desktopId !== p.desktopId) return setMessage(`${name} moved to ${s.desktops.find((d) => d.id === w.desktopId)?.name}`);
          if (w.displayId !== p.displayId) return setMessage(`${name} moved to ${s.displays.find((d) => d.id === w.displayId)?.name}`);
        }
        for (const id of Object.keys(prev.windows)) if (!s.windows[id]) return setMessage(`${prev.windows[id].title} closed`);
      }),
    [],
  );
  return (
    <div className="sr-only" role="status" aria-live="polite">
      {message}
    </div>
  );
}
