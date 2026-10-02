import { useAiStore } from '@/system/store/aiStore';
import { useShellStore } from '@/system/store/shellStore';
import { respond } from './intents';

/**
 * Voice command framework.
 *
 * A voice *source* produces interim and final transcripts; the controller routes the
 * final transcript into the same `respond()` pipeline typed requests use. Two sources:
 *  - the Web Speech API (`SpeechRecognition`), when the browser provides it and the
 *    microphone is allowed;
 *  - a simulated source that "speaks" a sample phrase, so the full flow can be shown
 *    where microphones are unavailable (sandboxed previews, kiosks, tests).
 */

interface SpeechRecognitionLike {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  start(): void;
  stop(): void;
  abort(): void;
  onresult: ((e: { resultIndex: number; results: ArrayLike<{ 0: { transcript: string }; isFinal: boolean }> }) => void) | null;
  onerror: ((e: { error: string }) => void) | null;
  onend: (() => void) | null;
}

type Ctor = new () => SpeechRecognitionLike;
const Recognition: Ctor | undefined = typeof window !== 'undefined' ? ((window as unknown as { SpeechRecognition?: Ctor; webkitSpeechRecognition?: Ctor }).SpeechRecognition ?? (window as unknown as { webkitSpeechRecognition?: Ctor }).webkitSpeechRecognition) : undefined;

export const SAMPLE_PHRASES = ['Open Calendar and snap it left', "What's on tomorrow?", 'Turn on dark mode', 'Organize Downloads', 'Play Halcyon Drive', 'Find PDFs from this month'];

let active: SpeechRecognitionLike | null = null;
let simTimer: ReturnType<typeof setInterval> | undefined;
let finalText = '';

function finish() {
  const store = useAiStore.getState();
  const text = (finalText || store.transcript).trim();
  active = null;
  if (!text) {
    store.setVoice('idle', '');
    return;
  }
  store.setVoice('processing', text);
  useShellStore.getState().openPanel('assistant');
  respond(text, 'voice');
  setTimeout(() => useAiStore.getState().setVoice('idle', ''), 700);
}

export const voice = {
  supported: !!Recognition,

  /** Begin listening with the real microphone, or report that it's unavailable. */
  start() {
    const store = useAiStore.getState();
    finalText = '';
    if (!Recognition) {
      store.setVoice('unavailable', '');
      return;
    }
    try {
      const rec = new Recognition();
      rec.lang = navigator.language || 'en-US';
      rec.interimResults = true;
      rec.continuous = false;
      rec.onresult = (e) => {
        let interim = '';
        for (let i = e.resultIndex; i < e.results.length; i++) {
          const r = e.results[i];
          if (r.isFinal) finalText += r[0].transcript;
          else interim += r[0].transcript;
        }
        useAiStore.getState().setVoice('listening', (finalText + interim).trim());
      };
      rec.onerror = (e) => {
        active = null;
        useAiStore.getState().setVoice(e.error === 'no-speech' ? 'idle' : 'unavailable', '');
      };
      rec.onend = () => {
        if (useAiStore.getState().voice === 'listening') finish();
      };
      active = rec;
      store.setVoice('listening', '');
      rec.start();
    } catch {
      store.setVoice('unavailable', '');
    }
  },

  stop() {
    if (active) active.stop();
    else if (useAiStore.getState().voice === 'listening') finish();
  },

  cancel() {
    active?.abort();
    active = null;
    clearInterval(simTimer);
    useAiStore.getState().setVoice('idle', '');
  },

  /** Simulated source: types the phrase into the live transcript like speech, then submits. */
  simulate(phrase: string) {
    clearInterval(simTimer);
    finalText = '';
    const words = phrase.split(' ');
    let i = 0;
    useAiStore.getState().setVoice('listening', '');
    simTimer = setInterval(() => {
      i++;
      useAiStore.getState().setVoice('listening', words.slice(0, i).join(' '));
      if (i >= words.length) {
        clearInterval(simTimer);
        finalText = phrase;
        setTimeout(finish, 350);
      }
    }, 170);
  },

  toggle() {
    const v = useAiStore.getState().voice;
    if (v === 'listening') this.stop();
    else if (v === 'unavailable') this.cancel();
    else this.start();
  },
};
