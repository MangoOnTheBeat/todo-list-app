import { create } from 'zustand';
import { buildSeed, pathOf, ROOT_ID, type FileKind, type VNode } from '@/services/vfs';
import { uid } from '../ids';

interface FileStore {
  nodes: Record<string, VNode>;
  createFolder: (parentId: string, name?: string) => string;
  createFile: (parentId: string, name: string, kind: FileKind, content?: string) => string;
  rename: (id: string, name: string) => void;
  move: (id: string, parentId: string) => void;
  trash: (id: string) => void;
  restore: (id: string) => void;
  emptyTrash: () => void;
  setTags: (id: string, tags: string[]) => void;
  writeContent: (id: string, content: string) => void;
}

function uniqueName(nodes: Record<string, VNode>, parentId: string, name: string) {
  const siblings = new Set(Object.values(nodes).filter((n) => n.parentId === parentId && !n.trashed).map((n) => n.name));
  if (!siblings.has(name)) return name;
  let i = 2;
  while (siblings.has(`${name} ${i}`)) i++;
  return `${name} ${i}`;
}

export const useFileStore = create<FileStore>()((set, get) => ({
  nodes: buildSeed(),

  createFolder(parentId, name = 'New Folder') {
    const id = uid('f');
    set((s) => ({ nodes: { ...s.nodes, [id]: { id, name: uniqueName(s.nodes, parentId, name), kind: 'folder', parentId, modified: Date.now() } } }));
    return id;
  },
  createFile(parentId, name, kind, content = '') {
    const id = uid('f');
    set((s) => ({ nodes: { ...s.nodes, [id]: { id, name: uniqueName(s.nodes, parentId, name), kind, parentId, modified: Date.now(), size: content.length, content } } }));
    return id;
  },
  rename: (id, name) => set((s) => ({ nodes: { ...s.nodes, [id]: { ...s.nodes[id], name: name.trim() || s.nodes[id].name, modified: Date.now() } } })),
  move(id, parentId) {
    // Refuse to move a folder into itself or its own descendant.
    let cur: string | null = parentId;
    while (cur) {
      if (cur === id) return;
      cur = get().nodes[cur]?.parentId ?? null;
    }
    set((s) => ({ nodes: { ...s.nodes, [id]: { ...s.nodes[id], parentId, name: uniqueName(s.nodes, parentId, s.nodes[id].name) } } }));
  },
  trash: (id) => set((s) => ({ nodes: { ...s.nodes, [id]: { ...s.nodes[id], trashed: true } } })),
  restore: (id) => set((s) => ({ nodes: { ...s.nodes, [id]: { ...s.nodes[id], trashed: false } } })),
  emptyTrash: () =>
    set((s) => {
      const doomed = new Set(Object.values(s.nodes).filter((n) => n.trashed).map((n) => n.id));
      // Also drop descendants of trashed folders.
      let grew = true;
      while (grew) {
        grew = false;
        for (const n of Object.values(s.nodes)) if (n.parentId && doomed.has(n.parentId) && !doomed.has(n.id)) (doomed.add(n.id), (grew = true));
      }
      return { nodes: Object.fromEntries(Object.entries(s.nodes).filter(([id]) => !doomed.has(id))) };
    }),
  setTags: (id, tags) => set((s) => ({ nodes: { ...s.nodes, [id]: { ...s.nodes[id], tags } } })),
  writeContent: (id, content) => set((s) => ({ nodes: { ...s.nodes, [id]: { ...s.nodes[id], content, size: content.length, modified: Date.now() } } })),
}));

/* ── Selectors / helpers (pure, take nodes) ── */

/** True if the node or any ancestor is in the trash. */
export function isTrashed(nodes: Record<string, VNode>, id: string) {
  let cur: VNode | undefined = nodes[id];
  while (cur) {
    if (cur.trashed) return true;
    cur = cur.parentId ? nodes[cur.parentId] : undefined;
  }
  return false;
}

export function childrenOf(nodes: Record<string, VNode>, parentId: string) {
  return Object.values(nodes).filter((n) => n.parentId === parentId && !n.trashed);
}

export function allFiles(nodes = useFileStore.getState().nodes): VNode[] {
  return Object.values(nodes)
    .filter((n) => n.id !== ROOT_ID && !isTrashed(nodes, n.id))
    .map((n) => ({ ...n, path: pathOf(nodes, n.id) }));
}

export function recentFiles(limit = 6, nodes = useFileStore.getState().nodes) {
  return allFiles(nodes)
    .filter((n) => n.kind !== 'folder')
    .sort((a, b) => b.modified - a.modified)
    .slice(0, limit);
}

export function findByPath(nodes: Record<string, VNode>, path: string) {
  return Object.values(nodes).find((n) => pathOf(nodes, n.id) === path);
}

export { ROOT_ID };
