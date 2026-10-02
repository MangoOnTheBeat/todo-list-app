import { motion } from 'framer-motion';
import { BatteryMedium, Bluetooth, BellOff, Lock, Moon, MoonStar, Plane, Settings2, SunMedium, Target, Volume1, VolumeX, Wifi, WifiOff } from 'lucide-react';
import { MediaCard } from '@/components/ui/MediaCard';
import { Slider } from '@/components/ui/Slider';
import { ToggleTile } from '@/components/ui/ToggleTile';
import { commands } from '@/services/commands';
import { springs } from '@/system/motion';
import { useNotificationStore } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';
import { useSystemStore } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';

/** Control center: connectivity and mode toggles, display/sound sliders, media. */
export function QuickSettings() {
  const sys = useSystemStore();
  const dnd = useNotificationStore((s) => s.dnd);
  const dark = sys.theme === 'dark' || (sys.theme === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  const close = useShellStore((s) => s.closePanel);

  return (
    <motion.div
      role="dialog"
      aria-label="Quick settings"
      initial={{ opacity: 0, y: -14, scale: 0.96 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -10, scale: 0.97, transition: { duration: 0.15 } }}
      transition={springs.panel}
      className="pointer-events-auto glass acrylic glass-sheen absolute right-2.5 top-11 z-[1300] max-h-[calc(100vh-150px)] w-[min(360px,calc(100vw-20px))] origin-top-right space-y-3 overflow-y-auto rounded-[var(--radius-panel)] p-4"
      style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
    >
      <div className="grid grid-cols-2 gap-2">
        <ToggleTile label="Wi-Fi" detail={sys.wifi && !sys.airplane ? 'Aurora-5G' : 'Off'} icon={sys.wifi && !sys.airplane ? Wifi : WifiOff} on={sys.wifi && !sys.airplane} onToggle={() => sys.set('wifi', !sys.wifi)} />
        <ToggleTile label="Bluetooth" detail={sys.bluetooth && !sys.airplane ? 'Studio Buds' : 'Off'} icon={Bluetooth} on={sys.bluetooth && !sys.airplane} onToggle={() => sys.set('bluetooth', !sys.bluetooth)} />
        <ToggleTile label="Do Not Disturb" detail={dnd ? 'Banners held' : 'Off'} icon={BellOff} on={dnd} onToggle={commands.toggleDnd} />
        <ToggleTile label="Focus" detail={sys.focusMode ? 'Deep work' : 'Off'} icon={Target} on={sys.focusMode} onToggle={commands.toggleFocusMode} />
        <ToggleTile label="Dark mode" icon={Moon} on={dark} onToggle={commands.toggleDarkMode} />
        <ToggleTile label="Night Light" icon={MoonStar} on={sys.nightLight} onToggle={commands.toggleNightLight} />
        <ToggleTile label="Airplane" icon={Plane} on={sys.airplane} onToggle={() => sys.set('airplane', !sys.airplane)} />
        <ToggleTile label="Transparency" detail={sys.reduceTransparency ? 'Reduced' : 'Full glass'} icon={SunMedium} on={!sys.reduceTransparency} onToggle={() => sys.set('reduceTransparency', !sys.reduceTransparency)} />
      </div>

      <div className="space-y-2.5">
        <Slider label="Display brightness" icon={SunMedium} value={sys.brightness} min={0.3} onChange={(v) => sys.set('brightness', v)} />
        <Slider label="Volume" icon={sys.volume === 0 ? VolumeX : Volume1} value={sys.volume} onChange={(v) => sys.set('volume', v)} />
      </div>

      <MediaCard />

      <footer className="flex items-center gap-2 pt-1 text-xs text-fg-muted">
        <BatteryMedium className="size-4" />
        <span className="tabular-nums">82% · 5 h 40 m left</span>
        <div className="ml-auto flex gap-1">
          <button
            aria-label="Open Settings"
            onClick={() => {
              close();
              useWindowStore.getState().openApp('settings');
            }}
            className="grid size-8 place-items-center rounded-full hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]"
          >
            <Settings2 className="size-4" />
          </button>
          <button aria-label="Lock" onClick={commands.lock} className="grid size-8 place-items-center rounded-full hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
            <Lock className="size-4" />
          </button>
        </div>
      </footer>
    </motion.div>
  );
}
