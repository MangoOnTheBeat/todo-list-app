import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Mic, Search } from 'lucide-react';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { FileGlyph } from '@/apps/files/FileGlyph';
import { runCommand } from '@/services/ai/intents';
import { appForFile, formatBytes, relativeTime } from '@/services/vfs';
import { springs } from '@/system/motion';
import type { AiCard, AiMessage } from '@/system/store/aiStore';
import { calColor } from '@/system/store/calendarStore';
import { useWindowStore } from '@/system/store/windowStore';
import { AuroraOrb } from './AuroraOrb';

const fmt = (t: number) => new Date(t).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });

/** Reveals text progressively, like it's being written. Skipped for older messages. */
function useTypewriter(text: string, enabled: boolean) {
  const [n, setN] = useState(enabled ? 0 : text.length);
  useEffect(() => {
    if (!enabled) return;
    let i = 0;
    const t = setInterval(() => {
      i += Math.max(2, Math.ceil(text.length / 40));
      setN(Math.min(text.length, i));
      if (i >= text.length) clearInterval(t);
    }, 16);
    return () => clearInterval(t);
  }, [text, enabled]);
  return text.slice(0, n);
}

export function MessageView({ m, latest }: { m: AiMessage; latest: boolean }) {
  const shown = useTypewriter(m.text, latest && m.role === 'assistant');
  const done = shown.length === m.text.length;

  if (m.role === 'user') {
    return (
      <motion.div initial={{ opacity: 0, y: 8, scale: 0.97 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={springs.snappy} className="flex justify-end">
        <p className="max-w-[85%] rounded-2xl rounded-br-md bg-accent px-3.5 py-2 text-[13px] leading-relaxed text-white shadow-[0_6px_18px_-8px_var(--color-accent)]">
          {m.via === 'voice' && <Mic aria-label="Spoken" className="mr-1 inline size-3 -translate-y-px opacity-80" />}
          {m.via === 'search' && <Search aria-label="From search" className="mr-1 inline size-3 -translate-y-px opacity-80" />}
          {m.text}
        </p>
      </motion.div>
    );
  }

  return (
    <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={springs.snappy} className="flex gap-2.5">
      <AuroraOrb size={22} className="mt-0.5" />
      <div className="min-w-0 flex-1 space-y-2">
        <p className="text-[13px] leading-relaxed">{shown}</p>
        {done && m.cards?.map((c, i) => <Card key={i} card={c} />)}
        {done && m.actions && m.actions.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {m.actions.map((a, i) => (
              <ActionButton key={a.label + i} label={a.label} primary={a.primary} run={a.run} />
            ))}
          </div>
        )}
      </div>
    </motion.div>
  );
}

function ActionButton({ label, primary, run }: { label: string; primary?: boolean; run: () => void }) {
  const [used, setUsed] = useState(false);
  return (
    <motion.button
      whileTap={{ scale: 0.94 }}
      disabled={used}
      onClick={() => {
        setUsed(true);
        run();
      }}
      className={clsx('rounded-full px-3 py-1 text-xs font-medium transition-opacity disabled:opacity-45', primary ? 'bg-accent text-white' : 'bg-[color-mix(in_oklab,var(--text-1)_9%,transparent)] hover:bg-[color-mix(in_oklab,var(--text-1)_15%,transparent)]')}
    >
      {label}
    </motion.button>
  );
}

function Card({ card }: { card: AiCard }) {
  const openApp = useWindowStore((s) => s.openApp);
  switch (card.type) {
    case 'bullets':
      return (
        <ul className="glass-well space-y-1 rounded-xl p-3 text-[13px] leading-relaxed">
          {card.items.map((it, i) => (
            <li key={i} className="flex gap-2">
              <span className="mt-2 size-1 shrink-0 rounded-full bg-accent" />
              <span>{it}</span>
            </li>
          ))}
        </ul>
      );
    case 'events':
      return (
        <ul className="glass-well divide-y divide-[var(--glass-border)] rounded-xl">
          {card.events.map((e) => (
            <li key={e.id} className="flex gap-2.5 px-3 py-2">
              <span className="w-1 shrink-0 rounded-full" style={{ background: calColor(e.calendar) }} />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-medium">{e.title}</span>
                <span className="block text-[11px] text-fg-subtle">
                  {new Date(e.start).toLocaleDateString(undefined, { weekday: 'short' })} {fmt(e.start)}–{fmt(e.end)}
                  {e.location ? ` · ${e.location}` : ''}
                </span>
              </span>
            </li>
          ))}
        </ul>
      );
    case 'files':
      return (
        <ul className="glass-well divide-y divide-[var(--glass-border)] rounded-xl">
          {card.files.map((f) => (
            <li key={f.id}>
              <button onClick={() => openApp(f.kind === 'folder' ? 'files' : appForFile(f.kind), { args: f.kind === 'folder' ? { folderId: f.id } : { fileId: f.id } })} className="flex w-full items-center gap-2.5 px-3 py-2 text-left hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]">
                <span className="grid w-6 place-items-center">
                  <FileGlyph node={f} size={22} />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[13px] font-medium">{f.name}</span>
                  <span className="block text-[11px] text-fg-subtle">
                    {relativeTime(f.modified)}
                    {f.size ? ` · ${formatBytes(f.size)}` : ''}
                  </span>
                </span>
              </button>
            </li>
          ))}
        </ul>
      );
    case 'procs':
      return (
        <ul className="glass-well divide-y divide-[var(--glass-border)] rounded-xl text-[13px]">
          {card.procs.map((p) => (
            <li key={p.pid} className="flex items-center gap-2.5 px-3 py-2">
              {p.appId ? <AppIcon appId={p.appId} size={18} /> : <span className="size-[18px] rounded-md bg-[color-mix(in_oklab,var(--text-1)_12%,transparent)]" />}
              <span className="min-w-0 flex-1 truncate">{p.name}</span>
              <span className="tabular-nums text-fg-muted">{p.cpu.toFixed(1)}%</span>
              <span className="w-16 text-right tabular-nums text-fg-subtle">{p.mem >= 1024 ? `${(p.mem / 1024).toFixed(1)} GB` : `${Math.round(p.mem)} MB`}</span>
            </li>
          ))}
        </ul>
      );
    case 'tips':
      return <Tips tips={card.tips} />;
  }
}

export function Tips({ tips }: { tips: Extract<AiCard, { type: 'tips' }>['tips'] }) {
  return (
    <ul className="space-y-2">
      {tips.map((t) => (
        <li key={t.id} className="glass-well rounded-xl p-3">
          <p className="text-[13px] font-semibold">{t.title}</p>
          <p className="mt-0.5 text-xs leading-relaxed text-fg-muted">{t.body}</p>
          {t.action && (
            <button onClick={() => runCommand(t.action!.command)} className="mt-2 rounded-full bg-accent-soft px-3 py-1 text-xs font-medium text-accent hover:bg-accent hover:text-white">
              {t.action.label}
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}
