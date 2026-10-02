import { ContextNudge } from '@/components/assistant/ContextNudge';
import { VoiceOverlay } from '@/components/assistant/VoiceOverlay';
import { DisplayFilters } from './DisplayFilters';
import { Dock } from './Dock';
import { DesktopHUD } from './DesktopHUD';
import { LockScreen } from './LockScreen';
import { OverviewChrome } from './Overview';
import { ShellPanels } from './ShellPanels';
import { Toasts } from './Toasts';
import { TopBar } from './TopBar';
import { Wallpaper } from './Wallpaper';
import { useOverviewSlots, WindowLayers } from './WindowLayers';

/**
 * The root spatial scene, back to front:
 * wallpaper → desktop layers (windows, overview backdrop) → overview chrome → top bar & dock
 * → banners → system panels → HUD → lock screen → display filters.
 */
export function Desktop() {
  const slots = useOverviewSlots();
  return (
    <main className="fixed inset-0 overflow-hidden" aria-label="Aurora desktop">
      <Wallpaper />
      <WindowLayers slots={slots} />
      <OverviewChrome slots={slots} />
      <TopBar />
      <Dock />
      <ContextNudge />
      <Toasts />
      <ShellPanels />
      <VoiceOverlay />
      <DesktopHUD />
      <LockScreen />
      <DisplayFilters />
    </main>
  );
}
