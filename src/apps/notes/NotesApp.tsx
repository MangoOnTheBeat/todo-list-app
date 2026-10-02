import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { FileText, Pin, PinOff, Plus, Sparkles, StickyNote, Trash2 } from 'lucide-react';
import clsx from 'clsx';
import { AppLayout, EmptyState, SearchField, Toolbar, ToolButton } from '@/components/ui/AppKit';
import { summarize } from '@/services/ai/text';
import { relativeTime } from '@/services/vfs';
import { springs } from '@/system/motion';
import { useFileStore } from '@/system/store/fileStore';
import { useNotesStore } from '@/system/store/notesStore';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';

/**
 * Notes. Edits its own notes (persisted locally), or — when launched with a fileId —
 * edits that document from Files directly.
 */
export default function NotesApp({ windowId, args }: AppProps) {
  const { notes, create, update, remove } = useNotesStore();
  const fileId = args?.fileId as string | undefined;
  const file = useFileStore((s) => (fileId ? s.nodes[fileId] : undefined));
  const [activeId, setActiveId] = useState<string | null>(fileId ? `file:${fileId}` : notes[0]?.id ?? null);
  const [query, setQuery] = useState('');
  const [summary, setSummary] = useState<string[] | null>(null);
  const setTitle = useWindowStore((s) => s.setTitle);
  const bodyRef = useRef<HTMLTextAreaElement>(null);

  const list = useMemo(() => {
    const q = query.toLowerCase();
    return notes
      .filter((n) => !q || n.title.toLowerCase().includes(q) || n.body.toLowerCase().includes(q))
      .sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.updated - a.updated);
  }, [notes, query]);

  const isFile = activeId?.startsWith('file:');
  const note = isFile ? undefined : notes.find((n) => n.id === activeId);
  const title = isFile ? file?.name ?? '' : note?.title ?? '';
  const body = isFile ? file?.content ?? '' : note?.body ?? '';

  useEffect(() => setTitle(windowId, title || 'Notes'), [title, windowId, setTitle]);
  useEffect(() => setSummary(null), [activeId]);

  const setBody = (v: string) => (isFile && fileId ? useFileStore.getState().writeContent(fileId, v) : note && update(note.id, { body: v }));
  const words = body.trim() ? body.trim().split(/\s+/).length : 0;

  const newNote = () => {
    const id = create();
    setActiveId(id);
    setQuery('');
    setTimeout(() => document.getElementById(`note-title-${windowId}`)?.focus(), 30);
  };

  const sidebar = (
    <div className="flex h-full flex-col pt-2">
      <div className="flex items-center gap-1.5">
        <SearchField value={query} onChange={setQuery} placeholder="Search notes" label="Search notes" className="flex-1" />
        <ToolButton icon={Plus} label="New note" onClick={newNote} />
      </div>
      {file && (
        <>
          <p className="mt-3 px-2 text-[11px] font-semibold uppercase tracking-[0.1em] text-fg-subtle">From Files</p>
          <NoteRow active={isFile} title={file.name} body={file.content ?? ''} time={file.modified} icon onClick={() => setActiveId(`file:${file.id}`)} />
        </>
      )}
      <p className="mt-3 px-2 text-[11px] font-semibold uppercase tracking-[0.1em] text-fg-subtle">Notes</p>
      <ul className="mt-1 space-y-1">
        <AnimatePresence initial={false}>
          {list.map((n) => (
            <motion.li key={n.id} layout initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, height: 0 }} transition={springs.snappy}>
              <NoteRow active={n.id === activeId} title={n.title || 'New note'} body={n.body} time={n.updated} pinned={n.pinned} hue={n.hue} onClick={() => setActiveId(n.id)} />
            </motion.li>
          ))}
        </AnimatePresence>
      </ul>
    </div>
  );

  return (
    <AppLayout sidebar={sidebar} sidebarWidth={240}>
      {!note && !isFile ? (
        <EmptyState icon={StickyNote} title="No note selected" body="Pick a note or start a new one." action={<button onClick={newNote} className="rounded-lg bg-accent px-3 py-1.5 text-xs font-medium text-white">New note</button>} />
      ) : (
        <>
          <Toolbar>
            <span className="text-xs text-fg-subtle">{isFile ? file?.name : `Edited ${relativeTime(note!.updated)}`}</span>
            <span className="ml-auto text-xs tabular-nums text-fg-subtle">{words} words</span>
            <button
              onClick={() => setSummary(summarize(`${title}. ${body}`))}
              className="flex h-8 items-center gap-1.5 rounded-lg bg-accent-soft px-2.5 text-xs font-medium text-accent hover:brightness-110"
            >
              <Sparkles className="size-3.5" /> Summarize
            </button>
            {note && (
              <>
                <ToolButton icon={note.pinned ? PinOff : Pin} label={note.pinned ? 'Unpin' : 'Pin'} active={note.pinned} onClick={() => update(note.id, { pinned: !note.pinned })} />
                <ToolButton
                  icon={Trash2}
                  label="Delete note"
                  onClick={() => {
                    const idx = list.findIndex((n) => n.id === note.id);
                    remove(note.id);
                    setActiveId(list[idx + 1]?.id ?? list[idx - 1]?.id ?? null);
                  }}
                />
              </>
            )}
          </Toolbar>
          <div className="min-h-0 flex-1 overflow-y-auto px-8 py-6 @container">
            <AnimatePresence>
              {summary && (
                <motion.aside
                  initial={{ opacity: 0, y: -8, height: 0 }}
                  animate={{ opacity: 1, y: 0, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={springs.panel}
                  className="mb-5 overflow-hidden rounded-xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-accent-soft"
                >
                  <div className="p-4">
                    <p className="flex items-center gap-1.5 text-xs font-semibold text-accent">
                      <Sparkles className="size-3.5" /> Summary
                    </p>
                    <ul className="mt-2 list-disc space-y-1 pl-4 text-[13px] leading-relaxed">
                      {summary.map((s, i) => (
                        <li key={i}>{s}</li>
                      ))}
                    </ul>
                  </div>
                </motion.aside>
              )}
            </AnimatePresence>
            {isFile ? (
              <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
            ) : (
              <input
                id={`note-title-${windowId}`}
                aria-label="Title"
                value={title}
                onChange={(e) => update(note!.id, { title: e.target.value })}
                onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), bodyRef.current?.focus())}
                placeholder="Title"
                className="w-full bg-transparent text-2xl font-semibold tracking-tight outline-none placeholder:text-fg-subtle"
              />
            )}
            <textarea
              ref={bodyRef}
              aria-label="Note body"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Start writing…"
              className="mt-3 min-h-[60%] w-full resize-none bg-transparent text-[15px] leading-[1.7] outline-none placeholder:text-fg-subtle"
              style={{ height: 'calc(100% - 3rem)' }}
            />
          </div>
        </>
      )}
    </AppLayout>
  );
}

function NoteRow({ active, title, body, time, pinned, hue, icon, onClick }: { active?: boolean; title: string; body: string; time: number; pinned?: boolean; hue?: number; icon?: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} aria-current={active ? 'true' : undefined} className={clsx('relative w-full rounded-xl px-3 py-2 text-left', active ? 'bg-[color-mix(in_oklab,var(--color-accent)_18%,transparent)]' : 'hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]')}>
      <span className="flex items-center gap-1.5">
        {icon ? <FileText className="size-3.5 text-accent" /> : <span className="size-2 shrink-0 rounded-full" style={{ background: `oklch(0.72 0.14 ${hue})` }} />}
        <span className="min-w-0 flex-1 truncate text-[13px] font-semibold">{title}</span>
        {pinned && <Pin className="size-3 text-fg-subtle" />}
      </span>
      <span className="mt-0.5 flex gap-2 text-[11px] text-fg-subtle">
        <span className="shrink-0">{relativeTime(time)}</span>
        <span className="truncate">{body.split('\n').find((l) => l.trim()) ?? 'No text'}</span>
      </span>
    </button>
  );
}
