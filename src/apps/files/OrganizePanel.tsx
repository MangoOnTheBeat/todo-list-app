import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Check, Sparkles, Undo2, X } from 'lucide-react';
import clsx from 'clsx';
import { apply, plan } from '@/services/ai/organizer';
import { springs } from '@/system/motion';
import { useFileStore } from '@/system/store/fileStore';
import { useNotificationStore } from '@/system/store/notificationStore';

/** Aurora AI's proposal for tidying the current folder. Nothing moves until you apply it. */
export function OrganizePanel({ folderId, onClose }: { folderId: string; onClose: () => void }) {
  const nodes = useFileStore((s) => s.nodes);
  // Re-plan whenever the tree changes (e.g. after an undo).
  const groups = useMemo(() => plan(folderId), [folderId, nodes]);
  const [off, setOff] = useState<Set<string>>(new Set());
  const [undo, setUndo] = useState<(() => void) | null>(null);
  const chosen = groups.filter((g) => !off.has(g.id));
  const folderName = nodes[folderId]?.name ?? 'this folder';

  return (
    <motion.aside
      aria-label="Organize suggestions"
      initial={{ x: 40, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: 40, opacity: 0 }}
      transition={springs.panel}
      className="flex w-[290px] shrink-0 flex-col border-l hairline"
      style={{ background: 'color-mix(in oklab, var(--color-accent) 7%, transparent)' }}
    >
      <div className="flex items-center gap-2 px-4 pb-2 pt-3">
        <Sparkles className="size-4 text-accent" />
        <h3 className="flex-1 text-sm font-semibold">Organize {folderName}</h3>
        <button aria-label="Close suggestions" onClick={onClose} className="grid size-6 place-items-center rounded-full hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
          <X className="size-3.5" />
        </button>
      </div>

      <div className="min-h-0 flex-1 space-y-2 overflow-y-auto px-3 pb-3">
        {undo ? (
          <div className="glass-well rounded-xl p-4 text-center">
            <Check className="mx-auto size-6 text-accent" />
            <p className="mt-2 text-sm font-medium">Organized</p>
            <p className="mt-1 text-xs text-fg-subtle">Changed your mind? Everything can go back where it was.</p>
            <button
              onClick={() => {
                undo();
                setUndo(null);
              }}
              className="mx-auto mt-3 flex items-center gap-1.5 rounded-full bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] px-3 py-1.5 text-xs font-medium"
            >
              <Undo2 className="size-3.5" /> Undo
            </button>
          </div>
        ) : groups.length === 0 ? (
          <p className="glass-well rounded-xl p-4 text-xs leading-relaxed text-fg-muted">
            {folderName} already looks tidy. Try Downloads — it tends to collect clutter.
          </p>
        ) : (
          groups.map((g) => {
            const on = !off.has(g.id);
            return (
              <label key={g.id} className={clsx('block cursor-pointer rounded-xl p-3 transition-colors', on ? 'glass' : 'glass-well opacity-60')}>
                <span className="flex items-start gap-2.5">
                  <input
                    type="checkbox"
                    checked={on}
                    onChange={() => {
                      const n = new Set(off);
                      on ? n.add(g.id) : n.delete(g.id);
                      setOff(n);
                    }}
                    className="mt-0.5 accent-[var(--color-accent)]"
                  />
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-2">
                      <span className="text-[13px] font-semibold">→ {g.folder}</span>
                      <span className="ml-auto text-[10px] tabular-nums text-fg-subtle">{Math.round(g.confidence * 100)}% sure</span>
                    </span>
                    <span className="mt-0.5 block text-[11px] text-fg-muted">{g.reason}</span>
                    <span className="mt-1.5 flex flex-wrap gap-1">
                      {g.files.map((f) => (
                        <span key={f.id} className="max-w-full truncate rounded-md bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] px-1.5 py-0.5 text-[10px]">
                          {f.name}
                        </span>
                      ))}
                    </span>
                  </span>
                </span>
              </label>
            );
          })
        )}
      </div>

      {!undo && groups.length > 0 && (
        <div className="border-t hairline p-3">
          <button
            disabled={!chosen.length}
            onClick={() => {
              const u = apply(folderId, chosen);
              setUndo(() => u);
              const moved = chosen.reduce((a, g) => a + g.files.length, 0);
              useNotificationStore.getState().post({ appId: 'files', title: `Organized ${folderName}`, body: `Moved ${moved} files into ${chosen.length} folders.`, priority: 'low', silent: true });
            }}
            className="h-9 w-full rounded-lg bg-accent text-sm font-medium text-white disabled:opacity-40"
          >
            Move {chosen.reduce((a, g) => a + g.files.length, 0)} files
          </button>
        </div>
      )}
    </motion.aside>
  );
}
