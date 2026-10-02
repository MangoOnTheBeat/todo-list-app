import { create } from 'zustand';

export type ShellPanel = 'launcher' | 'search' | 'notifications' | 'quick' | null;

/**
 * Transient shell UI state: which system surface is open, overview, lock.
 * Kept apart from the window store so opening a panel never re-renders windows.
 */
interface ShellStore {
  panel: ShellPanel;
  overview: boolean;
  locked: boolean;
  /** Text to pre-fill when search opens (e.g. typed into the launcher). */
  searchSeed: string;

  togglePanel: (p: Exclude<ShellPanel, null>) => void;
  openSearch: (seed?: string) => void;
  closePanel: () => void;
  setOverview: (on: boolean) => void;
  lock: () => void;
  unlock: () => void;
}

export const useShellStore = create<ShellStore>()((set) => ({
  panel: null,
  overview: false,
  locked: false,
  searchSeed: '',

  togglePanel: (p) => set((s) => ({ panel: s.panel === p ? null : p, overview: false })),
  openSearch: (seed = '') => set({ panel: 'search', searchSeed: seed, overview: false }),
  closePanel: () => set({ panel: null }),
  setOverview: (overview) => set({ overview, panel: null }),
  lock: () => set({ locked: true, panel: null, overview: false }),
  unlock: () => set({ locked: false }),
}));
