import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import {
  ArrowLeft,
  ArrowRight,
  Clock,
  Download,
  ExternalLink,
  FileText,
  Folder,
  FolderPlus,
  Home,
  Image,
  LayoutGrid,
  List,
  Music,
  Pencil,
  RotateCcw,
  Tag,
  Trash2,
  X,
} from 'lucide-react';
import clsx from 'clsx';
import { AppLayout, EmptyState, SearchField, Segmented, SidebarItem, SidebarSection, Toolbar, ToolButton } from '@/components/ui/AppKit';
import { ContextMenu, type MenuItem } from '@/components/ui/ContextMenu';
import { appForFile, formatBytes, KIND_LABEL, pathOf, relativeTime, type VNode } from '@/services/vfs';
import { springs } from '@/system/motion';
import { allFiles, childrenOf, isTrashed, ROOT_ID, useFileStore } from '@/system/store/fileStore';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';
import { FileGlyph } from './FileGlyph';
import { OrganizePanel } from './OrganizePanel';

type Location = { type: 'folder'; id: string } | { type: 'recents' } | { type: 'tag'; tag: string } | { type: 'trash' };

const TAGS: { tag: string; hue: number }[] = [
  { tag: 'work', hue: 255 },
  { tag: 'finance', hue: 150 },
  { tag: 'design', hue: 330 },
  { tag: 'personal', hue: 60 },
  { tag: 'travel', hue: 200 },
];
const tagColor = (t: string) => `oklch(0.68 0.15 ${TAGS.find((x) => x.tag === t)?.hue ?? 270})`;

const sameLoc = (a: Location, b: Location) => JSON.stringify(a) === JSON.stringify(b);

