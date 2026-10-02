/**
 * Lightweight ranking: exact > prefix > word-prefix > substring > in-order subsequence.
 * Returns 0 for no match. Good enough for a few hundred local items with no index.
 */
export function fuzzyScore(query: string, text: string): number {
  const q = query.toLowerCase().trim();
  const t = text.toLowerCase();
  if (!q) return 0;
  if (t === q) return 100;
  if (t.startsWith(q)) return 80 - Math.min(20, t.length - q.length) * 0.5;
  if (t.split(/[\s\-_./()]+/).some((w) => w.startsWith(q))) return 60;
  const idx = t.indexOf(q);
  if (idx >= 0) return 45 - Math.min(15, idx);
  // Subsequence: every query char appears in order; tighter spans score higher.
  let ti = 0;
  let first = -1;
  for (const ch of q) {
    ti = t.indexOf(ch, ti);
    if (ti < 0) return 0;
    if (first < 0) first = ti;
    ti++;
  }
  const span = ti - first;
  return Math.max(5, 30 - (span - q.length) * 2);
}

export function bestScore(query: string, ...fields: (string | undefined)[]) {
  return Math.max(0, ...fields.filter(Boolean).map((f) => fuzzyScore(query, f!)));
}
