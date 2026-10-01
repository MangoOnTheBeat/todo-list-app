import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ThemePref = 'light' | 'dark' | 'auto';

export interface SystemStore {
  theme: ThemePref;
  /** OKLCH hue of the accent colour. */
  accentHue: number;
  reduceTransparency: boolean;
  reduceMotion: boolean;
  /** 0–1: how see-through glass surfaces are (user-tunable "dynamic transparency"). */
  glassIntensity: number;
  dockMagnification: boolean;

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

      setTheme: (theme) => set({ theme }),
      setAccentHue: (accentHue) => set({ accentHue }),
      set: (key, value) => set({ [key]: value } as Partial<SystemStore>),
    }),
    { name: 'aurora.system', version: 1 },
  ),
);
