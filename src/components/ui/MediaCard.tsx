import { motion } from 'framer-motion';
import { Heart, Pause, Play, SkipBack, SkipForward } from 'lucide-react';
import clsx from 'clsx';
import { springs } from '@/system/motion';
import { currentTrack, formatTime, useMediaStore } from '@/system/store/mediaStore';
import { CoverArt } from './CoverArt';

/** Now-playing card with transport controls and a scrubber. Used in Quick Settings and the lock screen. */
export function MediaCard({ compact = false }: { compact?: boolean }) {
  const { playing, position, toggle, next, prev, seek, liked, toggleLike } = useMediaStore();
  const track = useMediaStore(currentTrack);
  const pct = (position / track.duration) * 100;

  return (
    <section aria-label="Now playing" className="glass-well relative overflow-hidden rounded-2xl p-3">
      {/* Ambient tint from the cover art bleeds into the card. */}
      <div aria-hidden className="pointer-events-none absolute inset-0 opacity-30" style={{ background: `radial-gradient(80% 120% at 0% 0%, ${track.palette[0]}, transparent 70%)` }} />
      <div className="relative flex items-center gap-3">
        <CoverArt track={track} size={compact ? 44 : 56} playing={playing} />
        <div className="min-w-0 flex-1">
          <motion.p key={track.id} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} className="truncate text-sm font-semibold">
            {track.title}
          </motion.p>
          <p className="truncate text-xs text-fg-muted">{track.artist}</p>
        </div>
        <button
          aria-label={liked[track.id] ? 'Unlike' : 'Like'}
          aria-pressed={!!liked[track.id]}
          onClick={toggleLike}
          className="grid size-8 place-items-center rounded-full hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)]"
        >
          <Heart className={clsx('size-4', liked[track.id] ? 'fill-[oklch(0.65_0.22_15)] text-[oklch(0.65_0.22_15)]' : 'text-fg-muted')} />
        </button>
      </div>

      <div className="relative mt-3">
        <div className="h-1 overflow-hidden rounded-full bg-[color-mix(in_oklab,var(--text-1)_14%,transparent)]">
          <div className="h-full rounded-full bg-fg" style={{ width: `${pct}%` }} />
        </div>
        <label className="sr-only" htmlFor="media-seek">
          Seek
        </label>
        <input
          id="media-seek"
          type="range"
          min={0}
          max={track.duration}
          step={1}
          value={position}
          onChange={(e) => seek(Number(e.target.value))}
          className="absolute inset-x-0 -top-2 h-5 w-full cursor-pointer opacity-0"
        />
        <div className="mt-1 flex justify-between font-mono text-[10px] tabular-nums text-fg-subtle">
          <span>{formatTime(position)}</span>
          <span>-{formatTime(track.duration - position)}</span>
        </div>
      </div>

      <div className="relative mt-1 flex items-center justify-center gap-4">
        <Transport label="Previous" onClick={prev}>
          <SkipBack className="size-4 fill-current" />
        </Transport>
        <Transport label={playing ? 'Pause' : 'Play'} onClick={toggle} big>
          {playing ? <Pause className="size-5 fill-current" /> : <Play className="size-5 translate-x-px fill-current" />}
        </Transport>
        <Transport label="Next" onClick={next}>
          <SkipForward className="size-4 fill-current" />
        </Transport>
      </div>
    </section>
  );
}

function Transport({ label, onClick, big, children }: { label: string; onClick: () => void; big?: boolean; children: React.ReactNode }) {
  return (
    <motion.button
      aria-label={label}
      onClick={onClick}
      whileTap={{ scale: 0.85 }}
      whileHover={{ scale: 1.08 }}
      transition={springs.elastic}
      className={clsx('grid place-items-center rounded-full text-fg', big ? 'size-10 bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]' : 'size-8')}
    >
      {children}
    </motion.button>
  );
}
