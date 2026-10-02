import { useEffect, useRef } from 'react';
import { AnimatePresence } from 'framer-motion';
import { useShellStore } from '@/system/store/shellStore';
import { AssistantPanel } from '@/components/assistant/AssistantPanel';
import { Launcher } from './Launcher';
import { NotificationCenter } from './NotificationCenter';
import { QuickSettings } from './QuickSettings';
import { SearchOverlay } from './SearchOverlay';

/** Hosts the single open system panel plus an invisible click-away catcher behind it. */
export function ShellPanels() {
  const panel = useShellStore((s) => s.panel);
  const close = useShellStore((s) => s.closePanel);
  const opener = useRef<HTMLElement | null>(null);
  // Each opening gets a fresh instance. Reusing a key that is still animating out would
  // revive the old panel (stale text, no autofocus) instead of mounting a new one.
  const openCount = useRef(0);
  const last = useRef(panel);
  if (panel && panel !== last.current) openCount.current++;
  last.current = panel;
  const k = (name: string) => `${name}-${openCount.current}`;

  // Return keyboard focus to whatever opened the panel once it closes.
  useEffect(() => {
    if (panel) {
      if (!opener.current) opener.current = document.activeElement as HTMLElement | null;
    } else if (opener.current) {
      const el = opener.current;
      opener.current = null;
      if (el.isConnected) el.focus({ preventScroll: true });
    }
  }, [panel]);
  return (
    <>
      {panel && (
        <div
          aria-hidden
          className="pointer-events-auto fixed inset-0 z-[1200]"
          style={panel === 'search' ? { background: 'oklch(0 0 0 / 0.12)' } : undefined}
          onPointerDown={close}
        />
      )}
      <AnimatePresence>
        {panel === 'launcher' && <Launcher key={k('launcher')} />}
        {panel === 'search' && <SearchOverlay key={k('search')} />}
        {panel === 'notifications' && <NotificationCenter key={k('notifications')} />}
        {panel === 'quick' && <QuickSettings key={k('quick')} />}
        {panel === 'assistant' && <AssistantPanel key={k('assistant')} />}
      </AnimatePresence>
    </>
  );
}
