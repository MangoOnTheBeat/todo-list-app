import clsx from 'clsx';
import { getApp } from '@/system/appRegistry';
import type { AppId } from '@/system/types';

interface Props {
  appId: AppId;
  size?: number;
  className?: string;
}

/**
 * Aurora app tile: a gradient squircle with a white glyph, an inner top highlight
 * and a soft coloured under-glow. All icons share this construction so the dock reads
 * as one family.
 */
export function AppIcon({ appId, size = 48, className }: Props) {
  const app = getApp(appId);
  const Icon = app.icon;
  const [from, to] = app.gradient;
  return (
    <div
      aria-hidden
      className={clsx('relative grid shrink-0 place-items-center', className)}
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.26,
        background: `linear-gradient(145deg, ${from}, ${to})`,
        boxShadow: `inset 0 1px 0 oklch(1 0 0 / 0.45), inset 0 -1px 0 oklch(0 0 0 / 0.15), 0 ${size * 0.08}px ${size * 0.25}px -${size * 0.06}px ${to}`,
      }}
    >
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          borderRadius: 'inherit',
          background: 'radial-gradient(120% 70% at 30% 0%, oklch(1 0 0 / 0.38), transparent 60%)',
        }}
      />
      <Icon className="relative text-white drop-shadow-[0_1px_1px_rgba(0,0,0,0.25)]" style={{ width: size * 0.5, height: size * 0.5 }} strokeWidth={1.75} />
    </div>
  );
}
