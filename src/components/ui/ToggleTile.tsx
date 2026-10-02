import { motion } from 'framer-motion';
import clsx from 'clsx';
import type { LucideIcon } from 'lucide-react';
import { springs } from '@/system/motion';

interface Props {
  label: string;
  detail?: string;
  icon: LucideIcon;
  on: boolean;
  onToggle: () => void;
}

/** Quick Settings tile: the icon disc lights up in accent when on. */
export function ToggleTile({ label, detail, icon: Icon, on, onToggle }: Props) {
  return (
    <motion.button
      type="button"
      role="switch"
      aria-checked={on}
      onClick={onToggle}
      whileTap={{ scale: 0.95 }}
      transition={springs.snappy}
      className={clsx(
        'flex min-w-0 items-center gap-2.5 rounded-2xl p-2 pr-3 text-left transition-colors',
        on ? 'bg-[color-mix(in_oklab,var(--color-accent)_18%,transparent)]' : 'glass-well',
      )}
    >
      <span
        className={clsx(
          'grid size-8 shrink-0 place-items-center rounded-full transition-all',
          on ? 'bg-accent text-white shadow-[0_0_16px_-3px_var(--color-accent)]' : 'bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] text-fg-muted',
        )}
      >
        <Icon className="size-4" />
      </span>
      <span className="min-w-0">
        <span className="block truncate text-[13px] font-medium">{label}</span>
        {detail && <span className="block truncate text-[11px] text-fg-subtle">{detail}</span>}
      </span>
    </motion.button>
  );
}
