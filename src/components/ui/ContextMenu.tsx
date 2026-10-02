import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { motion } from 'framer-motion';
import clsx from 'clsx';
import type { LucideIcon } from 'lucide-react';
import { springs } from '@/system/motion';

export interface MenuItem {
  label: string;
  icon?: LucideIcon;
  onSelect: () => void;
  danger?: boolean;
  disabled?: boolean;
  separatorBefore?: boolean;
}

/**
 * Glass context menu rendered in a portal at the pointer, kept inside the viewport.
 * Arrow keys move, Enter selects, Escape or an outside click closes.
 */
export function ContextMenu({ x, y, items, onClose }: { x: number; y: number; items: MenuItem[]; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState({ x, y });
  const [active, setActive] = useState(0);

  useLayoutEffect(() => {
    const r = ref.current?.getBoundingClientRect();
    if (!r) return;
    setPos({ x: Math.min(x, window.innerWidth - r.width - 8), y: Math.min(y, window.innerHeight - r.height - 8) });
  }, [x, y]);

  useEffect(() => {
    ref.current?.focus();
    const down = (e: PointerEvent) => !ref.current?.contains(e.target as Node) && onClose();
    window.addEventListener('pointerdown', down, true);
    return () => window.removeEventListener('pointerdown', down, true);
  }, [onClose]);

  const enabled = items.map((it, i) => (it.disabled ? -1 : i)).filter((i) => i >= 0);
  const onKey = (e: React.KeyboardEvent) => {
    e.stopPropagation();
    const at = enabled.indexOf(active);
    if (e.key === 'ArrowDown') setActive(enabled[(at + 1) % enabled.length]);
    else if (e.key === 'ArrowUp') setActive(enabled[(at - 1 + enabled.length) % enabled.length]);
    else if (e.key === 'Enter') {
      items[active]?.onSelect();
      onClose();
    } else if (e.key === 'Escape') onClose();
    else return;
    e.preventDefault();
  };

  return createPortal(
    <motion.div
      ref={ref}
      role="menu"
      tabIndex={-1}
      onKeyDown={onKey}
      initial={{ opacity: 0, scale: 0.94 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={springs.snappy}
      className="glass acrylic fixed z-[1500] min-w-[184px] origin-top-left rounded-xl p-1 outline-none"
      style={{ left: pos.x, top: pos.y, boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
      onContextMenu={(e) => e.preventDefault()}
    >
      {items.map((it, i) => {
        const Icon = it.icon;
        return (
          <div key={it.label}>
            {it.separatorBefore && <div className="mx-2 my-1 h-px bg-[var(--glass-border)]" />}
            <button
              role="menuitem"
              disabled={it.disabled}
              onMouseEnter={() => setActive(i)}
              onClick={() => {
                it.onSelect();
                onClose();
              }}
              className={clsx(
                'flex h-8 w-full items-center gap-2.5 rounded-lg px-2.5 text-left text-[13px] disabled:opacity-40',
                active === i && !it.disabled && (it.danger ? 'bg-[oklch(0.62_0.2_25)] text-white' : 'bg-accent text-white'),
                it.danger && active !== i && 'text-[oklch(0.62_0.2_25)]',
              )}
            >
              {Icon && <Icon className="size-4" />}
              {it.label}
            </button>
          </div>
        );
      })}
    </motion.div>,
    document.body,
  );
}
