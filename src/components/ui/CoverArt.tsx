import { motion } from 'framer-motion';
import type { Track } from '@/system/store/mediaStore';

/** Generative album cover: three colour fields from the track palette, slowly rotating while playing. */
export function CoverArt({ track, size, playing, radius = 12 }: { track: Track; size: number; playing?: boolean; radius?: number }) {
  const [a, b, c] = track.palette;
  return (
    <div
      aria-hidden
      className="relative shrink-0 overflow-hidden"
      style={{ width: size, height: size, borderRadius: radius, background: b, boxShadow: `0 8px 24px -8px ${b}, inset 0 1px 0 oklch(1 0 0 / 0.3)` }}
    >
      <motion.div
        className="absolute inset-[-30%]"
        style={{ background: `radial-gradient(circle at 30% 30%, ${a}, transparent 55%), radial-gradient(circle at 75% 70%, ${c}, transparent 50%)`, filter: 'blur(6px)' }}
        animate={playing ? { rotate: 360 } : { rotate: 0 }}
        transition={playing ? { duration: 18, ease: 'linear', repeat: Infinity } : { duration: 0.6 }}
      />
      <div className="absolute inset-0" style={{ background: 'linear-gradient(160deg, oklch(1 0 0 / 0.25), transparent 45%)' }} />
      <span className="absolute bottom-1.5 left-2 font-mono text-[9px] font-semibold uppercase tracking-widest text-white/80" style={{ fontSize: Math.max(7, size / 9) }}>
        {track.album.slice(0, 10)}
      </span>
    </div>
  );
}

/** Animated equaliser bars used as a "now playing" indicator. */
export function EqBars({ playing, className = '' }: { playing: boolean; className?: string }) {
  return (
    <span aria-hidden className={`flex h-3 items-end gap-[2px] ${className}`}>
      {[0.6, 1, 0.75].map((h, i) => (
        <motion.span
          key={i}
          className="w-[3px] rounded-full bg-accent"
          animate={playing ? { height: ['30%', `${h * 100}%`, '45%', `${h * 80}%`, '30%'] } : { height: '30%' }}
          transition={playing ? { duration: 1.1 + i * 0.2, repeat: Infinity, ease: 'easeInOut' } : { duration: 0.3 }}
        />
      ))}
    </span>
  );
}
