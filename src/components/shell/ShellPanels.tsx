import { AnimatePresence } from 'framer-motion';
import { useShellStore } from '@/system/store/shellStore';
import { Launcher } from './Launcher';
import { NotificationCenter } from './NotificationCenter';
import { QuickSettings } from './QuickSettings';
import { SearchOverlay } from './SearchOverlay';

/** Hosts the single open system panel plus an invisible click-away catcher behind it. */
export function ShellPanels() {
  const panel = useShellStore((s) => s.panel);
  const close = useShellStore((s) => s.closePanel);
  return (
    <>
      {panel && (
        <div
          aria-hidden
          className="absolute inset-0 z-[1200]"
          style={panel === 'search' ? { background: 'oklch(0 0 0 / 0.12)' } : undefined}
          onPointerDown={close}
        />
      )}
      <AnimatePresence>
        {panel === 'launcher' && <Launcher key="launcher" />}
        {panel === 'search' && <SearchOverlay key="search" />}
        {panel === 'notifications' && <NotificationCenter key="notifications" />}
        {panel === 'quick' && <QuickSettings key="quick" />}
      </AnimatePresence>
    </>
  );
}
