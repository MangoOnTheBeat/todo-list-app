import { useId } from 'react';
import type { LucideIcon } from 'lucide-react';

interface Props {
  label: string;
  value: number;
  onChange: (v: number) => void;
  icon: LucideIcon;
  min?: number;
  max?: number;
  step?: number;
  /** Optional readout to the right (e.g. a time). */
  format?: (v: number) => string;
}

/**
 * Pill slider: a glass well with an accent fill and the icon sitting inside the fill,
 * built on a native range input so keyboard and screen-reader support come for free.
 */
export function Slider({ label, value, onChange, icon: Icon, min = 0, max = 1, step = 0.01, format }: Props) {
  const id = useId();
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div className="flex items-center gap-3">
      <div className="glass-well relative h-9 flex-1 overflow-hidden rounded-full">
        <div
          aria-hidden
          className="absolute inset-y-0 left-0 rounded-full bg-accent-fill shadow-[0_0_18px_-4px_var(--color-accent)] transition-[width] duration-75"
          style={{ width: `max(36px, ${pct}%)` }}
        />
        <Icon aria-hidden className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-white" />
        <label htmlFor={id} className="sr-only">
          {label}
        </label>
        <input
          id={id}
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
        />
      </div>
      {format && <span className="w-10 text-right text-xs tabular-nums text-fg-muted">{format(value)}</span>}
    </div>
  );
}
