/**
 * Lightweight on-device text intelligence: extractive summarisation and keyword
 * extraction. Deterministic and instant; swappable for a model-backed implementation.
 */
const STOP = new Set('a an the and or but if then of to in on at for with by from is are was were be been it this that these those as i you we they he she my your our their me us them not no so do does did have has had can will just about into over than too very'.split(' '));

export function keywords(text: string, n = 6) {
  const freq = new Map<string, number>();
  for (const w of text.toLowerCase().match(/[a-z][a-z'-]{2,}/g) ?? []) if (!STOP.has(w)) freq.set(w, (freq.get(w) ?? 0) + 1);
  return [...freq.entries()].sort((a, b) => b[1] - a[1]).slice(0, n).map(([w]) => w);
}

/** Pick the most informative sentences / lines, in original order. */
export function summarize(text: string, max = 3): string[] {
  const units = text
    .split(/(?<=[.!?])\s+|\n+/)
    .map((s) => s.replace(/^[-*•\d.)\s]+/, '').trim())
    .filter((s) => s.length > 3);
  if (units.length === 0) return ['This note is empty.'];
  if (units.length <= max) return units;
  const kw = new Set(keywords(text, 10));
  const scored = units.map((u, i) => {
    const words = u.toLowerCase().match(/[a-z'-]+/g) ?? [];
    const hits = words.filter((w) => kw.has(w)).length;
    // Favour keyword density, a little position bias toward the start, and mid-length units.
    const score = hits / Math.sqrt(words.length + 1) + (i === 0 ? 0.5 : 0) + (words.length > 4 && words.length < 30 ? 0.3 : 0);
    return { u, i, score };
  });
  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, max)
    .sort((a, b) => a.i - b.i)
    .map((s) => s.u);
}
