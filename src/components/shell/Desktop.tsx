import { Dock } from './Dock';
import { DesktopHUD } from './DesktopHUD';
import { TopBar } from './TopBar';
import { Wallpaper } from './Wallpaper';
import { WindowLayers } from './WindowLayers';

/** The root spatial scene: wallpaper → desktop layers (windows) → shell chrome → overlays. */
export function Desktop() {
  return (
    <main className="fixed inset-0 overflow-hidden" aria-label="Aurora desktop">
      <Wallpaper />
      <WindowLayers />
      <TopBar />
      <Dock />
      <DesktopHUD />
    </main>
  );
}
