import { childrenOf, useFileStore } from '@/system/store/fileStore';
import type { VNode } from '../vfs';

/**
 * Smart file organisation. A deterministic, on-device planner: it reads names, kinds, tags
 * and ages, proposes folders with a human-readable reason and a confidence, and applies
 * a plan reversibly. A model-backed planner could replace `plan()` with the same output shape.
 */
export interface OrganizeGroup {
  id: string;
  folder: string;
  reason: string;
  confidence: number; // 0–1
  files: VNode[];
}

const DAY = 86_400_000;

interface Rule {
  id: string;
  folder: string;
  reason: (n: number) => string;
  confidence: number;
  match: (f: VNode) => boolean;
}

const RULES: Rule[] = [
  { id: 'screens', folder: 'Screenshots', confidence: 0.96, reason: (n) => `${n} screen captures detected by their file names`, match: (f) => /^(screenshot|screen recording)/i.test(f.name) },
  { id: 'finance', folder: 'Finance', confidence: 0.9, reason: (n) => `${n} invoices, receipts or tax documents`, match: (f) => /(invoice|receipt|tax|budget|statement)/i.test(f.name) || !!f.tags?.includes('finance') },
  { id: 'installers', folder: 'Archives', confidence: 0.82, reason: (n) => `${n} compressed archives you've probably already extracted`, match: (f) => f.kind === 'archive' },
  { id: 'media', folder: 'Audio & Podcasts', confidence: 0.78, reason: (n) => `${n} audio files`, match: (f) => f.kind === 'audio' },
  { id: 'photos', folder: 'Photos', confidence: 0.74, reason: (n) => `${n} photos from your camera roll`, match: (f) => f.kind === 'image' || f.kind === 'video' },
  { id: 'sheets', folder: 'Spreadsheets', confidence: 0.7, reason: (n) => `${n} spreadsheets`, match: (f) => f.kind === 'spreadsheet' },
  { id: 'stale', folder: 'Old Files', confidence: 0.6, reason: (n) => `${n} files untouched for over a month`, match: (f) => Date.now() - f.modified > 30 * DAY },
];

export function plan(folderId: string): OrganizeGroup[] {
  const nodes = useFileStore.getState().nodes;
  const files = childrenOf(nodes, folderId).filter((n) => n.kind !== 'folder');
  const taken = new Set<string>();
  const existingFolders = new Set(childrenOf(nodes, folderId).filter((n) => n.kind === 'folder').map((n) => n.name));
  const groups: OrganizeGroup[] = [];
  for (const rule of RULES) {
    const hits = files.filter((f) => !taken.has(f.id) && rule.match(f));
    // A folder of one isn't organisation; existing folders are fine to reuse.
    if (hits.length < 2 && !(hits.length === 1 && existingFolders.has(rule.folder))) continue;
    hits.forEach((f) => taken.add(f.id));
    groups.push({ id: rule.id, folder: rule.folder, reason: rule.reason(hits.length), confidence: rule.confidence, files: hits });
  }
  return groups;
}

/** Apply selected groups. Returns an undo function that restores every moved file. */
export function apply(folderId: string, groups: OrganizeGroup[]) {
  const fs = useFileStore.getState();
  const moves: { id: string; from: string | null }[] = [];
  const created: string[] = [];
  for (const g of groups) {
    const nodes = useFileStore.getState().nodes;
    let target = childrenOf(nodes, folderId).find((n) => n.kind === 'folder' && n.name === g.folder)?.id;
    if (!target) {
      target = fs.createFolder(folderId, g.folder);
      created.push(target);
    }
    for (const f of g.files) {
      moves.push({ id: f.id, from: useFileStore.getState().nodes[f.id].parentId });
      fs.move(f.id, target);
    }
  }
  return () => {
    const s = useFileStore.getState();
    moves.forEach((m) => m.from && s.move(m.id, m.from));
    created.forEach((id) => s.trash(id));
    useFileStore.getState().emptyTrash();
  };
}
