import { useId } from 'react';
import { motion } from 'framer-motion';
import clsx from 'clsx';
import type { LucideIcon } from 'lucide-react';
import { springs } from '@/system/motion';

/**
 * Shared building blocks for Aurora apps. Every app window is a size container, so
 * layouts respond to the *window* width (`@container` queries), not the screen.
 */

export function AppLayout({ sidebar, children, sidebarWidth = 208, className }: { sidebar?: React.ReactNode; children: React.ReactNode; sidebarWidth?: number; className?: string }) {
  return (
    <div className={clsx('@container flex h-full min-h-0', className)}>
      {sidebar && (
        // A plain container, not <aside>: several windows open at once would otherwise
        // produce indistinguishable complementary landmarks.
        <div
          className="hidden shrink-0 flex-col overflow-y-auto border-r hairline px-2.5 pb-3 @[560px]:flex"
          style={{ width: sidebarWidth, background: 'color-mix(in oklab, var(--text-1) 3%, transparent)' }}
        >
          {sidebar}
        </div>
      )}
      <div className="flex min-w-0 flex-1 flex-col" style={{ background: 'var(--app-surface)' }}>
        {children}
      </div>
    </div>
  );
}

export function SidebarSection({ title, children }: { title?: string; children: React.ReactNode }) {
  return (
    <div className="mt-3 first:mt-1">
      {title && <p className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-[0.1em] text-fg-subtle">{title}</p>}
      <ul className="space-y-0.5">{children}</ul>
    </div>
  );
}

export function SidebarItem({
  icon: Icon,
  label,
  active,
  onClick,
  trailing,
  layoutGroup = 'sidebar',
  dotColor,
}: {
  icon?: LucideIcon;
  label: string;
  active?: boolean;
  onClick: () => void;
  trailing?: React.ReactNode;
  layoutGroup?: string;
  dotColor?: string;
}) {
  return (
    <li>
      <button
        onClick={onClick}
        aria-current={active ? 'page' : undefined}
        className={clsx('relative flex h-8 w-full items-center gap-2.5 rounded-lg px-2 text-left text-[13px]', active ? 'font-medium text-fg' : 'text-fg-muted hover:text-fg')}
      >
        {active && <motion.span layoutId={`${layoutGroup}-active`} transition={springs.snappy} className="absolute inset-0 rounded-lg bg-[color-mix(in_oklab,var(--color-accent)_18%,transparent)]" />}
        {Icon && <Icon className={clsx('relative size-4 shrink-0', active && 'text-accent')} />}
        {dotColor && <span className="relative size-2.5 shrink-0 rounded-full" style={{ background: dotColor }} />}
        <span className="relative min-w-0 flex-1 truncate">{label}</span>
        {trailing && <span className="relative text-[11px] tabular-nums text-fg-subtle">{trailing}</span>}
      </button>
    </li>
  );
}

export function Toolbar({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={clsx('flex h-12 shrink-0 items-center gap-2 border-b hairline px-3', className)}>{children}</div>;
}

export function ToolButton({ icon: Icon, label, onClick, active, disabled, className }: { icon: LucideIcon; label: string; onClick?: () => void; active?: boolean; disabled?: boolean; className?: string }) {
  return (
    <motion.button
      type="button"
      aria-label={label}
      title={label}
      aria-pressed={active}
      disabled={disabled}
      onClick={onClick}
      whileTap={disabled ? undefined : { scale: 0.88 }}
      transition={springs.snappy}
      className={clsx(
        'grid size-8 shrink-0 place-items-center rounded-lg transition-colors disabled:opacity-35',
        active ? 'bg-[color-mix(in_oklab,var(--color-accent)_20%,transparent)] text-accent' : 'text-fg-muted enabled:hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] enabled:hover:text-fg',
        className,
      )}
    >
      <Icon className="size-4" />
    </motion.button>
  );
}

export function Segmented<T extends string>({ value, onChange, options, label }: { value: T; onChange: (v: T) => void; options: { value: T; label: string; ariaLabel?: string; icon?: LucideIcon }[]; label: string }) {
  const group = useId();
  return (
    <div role="radiogroup" aria-label={label} className="glass-well flex shrink-0 gap-0.5 rounded-lg p-0.5">
      {options.map((o) => {
        const on = o.value === value;
        const Icon = o.icon;
        return (
          <button
            key={o.value}
            role="radio"
            aria-checked={on}
            aria-label={o.ariaLabel}
            title={o.ariaLabel}
            onClick={() => onChange(o.value)}
            className={clsx('relative flex h-7 items-center gap-1.5 rounded-md px-2.5 text-xs font-medium', on ? 'text-fg' : 'text-fg-muted hover:text-fg')}
          >
            {on && <motion.span layoutId={`seg-${group}`} transition={springs.snappy} className="glass absolute inset-0 rounded-md" />}
            {Icon && <Icon className="relative size-3.5" />}
            <span className="relative">{o.label}</span>
          </button>
        );
      })}
    </div>
  );
}

export function SearchField({ value, onChange, placeholder, label, className }: { value: string; onChange: (v: string) => void; placeholder: string; label: string; className?: string }) {
  return (
    <label className={clsx('glass-well flex h-8 min-w-0 items-center gap-2 rounded-lg px-2.5', className)}>
      <span className="sr-only">{label}</span>
      <svg aria-hidden viewBox="0 0 24 24" className="size-3.5 shrink-0 fill-none stroke-current text-fg-subtle" strokeWidth="2">
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-3.5-3.5" />
      </svg>
      <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} className="min-w-0 flex-1 bg-transparent text-[13px] outline-none placeholder:text-fg-subtle" />
    </label>
  );
}

export function EmptyState({ icon: Icon, title, body, action }: { icon: LucideIcon; title: string; body?: string; action?: React.ReactNode }) {
  return (
    <div className="grid h-full place-items-center p-8 text-center">
      <div className="max-w-xs">
        <span className="glass-well mx-auto grid size-12 place-items-center rounded-2xl text-fg-subtle">
          <Icon className="size-5" />
        </span>
        <p className="mt-3 text-sm font-semibold">{title}</p>
        {body && <p className="mt-1 text-xs leading-relaxed text-fg-subtle">{body}</p>}
        {action && <div className="mt-4">{action}</div>}
      </div>
    </div>
  );
}

export function Toggle({ checked, onChange, label, id }: { checked: boolean; onChange: (v: boolean) => void; label: string; id?: string }) {
  return (
    <button
      id={id}
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => onChange(!checked)}
      className={clsx('relative h-6 w-10 shrink-0 rounded-full transition-colors', checked ? 'bg-accent' : 'bg-[color-mix(in_oklab,var(--text-1)_18%,transparent)]')}
    >
      <motion.span layout transition={springs.elastic} className={clsx('absolute top-0.5 size-5 rounded-full bg-white shadow', checked ? 'right-0.5' : 'left-0.5')} />
    </button>
  );
}
