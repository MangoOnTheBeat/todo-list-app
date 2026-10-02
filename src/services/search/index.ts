import { providers } from './providers';
import type { ResultKind, SearchResult } from './types';

export type { SearchResult, ResultKind } from './types';

export interface SearchSection {
  kind: ResultKind;
  label: string;
  results: SearchResult[];
}

export interface SearchResponse {
  top: SearchResult | null;
  sections: SearchSection[];
  /** Flat list in display order, for keyboard navigation. */
  flat: SearchResult[];
}

const PER_SECTION = 5;

/** Run every provider, pick a single best "top hit", then group the rest by kind. */
export function search(query: string): SearchResponse {
  const q = query.trim();
  const all = q
    ? providers.flatMap((p) => p.search(q).map((r) => ({ r, label: p.label })))
    : providers.flatMap((p) => (p.suggest?.() ?? []).map((r) => ({ r, label: p.id === 'file' ? 'Recent files' : 'Suggested' })));

  const sorted = all.sort((a, b) => b.r.score - a.r.score);
  const top = q && sorted.length ? sorted[0].r : null;

  const sections = new Map<string, SearchSection>();
  for (const { r, label } of sorted) {
    if (r === top) continue;
    const sec = sections.get(label) ?? { kind: r.kind, label, results: [] };
    if (sec.results.length < PER_SECTION) sec.results.push(r);
    sections.set(label, sec);
  }
  const list = [...sections.values()];
  return { top, sections: list, flat: [...(top ? [top] : []), ...list.flatMap((s) => s.results)] };
}
