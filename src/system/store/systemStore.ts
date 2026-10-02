import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ThemePref = 'light' | 'dark' | 'auto';
export type WallpaperId = 'aurora' | 'dusk' | 'lagoon' | 'bloom' | 'graphite';

export const WALLPAPERS: { id: WallpaperId; name: string; preview: string }[] = [
  { id: 'aurora', name: 'Aurora', preview: 'linear-gradient(135deg, oklch(0.55 0.16 190), oklch(0.45 0.2 290), oklch(0.5 0.2 340))' },
  { id: 'dusk', name: 'Dusk', preview: 'linear-gradient(135deg, oklch(0.6 0.17 50), oklch(0.5 0.2 10), oklch(0.4 0.16 300))' },
  { id: 'lagoon', name: 'Lagoon', preview: 'linear-gradient(135deg, oklch(0.6 0.12 230), oklch(0.55 0.13 190), oklch(0.6 0.15 150))' },
  { id: 'bloom', name: 'Bloom', preview: 'linear-gradient(135deg, oklch(0.8 0.1 350), oklch(0.75 0.1 40), oklch(0.7 0.12 300))' },
  { id: 'graphite', name: 'Graphite', preview: 'linear-gradient(135deg, oklch(0.45 0.01 270), oklch(0.3 0.02 270), oklch(0.55 0.04 var(--accent-h)))' },
];

export interface SystemStore {
  theme: ThemePref;
  /** OKLCH hue of the accent colour. */
  accentHue: number;
  reduceTransparency: boolean;
  reduceMotion: boolean;
  /** 0–1: how see-through glass surfaces are (user-tunable "dynamic transparency"). */
  glassIntensity: number;
  dockMagnification: boolean;
  /** Simulated device controls surfaced in Quick Settings. */
  brightness: number;
  volume: number;
  nightLight: boolean;
  wifi: boolean;
  bluetooth: boolean;
  airplane: boolean;
  focusMode: boolean;
  wallpaper: WallpaperId;
  /** Aurora AI preferences. */
  aiEnabled: boolean;
  aiSmartNotifications: boolean;
  aiSuggestions: boolean;
  aiVoice: boolean;
  /** Phase 5: split the viewport into two simulated displays. */
  dualDisplay: boolean;

  setTheme: (t: ThemePref) => void;
  setAccentHue: (h: number) => void;
  set: <K extends keyof SystemPrefs>(key: K, value: SystemPrefs[K]) => void;
}

type SystemPrefs = Omit<SystemStore, 'setTheme' | 'setAccentHue' | 'set'>;

export const ACCENT_PRESETS = [
  { name: 'Aurora', hue: 275 },
  { name: 'Lagoon', hue: 200 },
  { name: 'Mint', hue: 165 },
  { name: 'Citrine', hue: 85 },
  { name: 'Ember', hue: 35 },
  { name: 'Rose', hue: 355 },
];

export const useSystemStore = create<SystemStore>()(
  persist(
    (set) => ({
      theme: 'auto',
      accentHue: 275,
      reduceTransparency: false,
      reduceMotion: false,
      glassIntensity: 0.5,
      dockMagnification: true,
      brightness: 1,
      volume: 0.6,
      nightLight: false,
      wifi: true,
      bluetooth: true,
      airplane: false,
      focusMode: false,
      wallpaper: 'aurora',
      aiEnabled: true,
      aiSmartNotifications: true,
      aiSuggestions: true,
      aiVoice: true,
      dualDisplay: false,

      setTheme: (theme) => set({ theme }),
      setAccentHue: (accentHue) => set({ accentHue }),
      set: (key, value) => set({ [key]: value } as Partial<SystemStore>),
    }),
    { name: 'aurora.system', version: 1 },
  ),
);
