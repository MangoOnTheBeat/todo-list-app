import { create } from 'zustand';

export interface Track {
  id: string;
  title: string;
  artist: string;
  album: string;
  duration: number; // seconds
  /** Three colours used to paint generative cover art. */
  palette: [string, string, string];
}

export const LIBRARY: Track[] = [
  { id: 't1', title: 'Glasshouse Weather', artist: 'Lumen Arcade', album: 'Refraction', duration: 222, palette: ['oklch(0.78 0.14 200)', 'oklch(0.6 0.2 280)', 'oklch(0.85 0.1 160)'] },
  { id: 't2', title: 'Northern Static', artist: 'Vela & The Tide', album: 'Polar Hours', duration: 245, palette: ['oklch(0.72 0.17 160)', 'oklch(0.5 0.15 230)', 'oklch(0.9 0.08 120)'] },
  { id: 't3', title: 'Soft Machines', artist: 'Orchid Protocol', album: 'Bloom State', duration: 198, palette: ['oklch(0.75 0.18 340)', 'oklch(0.55 0.2 300)', 'oklch(0.88 0.1 20)'] },
  { id: 't4', title: 'Halcyon Drive', artist: 'Neon Fathom', album: 'Depth Charts', duration: 301, palette: ['oklch(0.8 0.15 60)', 'oklch(0.6 0.2 20)', 'oklch(0.7 0.15 330)'] },
  { id: 't5', title: 'Low Orbit Lullaby', artist: 'Kites at Dusk', album: 'Apogee', duration: 176, palette: ['oklch(0.7 0.12 260)', 'oklch(0.45 0.12 280)', 'oklch(0.85 0.08 220)'] },
];

interface MediaStore {
  index: number;
  playing: boolean;
  position: number;
  liked: Record<string, boolean>;

  toggle: () => void;
  play: () => void;
  pause: () => void;
  next: () => void;
  prev: () => void;
  seek: (s: number) => void;
  tick: (dt: number) => void;
  toggleLike: () => void;
}

/**
 * A simulated media session (no audio is played). The shell treats it like a real
 * MediaSession: quick settings, the lock screen and the top bar all read from here.
 */
export const useMediaStore = create<MediaStore>()((set, get) => ({
  index: 0,
  playing: false,
  position: 64,
  liked: {},

  toggle: () => set((s) => ({ playing: !s.playing })),
  play: () => set({ playing: true }),
  pause: () => set({ playing: false }),
  next: () => set((s) => ({ index: (s.index + 1) % LIBRARY.length, position: 0 })),
  // Like most players: "previous" restarts the track unless you're at its very start.
  prev: () => set((s) => (s.position > 3 ? { position: 0 } : { index: (s.index - 1 + LIBRARY.length) % LIBRARY.length, position: 0 })),
  seek: (position) => set({ position }),
  tick: (dt) => {
    const s = get();
    if (!s.playing) return;
    const p = s.position + dt;
    if (p >= LIBRARY[s.index].duration) s.next();
    else set({ position: p });
  },
  toggleLike: () => set((s) => ({ liked: { ...s.liked, [LIBRARY[s.index].id]: !s.liked[LIBRARY[s.index].id] } })),
}));

export const currentTrack = (s: { index: number }) => LIBRARY[s.index];

export function formatTime(sec: number) {
  const s = Math.max(0, Math.floor(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}
