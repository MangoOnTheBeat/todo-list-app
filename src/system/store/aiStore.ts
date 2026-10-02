import { create } from 'zustand';
import type { CalEvent } from './calendarStore';
import type { VNode } from '@/services/vfs';
import type { Proc } from '@/services/metrics';
import type { Recommendation } from '@/services/ai/productivity';
import { uid } from '../ids';

export interface AiAction {
  label: string;
  run: () => void;
  primary?: boolean;
}

export type AiCard =
  | { type: 'events'; events: CalEvent[] }
  | { type: 'files'; files: VNode[] }
  | { type: 'procs'; procs: Proc[] }
  | { type: 'tips'; tips: Recommendation[] }
  | { type: 'bullets'; items: string[] };

export interface AiReply {
  text: string;
  cards?: AiCard[];
  actions?: AiAction[];
}

export interface AiMessage extends AiReply {
  id: string;
  role: 'user' | 'assistant';
  via?: 'voice' | 'text' | 'search';
  time: number;
}

type VoiceState = 'idle' | 'listening' | 'processing' | 'unavailable';

interface AiStore {
  messages: AiMessage[];
  thinking: boolean;
  voice: VoiceState;
  transcript: string;
  push: (m: Omit<AiMessage, 'id' | 'time'>) => void;
  setThinking: (v: boolean) => void;
  setVoice: (v: VoiceState, transcript?: string) => void;
  clear: () => void;
}

export const useAiStore = create<AiStore>()((set) => ({
  messages: [],
  thinking: false,
  voice: 'idle',
  transcript: '',
  push: (m) => set((s) => ({ messages: [...s.messages, { ...m, id: uid('m'), time: Date.now() }] })),
  setThinking: (thinking) => set({ thinking }),
  setVoice: (voice, transcript) => set((s) => ({ voice, transcript: transcript ?? s.transcript })),
  clear: () => set({ messages: [] }),
}));