export default function FilesApp({ windowId, args }: AppProps) {
  const nodes = useFileStore((s) => s.nodes);
  const fs = useFileStore.getState();
  const setTitle = useWindowStore((s) => s.setTitle);
  const openApp = useWindowStore((s) => s.openApp);

  const initial = useMemo<{ loc: Location; select?: string }>(() => {
    const fileId = args?.fileId as string | undefined;
    const folderId = args?.folderId as string | undefined;
    if (fileId && nodes[fileId]) return { loc: { type: 'folder', id: nodes[fileId].parentId ?? ROOT_ID }, select: fileId };
    if (folderId && nodes[folderId]) return { loc: { type: 'folder', id: folderId } };
    return { loc: { type: 'folder', id: ROOT_ID } };
  }, []);

  const [history, setHistory] = useState<Location[]>([initial.loc]);
  const [cursor, setCursor] = useState(0);
  const loc = history[cursor];
  const [view, setView] = useState<'grid' | 'list'>('grid');
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set(initial.select ? [initial.select] : []));
  const [renaming, setRenaming] = useState<string | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [menu, setMenu] = useState<{ x: number; y: number; id?: string } | null>(null);
  const [organizing, setOrganizing] = useState(false);
  const [dropTarget, setDropTarget] = useState<string | null>(null);
  const gridRef = useRef<HTMLDivElement>(null);

  const go = (next: Location) => {
    if (sameLoc(next, loc)) return;
    setHistory([...history.slice(0, cursor + 1), next]);
    setCursor(cursor + 1);
    setSelected(new Set());
    setQuery('');
  };

  const title = loc.type === 'folder' ? nodes[loc.id]?.name ?? 'Files' : loc.type === 'recents' ? 'Recents' : loc.type === 'trash' ? 'Trash' : `#${loc.tag}`;
  useEffect(() => setTitle(windowId, title), [title, windowId, setTitle]);

  // If the folder we're in disappears (trashed elsewhere), fall back home.
  useEffect(() => {
    if (loc.type === 'folder' && (!nodes[loc.id] || isTrashed(nodes, loc.id))) go({ type: 'folder', id: ROOT_ID });
  }, [nodes]);

  const items = useMemo(() => {
    let list: VNode[];
    if (query.trim()) {
      const q = query.toLowerCase();
      list = allFiles(nodes).filter((n) => n.name.toLowerCase().includes(q) || n.tags?.some((t) => t.includes(q)));
    } else if (loc.type === 'folder') list = childrenOf(nodes, loc.id);
    else if (loc.type === 'recents') list = allFiles(nodes).filter((n) => n.kind !== 'folder').sort((a, b) => b.modified - a.modified).slice(0, 24);
    else if (loc.type === 'tag') list = allFiles(nodes).filter((n) => n.tags?.includes(loc.tag));
    else list = Object.values(nodes).filter((n) => n.trashed);
    if (loc.type === 'recents' && !query) return list;
    return [...list].sort((a, b) => (a.kind === 'folder' ? 0 : 1) - (b.kind === 'folder' ? 0 : 1) || a.name.localeCompare(b.name, undefined, { numeric: true }));
  }, [nodes, loc, query]);

  const open = (n: VNode) => {
    if (n.trashed) return;
    if (n.kind === 'folder') go({ type: 'folder', id: n.id });
    else if (appForFile(n.kind) === 'files') setPreview(n.id);
    else openApp(appForFile(n.kind), { args: { fileId: n.id } });
  };

  const select = (id: string, e: React.MouseEvent | React.KeyboardEvent) => {
    if (e.metaKey || e.ctrlKey) {
      const next = new Set(selected);
      next.has(id) ? next.delete(id) : next.add(id);
      setSelected(next);
    } else if (e.shiftKey && selected.size) {
      const ids = items.map((i) => i.id);
      const last = ids.indexOf([...selected].pop()!);
      const at = ids.indexOf(id);
      setSelected(new Set(ids.slice(Math.min(last, at), Math.max(last, at) + 1)));
    } else setSelected(new Set([id]));
  };

  const trashSelected = () => {
    selected.forEach((id) => (loc.type === 'trash' ? fs.restore(id) : fs.trash(id)));
    setSelected(new Set());
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (renaming || (e.target as HTMLElement).tagName === 'INPUT') return;
    const ids = items.map((i) => i.id);
    const cur = ids.indexOf([...selected].pop() ?? '');
    const cols = view === 'grid' ? Math.max(1, Math.floor((gridRef.current?.clientWidth ?? 600) / 112)) : 1;
    const move = (d: number) => {
      const next = ids[Math.min(ids.length - 1, Math.max(0, (cur < 0 ? 0 : cur + d)))];
      if (next) {
        setSelected(new Set([next]));
        document.getElementById(`file-${windowId}-${next}`)?.focus();
      }
    };
    if (e.key === 'ArrowRight') move(1);
    else if (e.key === 'ArrowLeft') move(-1);
    else if (e.key === 'ArrowDown') move(cols);
    else if (e.key === 'ArrowUp') move(-cols);
    else if (e.key === 'Enter' && selected.size === 1) open(nodes[[...selected][0]]);
    else if (e.key === 'F2' && selected.size === 1) setRenaming([...selected][0]);
    else if ((e.key === 'Delete' || e.key === 'Backspace') && selected.size) trashSelected();
    else if (e.key === ' ' && selected.size === 1) setPreview([...selected][0]);
    else if ((e.metaKey || e.ctrlKey) && e.key === 'a') setSelected(new Set(ids));
    else return;
    e.preventDefault();
  };

  const menuItems = (id?: string): MenuItem[] => {
    if (!id) {
      return [
        { label: 'New folder', icon: FolderPlus, onSelect: () => loc.type === 'folder' && setRenaming(fs.createFolder(loc.id)), disabled: loc.type !== 'folder' },
        { label: view === 'grid' ? 'View as list' : 'View as icons', icon: view === 'grid' ? List : LayoutGrid, onSelect: () => setView(view === 'grid' ? 'list' : 'grid') },
      ];
    }
    const n = nodes[id];
    if (n.trashed) return [{ label: 'Put back', icon: RotateCcw, onSelect: () => fs.restore(id) }];
    return [
      { label: 'Open', icon: ExternalLink, onSelect: () => open(n) },
      { label: 'Rename', icon: Pencil, onSelect: () => setRenaming(id) },
      ...TAGS.slice(0, 3).map((t, i) => ({
        label: `${n.tags?.includes(t.tag) ? 'Remove' : 'Tag'} “${t.tag}”`,
        icon: Tag,
        separatorBefore: i === 0,
        onSelect: () => fs.setTags(id, n.tags?.includes(t.tag) ? n.tags.filter((x) => x !== t.tag) : [...(n.tags ?? []), t.tag]),
      })),
      { label: 'Move to Trash', icon: Trash2, danger: true, separatorBefore: true, onSelect: () => fs.trash(id) },
    ];
  };

  // Breadcrumb for folder locations.
  const crumbs: VNode[] = [];
  if (loc.type === 'folder') {
    let cur: VNode | undefined = nodes[loc.id];
    while (cur) {
      crumbs.unshift(cur);
      cur = cur.parentId ? nodes[cur.parentId] : undefined;
    }
  }

  const folderShortcuts = ['Documents', 'Projects', 'Downloads', 'Pictures', 'Music'].map((name) => Object.values(nodes).find((n) => n.parentId === ROOT_ID && n.name === name && !n.trashed)).filter(Boolean) as VNode[];
  const favIcon = { Documents: FileText, Projects: Folder, Downloads: Download, Pictures: Image, Music } as Record<string, typeof Folder>;
  const trashCount = Object.values(nodes).filter((n) => n.trashed).length;
  const selectedSize = [...selected].reduce((a, id) => a + (nodes[id]?.size ?? 0), 0);

  const dragProps = (n: VNode) => ({
    draggable: !n.trashed,
    onDragStart: (e: React.DragEvent) => {
      const ids = selected.has(n.id) ? [...selected] : [n.id];
      e.dataTransfer.setData('application/x-aurora-files', JSON.stringify(ids));
      e.dataTransfer.effectAllowed = 'move';
    },
    ...(n.kind === 'folder' && !n.trashed
      ? {
          onDragOver: (e: React.DragEvent) => {
            if (!e.dataTransfer.types.includes('application/x-aurora-files')) return;
            e.preventDefault();
            setDropTarget(n.id);
          },
          onDragLeave: () => setDropTarget((t) => (t === n.id ? null : t)),
          onDrop: (e: React.DragEvent) => {
            e.preventDefault();
            setDropTarget(null);
            const ids = JSON.parse(e.dataTransfer.getData('application/x-aurora-files') || '[]') as string[];
            ids.filter((id) => id !== n.id).forEach((id) => fs.move(id, n.id));
            setSelected(new Set());
          },
        }
      : {}),
  });

  const sidebar = (
    <>
      <SidebarSection title="Places">
        <SidebarItem layoutGroup={`files-${windowId}`} icon={Home} label="Home" active={loc.type === 'folder' && loc.id === ROOT_ID} onClick={() => go({ type: 'folder', id: ROOT_ID })} />
        <SidebarItem layoutGroup={`files-${windowId}`} icon={Clock} label="Recents" active={loc.type === 'recents'} onClick={() => go({ type: 'recents' })} />
        {folderShortcuts.map((f) => (
          <SidebarItem key={f.id} layoutGroup={`files-${windowId}`} icon={favIcon[f.name] ?? Folder} label={f.name} active={loc.type === 'folder' && loc.id === f.id} onClick={() => go({ type: 'folder', id: f.id })} />
        ))}
      </SidebarSection>
      <SidebarSection title="Tags">
        {TAGS.map((t) => (
          <SidebarItem key={t.tag} layoutGroup={`files-${windowId}`} dotColor={tagColor(t.tag)} label={t.tag[0].toUpperCase() + t.tag.slice(1)} active={loc.type === 'tag' && loc.tag === t.tag} onClick={() => go({ type: 'tag', tag: t.tag })} />
        ))}
      </SidebarSection>
      <SidebarSection>
        <SidebarItem layoutGroup={`files-${windowId}`} icon={Trash2} label="Trash" trailing={trashCount || undefined} active={loc.type === 'trash'} onClick={() => go({ type: 'trash' })} />
      </SidebarSection>
    </>
  );

  return (
    <AppLayout sidebar={sidebar}>
      <Toolbar>
        <ToolButton icon={ArrowLeft} label="Back" disabled={cursor === 0} onClick={() => setCursor(cursor - 1)} />
        <ToolButton icon={ArrowRight} label="Forward" disabled={cursor >= history.length - 1} onClick={() => setCursor(cursor + 1)} />
        <nav aria-label="Path" className="flex min-w-0 flex-1 items-center gap-0.5 overflow-hidden text-[13px]">
          {loc.type === 'folder' ? (
            crumbs.map((c, i) => (
              <span key={c.id} className="flex min-w-0 items-center">
                {i > 0 && <span className="px-0.5 text-fg-subtle">/</span>}
                <button onClick={() => go({ type: 'folder', id: c.id })} className={clsx('truncate rounded-md px-1.5 py-0.5 hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)]', i === crumbs.length - 1 ? 'font-semibold' : 'text-fg-muted')}>
                  {c.name}
                </button>
              </span>
            ))
          ) : (
            <span className="px-1.5 font-semibold">{title}</span>
          )}
        </nav>
        <SearchField value={query} onChange={setQuery} placeholder="Search all files" label="Search files" className="hidden w-44 @[640px]:flex" />
        <Segmented
          label="View"
          value={view}
          onChange={setView}
          options={[
            { value: 'grid', label: '', ariaLabel: 'Icons', icon: LayoutGrid },
            { value: 'list', label: '', ariaLabel: 'List', icon: List },
          ]}
        />
        {loc.type === 'trash' ? (
          <button onClick={fs.emptyTrash} disabled={!trashCount} className="h-8 rounded-lg px-3 text-xs font-medium text-[oklch(0.62_0.2_25)] hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] disabled:opacity-40">
            Empty Trash
          </button>
        ) : (
          <>
            <ToolButton icon={FolderPlus} label="New folder" disabled={loc.type !== 'folder'} onClick={() => loc.type === 'folder' && setRenaming(fs.createFolder(loc.id))} />
            <button
              onClick={() => setOrganizing((v) => !v)}
              aria-pressed={organizing}
              className={clsx('flex h-8 items-center gap-1.5 rounded-lg px-2.5 text-xs font-medium', organizing ? 'bg-accent-fill text-white' : 'bg-accent-soft text-accent hover:brightness-110')}
            >
              <svg aria-hidden viewBox="0 0 24 24" className="size-3.5 fill-current">
                <path d="M12 2l1.8 5.4L19 9l-5.2 1.6L12 16l-1.8-5.4L5 9l5.2-1.6zM19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9z" />
              </svg>
              Organize
            </button>
          </>
        )}
      </Toolbar>

      <div className="relative flex min-h-0 flex-1">
        <div
          ref={gridRef}
          role={view === 'grid' ? 'listbox' : 'region'}
          aria-label={title}
          aria-multiselectable={view === 'grid' ? true : undefined}
          tabIndex={0}
          onKeyDown={onKeyDown}
          onClick={(e) => e.target === e.currentTarget && setSelected(new Set())}
          onContextMenu={(e) => {
            if (e.target !== e.currentTarget) return;
            e.preventDefault();
            setMenu({ x: e.clientX, y: e.clientY });
          }}
          className="min-w-0 flex-1 overflow-y-auto p-3 outline-none"
        >
          {items.length === 0 ? (
            loc.type === 'trash' ? (
              <EmptyState icon={Trash2} title="Trash is empty" body="Items you delete wait here until you empty the trash." />
            ) : (
              <EmptyState icon={Folder} title={query ? 'No matching files' : 'This folder is empty'} body={query ? 'Try a different name or tag.' : 'Drag files here, or create a folder.'} />
            )
          ) : view === 'grid' ? (
            <div className="grid grid-cols-[repeat(auto-fill,minmax(104px,1fr))] gap-1" onClick={(e) => e.target === e.currentTarget && setSelected(new Set())}>
              <AnimatePresence initial={false}>
                {items.map((n) => (
                  <motion.div
                    key={n.id}
                    layout
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: n.trashed && loc.type !== 'trash' ? 0.4 : 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.8 }}
                    transition={springs.snappy}
                    id={`file-${windowId}-${n.id}`}
                    role="option"
                    aria-selected={selected.has(n.id)}
                    aria-label={`${n.name}, ${KIND_LABEL[n.kind]}`}
                    tabIndex={-1}
                    onClick={(e) => select(n.id, e)}
                    onDoubleClick={() => open(n)}
                    onContextMenu={(e) => {
                      e.preventDefault();
                      if (!selected.has(n.id)) setSelected(new Set([n.id]));
                      setMenu({ x: e.clientX, y: e.clientY, id: n.id });
                    }}
                    {...(dragProps(n) as object)}
                    className={clsx(
                      'flex cursor-default flex-col items-center gap-1.5 rounded-xl p-2 text-center outline-none',
                      selected.has(n.id) ? 'bg-[color-mix(in_oklab,var(--color-accent)_20%,transparent)]' : 'hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]',
                      dropTarget === n.id && 'ring-2 ring-accent',
                    )}
                  >
                    <div className="grid h-14 place-items-center">
                      <FileGlyph node={n} size={52} />
                    </div>
                    {renaming === n.id ? (
                      <RenameField node={n} onDone={() => setRenaming(null)} />
                    ) : (
                      <span className={clsx('line-clamp-2 w-full break-words text-[12px] leading-tight', selected.has(n.id) && 'font-medium')}>{n.name}</span>
                    )}
                    {n.tags && n.tags.length > 0 && (
                      <span className="flex gap-0.5">
                        {n.tags.map((t) => (
                          <span key={t} className="size-1.5 rounded-full" style={{ background: tagColor(t) }} />
                        ))}
                      </span>
                    )}
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          ) : (
            <table className="w-full table-fixed text-[13px]">
              <thead>
                <tr className="text-left text-[11px] uppercase tracking-wider text-fg-subtle">
                  <th className="px-2 pb-2 font-medium">Name</th>
                  <th className="hidden w-32 px-2 pb-2 font-medium @[520px]:table-cell">Modified</th>
                  <th className="hidden w-24 px-2 pb-2 text-right font-medium @[640px]:table-cell">Size</th>
                  <th className="hidden w-28 px-2 pb-2 font-medium @[760px]:table-cell">Kind</th>
                </tr>
              </thead>
              <tbody>
                {items.map((n) => (
                  <tr
                    key={n.id}
                    id={`file-${windowId}-${n.id}`}
                    tabIndex={-1}
                    aria-selected={selected.has(n.id)}
                    onClick={(e) => select(n.id, e)}
                    onDoubleClick={() => open(n)}
                    onContextMenu={(e) => {
                      e.preventDefault();
                      if (!selected.has(n.id)) setSelected(new Set([n.id]));
                      setMenu({ x: e.clientX, y: e.clientY, id: n.id });
                    }}
                    {...(dragProps(n) as object)}
                    className={clsx('cursor-default outline-none', selected.has(n.id) ? 'bg-[color-mix(in_oklab,var(--color-accent)_20%,transparent)]' : 'odd:bg-[color-mix(in_oklab,var(--text-1)_3%,transparent)]', dropTarget === n.id && 'outline outline-2 outline-accent')}
                  >
                    <td className="rounded-l-lg px-2 py-1.5">
                      <span className="flex items-center gap-2.5">
                        <span className="grid w-6 shrink-0 place-items-center">
                          <FileGlyph node={n} size={20} />
                        </span>
                        {renaming === n.id ? <RenameField node={n} onDone={() => setRenaming(null)} /> : <span className="truncate">{n.name}</span>}
                        {n.tags?.map((t) => <span key={t} className="size-1.5 shrink-0 rounded-full" style={{ background: tagColor(t) }} />)}
                      </span>
                    </td>
                    <td className="hidden px-2 text-fg-muted @[520px]:table-cell">{relativeTime(n.modified)}</td>
                    <td className="hidden px-2 text-right tabular-nums text-fg-muted @[640px]:table-cell">{n.kind === 'folder' ? '—' : formatBytes(n.size)}</td>
                    <td className="hidden rounded-r-lg px-2 text-fg-muted @[760px]:table-cell">{KIND_LABEL[n.kind]}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        <AnimatePresence>
          {organizing && <OrganizePanel key="organize" folderId={loc.type === 'folder' ? loc.id : ROOT_ID} onClose={() => setOrganizing(false)} />}
        </AnimatePresence>
      </div>

      <footer className="flex h-7 shrink-0 items-center gap-3 border-t hairline px-3 text-[11px] text-fg-subtle">
        <span>
          {items.length} {items.length === 1 ? 'item' : 'items'}
        </span>
        {selected.size > 0 && (
          <span>
            {selected.size} selected{selectedSize ? ` · ${formatBytes(selectedSize)}` : ''}
          </span>
        )}
        {loc.type === 'folder' && <span className="ml-auto truncate">{pathOf(nodes, loc.id)}</span>}
      </footer>

      {menu && <ContextMenu x={menu.x} y={menu.y} items={menuItems(menu.id)} onClose={() => setMenu(null)} />}
      <AnimatePresence>{preview && nodes[preview] && <QuickLook node={nodes[preview]} onClose={() => setPreview(null)} />}</AnimatePresence>
    </AppLayout>
  );
}

function RenameField({ node, onDone }: { node: VNode; onDone: () => void }) {
  const [value, setValue] = useState(node.name);
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.focus();
    // Select the base name, not the extension.
    const dot = node.kind === 'folder' ? -1 : node.name.lastIndexOf('.');
    el.setSelectionRange(0, dot > 0 ? dot : node.name.length);
  }, [node]);
  const commit = () => {
    useFileStore.getState().rename(node.id, value);
    onDone();
  };
  return (
    <input
      ref={ref}
      aria-label="New name"
      value={value}
      onChange={(e) => setValue(e.target.value)}
      onClick={(e) => e.stopPropagation()}
      onBlur={commit}
      onKeyDown={(e) => {
        e.stopPropagation();
        if (e.key === 'Enter') commit();
        if (e.key === 'Escape') onDone();
      }}
      className="w-full rounded-md bg-[var(--glass-tint)] px-1 text-center text-[12px] outline outline-2 outline-accent"
    />
  );
}

function QuickLook({ node, onClose }: { node: VNode; onClose: () => void }) {
  useEffect(() => {
    const k = (e: KeyboardEvent) => (e.key === 'Escape' || e.key === ' ') && (e.preventDefault(), onClose());
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, [onClose]);
  return (
    <motion.div className="absolute inset-0 z-30 grid place-items-center bg-black/25 p-6" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose}>
      <motion.div
        role="dialog"
        aria-label={`Preview of ${node.name}`}
        initial={{ scale: 0.85, y: 20 }}
        animate={{ scale: 1, y: 0 }}
        exit={{ scale: 0.9, opacity: 0 }}
        transition={springs.elastic}
        onClick={(e) => e.stopPropagation()}
        className="glass acrylic w-full max-w-md overflow-hidden rounded-2xl"
        style={{ boxShadow: 'var(--shadow-window)' }}
      >
        <div className="flex items-center gap-2 border-b hairline px-3 py-2">
          <span className="min-w-0 flex-1 truncate text-sm font-medium">{node.name}</span>
          <button aria-label="Close preview" onClick={onClose} className="grid size-7 place-items-center rounded-full hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
            <X className="size-4" />
          </button>
        </div>
        <div className="grid min-h-48 place-items-center p-6">
          <FileGlyph node={node} size={node.kind === 'image' ? 320 : 120} />
        </div>
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 border-t hairline px-4 py-3 text-xs">
          <dt className="text-fg-subtle">Kind</dt>
          <dd>{KIND_LABEL[node.kind]}</dd>
          <dt className="text-fg-subtle">Size</dt>
          <dd className="tabular-nums">{formatBytes(node.size)}</dd>
          <dt className="text-fg-subtle">Modified</dt>
          <dd>{new Date(node.modified).toLocaleString()}</dd>
        </dl>
      </motion.div>
    </motion.div>
  );
}
