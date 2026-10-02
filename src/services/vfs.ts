import type { AppId } from '@/system/types';

/**
 * Virtual file system model + helpers. The live, mutable tree lives in
 * `system/store/fileStore.ts`; this module defines the shape, the seed data and pure helpers.
 */
export type FileKind = 'folder' | 'document' | 'image' | 'audio' | 'video' | 'code' | 'archive' | 'spreadsheet' | 'presentation' | 'pdf';

export interface VNode {
  id: string;
  name: string;
  kind: FileKind;
  parentId: string | null;
  size?: number; // bytes
  modified: number;
  tags?: string[];
  trashed?: boolean;
  /** Text content for documents/code (Notes can open these). */
  content?: string;
  /** Derived, filled in by selectors. */
  path?: string;
}

const DAY = 86_400_000;
let seq = 0;

type Seed = { name: string; kind: FileKind; size?: number; daysAgo: number; tags?: string[]; content?: string; children?: Seed[] };
const f = (name: string, kind: FileKind, size: number, daysAgo: number, tags?: string[], content?: string): Seed => ({ name, kind, size, daysAgo, tags, content });
const d = (name: string, children: Seed[], daysAgo = 1): Seed => ({ name, kind: 'folder', daysAgo, children });

const seed: Seed[] = [
  d('Documents', [
    f('Q4 Roadmap.aurdoc', 'document', 48_200, 0.1, ['work', 'planning'], 'Q4 Roadmap\n\n1. Ship the glass window manager\n2. Launch Aurora AI beta to 5% of users\n3. Cut cold-start time by 30%'),
    f('Design Principles.aurdoc', 'document', 22_900, 3, ['design'], 'Light passes through. Depth is information. One physics. Calm by default.'),
    f('Lease Agreement 2026.pdf', 'pdf', 1_240_000, 40, ['personal']),
    f('Budget FY27.sheet', 'spreadsheet', 96_000, 1.5, ['work', 'finance']),
    f('Offsite Agenda.aurdoc', 'document', 9_800, 0.4, ['work'], 'Day 1: strategy\nDay 2: workshops\nDinner at 7pm, Harbour Room'),
  ]),
  d('Projects', [
    d('aurora-shell', [f('README.md', 'code', 4_100, 0.2), f('window-manager.ts', 'code', 18_400, 0.2), f('tokens.css', 'code', 6_300, 0.6)], 0.2),
    d('brand-refresh', [f('Moodboard.png', 'image', 6_400_000, 5, ['design']), f('Pitch.deck', 'presentation', 12_800_000, 2, ['work'])], 2),
  ]),
  d(
    'Downloads',
    [
      f('glass-shaders.zip', 'archive', 88_000_000, 0.05),
      f('IMG_2041.heic', 'image', 3_100_000, 0.3),
      f('Invoice-0412.pdf', 'pdf', 210_000, 6, ['finance']),
      f('podcast-ep-88.mp3', 'audio', 54_000_000, 9),
      f('Screenshot 2026-09-30 at 14.02.png', 'image', 1_800_000, 2),
      f('Tax Return 2025.pdf', 'pdf', 640_000, 20, ['finance']),
      f('quarterly-metrics.sheet', 'spreadsheet', 210_000, 3, ['work']),
      f('setup-notes.txt', 'document', 2_100, 12, [], 'Router password is on the fridge.'),
    ],
    0.05,
  ),
  d('Pictures', [
    f('Aurora Borealis, Tromsø.jpg', 'image', 7_800_000, 120, ['travel']),
    f('Studio Desk.jpg', 'image', 4_200_000, 14),
    f('Screen Recording 09-28.mov', 'video', 140_000_000, 4),
  ], 4),
  d('Music', [f('Glasshouse Weather.flac', 'audio', 32_000_000, 30), f('Northern Static.flac', 'audio', 35_000_000, 30)], 30),
];

export const ROOT_ID = 'root';

export function buildSeed(now = Date.now()): Record<string, VNode> {
  const nodes: Record<string, VNode> = {
    [ROOT_ID]: { id: ROOT_ID, name: 'Home', kind: 'folder', parentId: null, modified: now },
  };
  const walk = (items: Seed[], parentId: string) => {
    for (const s of items) {
      const id = `f${seq++}`;
      nodes[id] = { id, name: s.name, kind: s.kind, parentId, size: s.size, modified: now - s.daysAgo * DAY, tags: s.tags, content: s.content };
      if (s.children) walk(s.children, id);
    }
  };
  walk(seed, ROOT_ID);
  return nodes;
}

export function pathOf(nodes: Record<string, VNode>, id: string): string {
  const parts: string[] = [];
  let cur: VNode | undefined = nodes[id];
  while (cur) {
    parts.unshift(cur.name);
    cur = cur.parentId ? nodes[cur.parentId] : undefined;
  }
  return parts.join('/');
}

export function formatBytes(b = 0) {
  if (b < 1024) return `${b} B`;
  const u = ['KB', 'MB', 'GB'];
  let v = b / 1024;
  let i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v < 10 ? v.toFixed(1) : Math.round(v)} ${u[i]}`;
}

export function relativeTime(t: number) {
  const diff = Date.now() - t;
  const m = Math.round(diff / 60_000);
  if (m < 1) return 'now';
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.round(h / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(t).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

/** Which app opens a given file. */
export function appForFile(kind: FileKind): AppId {
  if (kind === 'audio') return 'music';
  if (kind === 'document' || kind === 'code') return 'notes';
  return 'files';
}

export const KIND_LABEL: Record<FileKind, string> = {
  folder: 'Folder',
  document: 'Document',
  image: 'Image',
  audio: 'Audio',
  video: 'Video',
  code: 'Source code',
  archive: 'Archive',
  spreadsheet: 'Spreadsheet',
  presentation: 'Presentation',
  pdf: 'PDF',
};
