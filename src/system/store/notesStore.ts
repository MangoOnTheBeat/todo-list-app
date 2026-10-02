import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { uid } from '../ids';

export interface Note {
  id: string;
  title: string;
  body: string;
  pinned: boolean;
  updated: number;
  hue: number;
}

const now = Date.now();
const SEED: Note[] = [
  {
    id: 'n-welcome',
    title: 'Aurora field notes',
    body: 'Glass needs contrast underneath it — when a surface sits over busy content, raise its opacity instead of the blur.\n\nIdeas:\n- Ambient light follows the cursor on focused windows\n- Overview could group windows by project\n- Hold Alt while snapping for thirds',
    pinned: true,
    updated: now - 3_600_000,
    hue: 275,
  },
  { id: 'n-groceries', title: 'Weekend', body: 'Farmers market at 10\nBuy: figs, sourdough, oat milk, basil\nCall Mum', pinned: false, updated: now - 86_400_000, hue: 85 },
  { id: 'n-books', title: 'Reading list', body: 'The Design of Everyday Things\nA Pattern Language\nThe Shape of Design', pinned: false, updated: now - 4 * 86_400_000, hue: 165 },
];

interface NotesStore {
  notes: Note[];
  create: () => string;
  update: (id: string, patch: Partial<Omit<Note, 'id'>>) => void;
  remove: (id: string) => void;
}

/** Notes persist locally (wrapped storage access fails soft in private windows). */
export const useNotesStore = create<NotesStore>()(
  persist(
    (set) => ({
      notes: SEED,
      create: () => {
        const id = uid('n');
        set((s) => ({ notes: [{ id, title: '', body: '', pinned: false, updated: Date.now(), hue: [275, 200, 165, 85, 35, 355][s.notes.length % 6] }, ...s.notes] }));
        return id;
      },
      update: (id, patch) => set((s) => ({ notes: s.notes.map((n) => (n.id === id ? { ...n, ...patch, updated: Date.now() } : n)) })),
      remove: (id) => set((s) => ({ notes: s.notes.filter((n) => n.id !== id) })),
    }),
    { name: 'aurora.notes', version: 1 },
  ),
);
