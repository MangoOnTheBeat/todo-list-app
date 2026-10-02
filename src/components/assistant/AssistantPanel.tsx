import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import { springs } from '@/system/motion';
import { useShellStore } from '@/system/store/shellStore';
import { AssistantChat } from './AssistantChat';
import { AuroraOrb } from './AuroraOrb';

/** Aurora AI as a system sheet on the right edge, with a slow aurora rim. */
export function AssistantPanel() {
  const close = useShellStore((s) => s.closePanel);
  return (
    <motion.aside
      role="dialog"
      aria-label="Aurora AI"
      initial={{ opacity: 0, x: 70, scale: 0.98 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      exit={{ opacity: 0, x: 60, transition: { duration: 0.18 } }}
      transition={springs.panel}
      className="absolute bottom-[100px] right-2.5 top-11 z-[1300] w-[min(400px,calc(100vw-20px))]"
    >
      {/* Rim light: a rotating conic gradient peeking out 1px around the sheet. */}
      <div aria-hidden className="absolute -inset-px overflow-hidden rounded-[calc(var(--radius-panel)+1px)] opacity-80">
        <motion.div
          className="absolute -inset-[50%]"
          style={{ background: 'conic-gradient(from 0deg, transparent 0 40%, oklch(0.8 0.14 200), var(--color-accent), oklch(0.75 0.18 340), transparent 60% 100%)' }}
          animate={{ rotate: 360 }}
          transition={{ duration: 8, repeat: Infinity, ease: 'linear' }}
        />
      </div>
      <div className="glass acrylic glass-sheen relative flex h-full flex-col overflow-hidden rounded-[var(--radius-panel)]" style={{ boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window), 0 0 60px -20px var(--color-accent)' }}>
        <header className="flex items-center gap-2.5 px-4 pb-2 pt-3.5">
          <AuroraOrb size={24} />
          <h2 className="flex-1 text-sm font-semibold tracking-tight">Aurora AI</h2>
          <kbd className="glass-well rounded-md px-1.5 py-0.5 font-mono text-[10px] text-fg-subtle">Ctrl J</kbd>
          <button aria-label="Close Aurora AI" onClick={close} className="grid size-7 place-items-center rounded-full text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] hover:text-fg">
            <X className="size-4" />
          </button>
        </header>
        <div className="min-h-0 flex-1">
          <AssistantChat />
        </div>
      </div>
    </motion.aside>
  );
}
