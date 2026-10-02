import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { ArrowUp, Eye, Mic, RotateCcw } from 'lucide-react';
import clsx from 'clsx';
import { getContext } from '@/services/ai/context';
import { currentRecommendations, respond } from '@/services/ai/intents';
import { voice } from '@/services/ai/voice';
import { springs } from '@/system/motion';
import { useAiStore } from '@/system/store/aiStore';
import { useSystemStore } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';
import { AuroraOrb } from './AuroraOrb';
import { MessageView, Tips } from './MessageView';

/** Conversation surface shared by the assistant panel and the Aurora AI window. */
export function AssistantChat({ autoFocus = true }: { autoFocus?: boolean }) {
  const { messages, thinking, voice: vstate, clear } = useAiStore();
  const { aiSuggestions, aiVoice } = useSystemStore();
  const [text, setText] = useState('');
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const windows = useWindowStore((s) => s.windows);
  const order = useWindowStore((s) => s.order);
  // Recomputed whenever the window arrangement changes (the deps are the trigger).
  const ctx = useMemo(() => getContext(), [windows, order]);
  const tips = useMemo(() => (aiSuggestions && windows ? currentRecommendations() : []), [aiSuggestions, windows]);

  useEffect(() => {
    if (autoFocus) inputRef.current?.focus();
  }, [autoFocus]);
  useEffect(() => {
    endRef.current?.scrollIntoView({ block: 'end', behavior: 'smooth' });
  }, [messages.length, thinking]);

  const send = (value = text) => {
    const v = value.trim();
    if (!v) return;
    respond(v, 'text');
    setText('');
  };

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="flex items-center gap-2 border-b hairline px-4 py-2 text-[11px] text-fg-subtle">
        <Eye className="size-3.5 shrink-0" />
        <span className="min-w-0 flex-1 truncate">
          Looking at <span className="font-medium text-fg-muted">{ctx.summary}</span>
        </span>
        {messages.length > 0 && (
          <button onClick={clear} className="flex items-center gap-1 rounded-full px-2 py-0.5 hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] hover:text-fg">
            <RotateCcw className="size-3" /> New chat
          </button>
        )}
      </div>

      <div role="log" aria-live="polite" aria-label="Conversation" className="min-h-0 flex-1 space-y-4 overflow-y-auto px-4 py-4">
        {messages.length === 0 ? (
          <div>
            <div className="flex flex-col items-center pb-2 pt-4 text-center">
              <AuroraOrb size={56} />
              <p className="mt-3 text-lg font-semibold tracking-tight">How can I help?</p>
              <p className="mt-1 max-w-[30ch] text-xs leading-relaxed text-fg-subtle">Ask in plain words. I can open and arrange windows, manage your calendar and files, and change settings.</p>
            </div>
            {tips.length > 0 && (
              <section className="mt-5" aria-label="Suggestions for you">
                <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-fg-subtle">For you</p>
                <Tips tips={tips} />
              </section>
            )}
          </div>
        ) : (
          messages.map((m, i) => <MessageView key={m.id} m={m} latest={i === messages.length - 1} />)
        )}
        <AnimatePresence>
          {thinking && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex items-center gap-2.5">
              <AuroraOrb size={22} active />
              <span className="flex gap-1">
                {[0, 1, 2].map((i) => (
                  <motion.span key={i} className="size-1.5 rounded-full bg-fg-subtle" animate={{ opacity: [0.3, 1, 0.3] }} transition={{ duration: 1, repeat: Infinity, delay: i * 0.15 }} />
                ))}
              </span>
            </motion.div>
          )}
        </AnimatePresence>
        <div ref={endRef} />
      </div>

      <div className="flex gap-1.5 overflow-x-auto px-4 pb-2">
        {ctx.suggestions.map((s) => (
          <button key={s.label} onClick={() => send(s.prompt)} className="shrink-0 rounded-full border hairline px-3 py-1 text-xs text-fg-muted hover:border-accent hover:text-fg">
            {s.label}
          </button>
        ))}
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          send();
        }}
        className="mx-3 mb-3 flex items-end gap-2 rounded-2xl p-1.5 glass-well focus-within:ring-2 focus-within:ring-accent"
      >
        <textarea
          ref={inputRef}
          rows={1}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              send();
            }
          }}
          aria-label="Message Aurora AI"
          placeholder="Ask Aurora or give a command…"
          className="max-h-28 min-h-9 flex-1 resize-none bg-transparent px-2.5 py-2 text-[13px] outline-none placeholder:text-fg-subtle"
        />
        {aiVoice && (
          <button
            type="button"
            aria-label={vstate === 'listening' ? 'Stop listening' : 'Speak a command'}
            aria-pressed={vstate === 'listening'}
            onClick={() => voice.toggle()}
            className={clsx('grid size-9 shrink-0 place-items-center rounded-xl', vstate === 'listening' ? 'bg-[oklch(0.62_0.2_25)] text-white' : 'text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] hover:text-fg')}
          >
            <Mic className="size-4" />
          </button>
        )}
        <motion.button whileTap={{ scale: 0.9 }} transition={springs.snappy} type="submit" aria-label="Send" disabled={!text.trim()} className="grid size-9 shrink-0 place-items-center rounded-xl bg-accent-fill text-white disabled:opacity-35">
          <ArrowUp className="size-4" />
        </motion.button>
      </form>
    </div>
  );
}
