import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { MicOff, X } from 'lucide-react';
import { SAMPLE_PHRASES, voice } from '@/services/ai/voice';
import { springs } from '@/system/motion';
import { useAiStore } from '@/system/store/aiStore';
import { AuroraOrb } from './AuroraOrb';

/**
 * Push-to-talk HUD. Shows the live transcript while listening; where no microphone is
 * available it offers sample phrases that run through the simulated voice source.
 */
export function VoiceOverlay() {
  const state = useAiStore((s) => s.voice);
  const transcript = useAiStore((s) => s.transcript);
  const visible = state !== 'idle';

  useEffect(() => {
    if (!visible) return;
    const k = (e: KeyboardEvent) => e.key === 'Escape' && voice.cancel();
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, [visible]);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          role="dialog"
          aria-label="Voice command"
          initial={{ opacity: 0, y: 30, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 20, scale: 0.95 }}
          transition={springs.elastic}
          className="pointer-events-auto glass acrylic glass-sheen absolute bottom-[104px] left-1/2 z-[1400] w-[min(440px,calc(100vw-32px))] -translate-x-1/2 rounded-[28px] p-5 text-center"
          style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window), 0 0 80px -20px var(--color-accent)' }}
        >
          <button aria-label="Cancel" onClick={() => voice.cancel()} className="absolute right-3 top-3 grid size-7 place-items-center rounded-full text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
            <X className="size-4" />
          </button>
          {state === 'unavailable' ? (
            <>
              <span className="mx-auto grid size-12 place-items-center rounded-full bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)]">
                <MicOff className="size-5 text-fg-muted" />
              </span>
              <p className="mt-3 text-sm font-semibold">Microphone isn't available here</p>
              <p className="mt-1 text-xs text-fg-subtle">Try the voice pipeline with a sample phrase instead:</p>
              <div className="mt-3 flex flex-wrap justify-center gap-1.5">
                {SAMPLE_PHRASES.map((p) => (
                  <button key={p} onClick={() => voice.simulate(p)} className="rounded-full bg-accent-soft px-3 py-1 text-xs font-medium text-accent hover:bg-accent-fill hover:text-white">
                    “{p}”
                  </button>
                ))}
              </div>
            </>
          ) : (
            <>
              <div className="relative mx-auto grid size-20 place-items-center">
                {state === 'listening' &&
                  [0, 1, 2].map((i) => (
                    <motion.span
                      key={i}
                      aria-hidden
                      className="absolute inset-0 rounded-full border border-accent"
                      initial={{ scale: 0.6, opacity: 0.6 }}
                      animate={{ scale: 1.6, opacity: 0 }}
                      transition={{ duration: 1.8, repeat: Infinity, delay: i * 0.6, ease: 'easeOut' }}
                    />
                  ))}
                <AuroraOrb size={60} active />
              </div>
              <p className="mt-4 min-h-6 text-base font-medium tracking-tight" aria-live="polite">
                {transcript || (state === 'listening' ? 'Listening…' : 'Working on it…')}
              </p>
              <p className="mt-1 text-[11px] text-fg-subtle">{state === 'listening' ? 'Speak a command · Esc to cancel' : 'Running your request'}</p>
            </>
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
