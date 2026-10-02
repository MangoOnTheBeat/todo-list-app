import { motion } from 'framer-motion';
import { CornerDownLeft } from 'lucide-react';
import clsx from 'clsx';
import type { SearchResponse, SearchResult } from '@/services/search';
import { springs } from '@/system/motion';
import { AppIcon } from './AppIcon';

interface Props {
  response: SearchResponse;
  active: number;
  onHover: (i: number) => void;
  onRun: (r: SearchResult) => void;
  idPrefix: string;
}

/** Grouped results with a highlighted "top hit". The active row follows the keyboard. */
export function SearchResults({ response, active, onHover, onRun, idPrefix }: Props) {
  const { top, sections, flat } = response;
  if (flat.length === 0) {
    return <p className="px-4 py-10 text-center text-sm text-fg-subtle">No matches. Try an app name, a file, or something like “dark mode”.</p>;
  }
  let i = top ? 1 : 0;
  return (
    <div role="listbox" id={`${idPrefix}-list`} aria-label="Search results" className="space-y-3">
      {top && (
        <div>
          <SectionLabel>Top hit</SectionLabel>
          <Row r={top} index={0} active={active === 0} onHover={onHover} onRun={onRun} big idPrefix={idPrefix} />
        </div>
      )}
      {sections.map((sec) => (
        <div key={sec.label}>
          <SectionLabel>{sec.label}</SectionLabel>
          {sec.results.map((r) => {
            const idx = i++;
            return <Row key={r.id} r={r} index={idx} active={active === idx} onHover={onHover} onRun={onRun} idPrefix={idPrefix} />;
          })}
        </div>
      ))}
    </div>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return <p className="px-3 pb-1 text-[11px] font-medium uppercase tracking-[0.12em] text-fg-subtle">{children}</p>;
}

function Row({ r, index, active, onHover, onRun, big, idPrefix }: { r: SearchResult; index: number; active: boolean; onHover: (i: number) => void; onRun: (r: SearchResult) => void; big?: boolean; idPrefix: string }) {
  const Icon = r.icon;
  return (
    <div
      id={`${idPrefix}-opt-${index}`}
      role="option"
      aria-selected={active}
      onMouseMove={() => !active && onHover(index)}
      onClick={() => onRun(r)}
      className={clsx('relative flex cursor-default items-center gap-3 rounded-xl px-3', big ? 'py-2.5' : 'py-1.5')}
    >
      {active && (
        <motion.span
          layoutId={`${idPrefix}-active`}
          transition={springs.snappy}
          className="absolute inset-0 rounded-xl bg-[color-mix(in_oklab,var(--color-accent)_20%,transparent)] ring-1 ring-[color-mix(in_oklab,var(--color-accent)_35%,transparent)]"
        />
      )}
      <span className="relative">
        {r.appId ? (
          <AppIcon appId={r.appId} size={big ? 36 : 26} />
        ) : (
          Icon && (
            <span className={clsx('grid place-items-center rounded-lg glass-well text-fg-muted', big ? 'size-9' : 'size-[26px]')}>
              <Icon className={big ? 'size-5' : 'size-3.5'} />
            </span>
          )
        )}
      </span>
      <span className="relative min-w-0 flex-1">
        <span className={clsx('block truncate font-medium', big ? 'text-[15px]' : 'text-[13px]')}>{r.title}</span>
        {r.subtitle && <span className="block truncate text-xs text-fg-subtle">{r.subtitle}</span>}
      </span>
      {active && <CornerDownLeft aria-hidden className="relative size-3.5 shrink-0 text-fg-subtle" />}
    </div>
  );
}
