import type { LucideIcon } from 'lucide-react';
import type { AppId } from '@/system/types';

export type ResultKind = 'ai' | 'app' | 'window' | 'action' | 'file' | 'setting' | 'calc';

export interface SearchResult {
  id: string;
  kind: ResultKind;
  title: string;
  subtitle?: string;
  /** Either an app tile or a glyph. */
  appId?: AppId;
  icon?: LucideIcon;
  score: number;
  run: () => void;
}

/**
 * Search is a set of providers. Each one is synchronous and local today; the AI layer
 * (Phase 4) adds a natural-language provider that rewrites queries and contributes answers.
 */
export interface SearchProvider {
  id: ResultKind;
  label: string;
  search: (query: string) => SearchResult[];
  /** Results shown before the user types. */
  suggest?: () => SearchResult[];
}
