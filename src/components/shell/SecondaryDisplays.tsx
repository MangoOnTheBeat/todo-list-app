import { Monitor } from 'lucide-react';
import { useClock } from '@/hooks/useClock';
import { BEZEL } from '@/hooks/useDisplaySync';
import { SECONDARY_BAR_H } from '@/system/layout';
import { useWindowStore } from '@/system/store/windowStore';

/**
 * Chrome for non-primary displays: a bezel separating it from its neighbour and a slim
 * status strip. The dock and system panels stay on the primary display.
 */
export function SecondaryDisplays() {
  const displays = useWindowStore((s) => s.displays);
  const now = useClock();
  const extra = displays.filter((d) => !d.primary);
  if (!extra.length) return null;
  return (
    <>
      {extra.map((d) => (
        <div key={d.id} aria-label={d.name} role="region">
          {/* Bezel: a dark physical frame with a faint edge highlight. */}
          <div
            aria-hidden
            className="pointer-events-none absolute top-0 z-[950] h-full"
            style={{ left: d.bounds.x - BEZEL, width: BEZEL, background: 'linear-gradient(90deg, oklch(0.08 0 0), oklch(0.16 0 0) 45%, oklch(0.08 0 0))', boxShadow: 'inset 1px 0 0 oklch(1 0 0 / 0.06), inset -1px 0 0 oklch(1 0 0 / 0.06)' }}
          />
          <div className="glass pointer-events-none absolute z-[1000] flex items-center gap-2 rounded-full px-3 text-[12px] text-fg-muted" style={{ left: d.bounds.x + d.bounds.w / 2, top: 6, height: SECONDARY_BAR_H - 8, transform: 'translateX(-50%)' }}>
            <Monitor className="size-3.5" />
            <span className="font-medium text-fg">{d.name}</span>
            <span className="tabular-nums">{now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}</span>
          </div>
        </div>
      ))}
    </>
  );
}
