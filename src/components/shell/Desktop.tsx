import { ContextNudge } from '@/components/assistant/ContextNudge';
import { VoiceOverlay } from '@/components/assistant/VoiceOverlay';
import { useWindowStore } from '@/system/store/windowStore';
import { Announcer } from './Announcer';
import { DisplayFilters } from './DisplayFilters';
import { Dock } from './Dock';
import { DesktopHUD } from './DesktopHUD';
import { LockScreen } from './LockScreen';
import { OverviewChrome } from './Overview';
import { SecondaryDisplays } from './SecondaryDisplays';
import { ShellPanels } from './ShellPanels';
import { Toasts } from './Toasts';
import { TopBar } from './TopBar';
import { Wallpaper } from './Wallpaper';
import { useOverviewSlots, WindowLayers } from './WindowLayers';

/**
 * The root spatial scene, back to front:
 * wallpaper → desktop layers (windows, overview backdrop) → display bezels → overview chrome
 * → primary-display chrome (top bar, dock, banners, panels, HUDs) → lock screen → display filters.
 *
 * Windows span the whole virtual screen; system chrome is confined to the primary display.
 */
export function Desktop() {
  const slots = useOverviewSlots();
  const primary = useWindowStore((s) => s.displays.find((d) => d.primary) ?? s.displays[0]);
  const b = primary.bounds;
  return (
    <main className="fixed inset-0 overflow-hidden" aria-label="Aurora desktop">
      <Wallpaper />
      <WindowLayers slots={slots} />
      <SecondaryDisplays />
      <OverviewChrome slots={slots} />
      <div className="pointer-events-none absolute" style={{ left: b.x, top: b.y, width: b.w, height: b.h }}>
        {/* pointer-events stay off here; each interactive surface opts back in. */}
        <div className="pointer-events-none absolute inset-0">
          <TopBar />
          <Dock />
          <ContextNudge />
          <Toasts />
          <ShellPanels />
          <VoiceOverlay />
          <DesktopHUD />
        </div>
      </div>
      <LockScreen />
      <DisplayFilters />
      <Announcer />
    </main>
  );
}
