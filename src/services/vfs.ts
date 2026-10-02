import type { AppId } from '@/system/types';

/**
 * A small in-memory virtual file system. Search uses it now; the Files app and the
 * AI file organiser build on it in later phases.
 */
export type FileKind = 'folder' | 'document' | 'image' | 'audio' | 'video' | 'code' | 'archive' | 'spreadsheet' | 'presentation' | 'pdf';

export interface VNode {
  id: string;
  name: string;
  kind: FileKind;
  path: string;
  size?: number; // bytes
  modified: number;
  tags?: string[];
  children?: VNode[];
}

const DAY = 86_400_000;
const now = Date.now();
let seq = 0;

function f(name: string, kind: FileKind, size: number, daysAgo: number, tags?: string[]): Omit<VNode, 'path'> {
  return { id: `f${seq++}`, name, kind, size, modified: now - daysAgo * DAY, tags };
}
function d(name: string, children: Omit<VNode, 'path'>[], daysAgo = 1): Omit<VNode, 'path'> {
  return { id: `f${seq++}`, name, kind: 'folder', modified: now - daysAgo * DAY, children: children as VNode[] };
}

const raw = d('Home', [
  d('Documents', [
    f('Q4 Roadmap.aurdoc', 'document', 48_200, 0.1, ['work', 'planning']),
    f('Design Principles.aurdoc', 'document', 22_900, 3, ['design']),
    f('Lease Agreement 2026.pdf', 'pdf', 1_240_000, 40, ['personal']),
    f('Budget FY27.sheet', 'spreadsheet', 96_000, 1.5, ['work', 'finance']),
    f('Offsite Agenda.aurdoc', 'document', 9_800, 0.4, ['work']),
  ]),
  d('Projects', [
    d('aurora-shell', [f('README.md', 'code', 4_100, 0.2), f('window-manager.ts', 'code', 18_400, 0.2), f('tokens.css', 'code', 6_300, 0.6)]),
    d('brand-refresh', [f('Moodboard.png', 'image', 6_400_000, 5, ['design']), f('Pitch.deck', 'presentation', 12_800_000, 2, ['work'])]),
  ]),
  d('Downloads', [
    f('glass-shaders.zip', 'archive', 88_000_000, 0.05),
    f('IMG_2041.heic', 'image', 3_100_000, 0.3),
    f('Invoice-0412.pdf', 'pdf', 210_000, 6, ['finance']),
    f('podcast-ep-88.mp3', 'audio', 54_000_000, 9),
  ]),
  d('Pictures', [
    f('Aurora Borealis, Tromsø.jpg', 'image', 7_800_000, 120, ['travel']),
    f('Studio Desk.jpg', 'image', 4_200_000, 14),
    f('Screen Recording 09-28.mov', 'video', 140_000_000, 4),
  ]),
  d('Music', [f('Refraction (Lumen Arcade)', 'folder', 0, 30)]),
], 0);

function withPaths(node: Omit<VNode, 'path'>, parent: string): VNode {
  const path = parent ? `${parent}/${node.name}` : node.name;
  return { ...node, path, children: node.children?.map((c) => withPaths(c, path)) };
}

export const fileTree: VNode = withPaths(raw, '');

export function allFiles(node: VNode = fileTree): VNode[] {
  return [node, ...(node.children ?? []).flatMap(allFiles)].filter((n) => n !== fileTree);
}

export function recentFiles(limit = 6) {
  return allFiles()
    .filter((n) => n.kind !== 'folder')
    .sort((a, b) => b.modified - a.modified)
    .slice(0, limit);
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
