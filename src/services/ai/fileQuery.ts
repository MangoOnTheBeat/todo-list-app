import { allFiles } from '@/system/store/fileStore';
import type { FileKind, VNode } from '../vfs';

/**
 * Natural-language file queries: "pdfs from last week", "photos larger than 5 MB",
 * "work documents", "invoices". Returns null when the text isn't a file query.
 */
const KIND_WORDS: [RegExp, FileKind[], string][] = [
  [/\bpdfs?\b/, ['pdf'], 'PDFs'],
  [/\b(images?|photos?|pictures?|pics?|screenshots?)\b/, ['image'], 'images'],
  [/\bvideos?|recordings?|movies?\b/, ['video'], 'videos'],
  [/\b(docs?|documents?)\b/, ['document', 'pdf'], 'documents'],
  [/\b(spreadsheets?|sheets?)\b/, ['spreadsheet'], 'spreadsheets'],
  [/\b(audio|songs?|music|podcasts?|mp3s?)\b/, ['audio'], 'audio files'],
  [/\b(archives?|zips?)\b/, ['archive'], 'archives'],
  [/\b(code|source)\b/, ['code'], 'code files'],
  [/\b(decks?|presentations?|slides)\b/, ['presentation'], 'presentations'],
  [/\bfolders?\b/, ['folder'], 'folders'],
];
const TAGS = ['work', 'finance', 'design', 'personal', 'travel', 'planning'];
const DAY = 86_400_000;
const FILLER = new Set('find show me my all the a an any search for files file from in of with that are is larger bigger smaller than over under last this past week month today yesterday recent recently modified changed edited opened please mb gb kb'.split(' '));

export interface FileQueryResult {
  files: VNode[];
  description: string;
  /** True when the query had a kind, date, size or tag constraint (not just name words). */
  structured: boolean;
}

export function fileQuery(text: string): FileQueryResult | null {
  const t = text.toLowerCase();
  let kinds: FileKind[] | undefined;
  const parts: string[] = [];
  for (const [re, k, label] of KIND_WORDS)
    if (re.test(t)) {
      kinds = [...(kinds ?? []), ...k];
      parts.push(label);
    }

  let since: number | undefined;
  const now = Date.now();
  if (/\btoday\b/.test(t)) (since = now - DAY), parts.push('from today');
  else if (/\byesterday\b/.test(t)) (since = now - 2 * DAY), parts.push('since yesterday');
  else if (/\b(this|last|past) week\b/.test(t)) (since = now - 7 * DAY), parts.push('from the last week');
  else if (/\b(this|last|past) month\b/.test(t)) (since = now - 31 * DAY), parts.push('from the last month');
  else if (/\brecent(ly)?\b/.test(t)) (since = now - 7 * DAY), parts.push('recent');

  let minSize: number | undefined;
  let maxSize: number | undefined;
  const sm = t.match(/\b(larger|bigger|over|more) than\s+(\d+(?:\.\d+)?)\s*(kb|mb|gb)\b/) ?? t.match(/\bover\s+(\d+(?:\.\d+)?)\s*(kb|mb|gb)\b/);
  const unit = (u: string) => (u === 'gb' ? 1024 ** 3 : u === 'mb' ? 1024 ** 2 : 1024);
  if (sm) {
    const [n, u] = sm.length === 4 ? [sm[2], sm[3]] : [sm[1], sm[2]];
    minSize = Number(n) * unit(u);
    parts.push(`over ${n} ${u.toUpperCase()}`);
  }
  const sx = t.match(/\b(smaller|less|under) than\s+(\d+(?:\.\d+)?)\s*(kb|mb|gb)\b/);
  if (sx) {
    maxSize = Number(sx[2]) * unit(sx[3]);
    parts.push(`under ${sx[2]} ${sx[3].toUpperCase()}`);
  }
  if (/\b(large|big|huge)\b/.test(t) && !minSize) (minSize = 50 * 1024 ** 2), parts.push('over 50 MB');

  const tags = TAGS.filter((g) => new RegExp(`\\b${g}\\b`).test(t));
  if (tags.length) parts.push(`tagged ${tags.join(', ')}`);

  // Remaining meaningful words become a name filter ("invoices" → "invoice").
  const consumed = new RegExp(KIND_WORDS.map(([r]) => r.source).join('|'), 'g');
  const words = t
    .replace(consumed, ' ')
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length > 2 && !FILLER.has(w) && !TAGS.includes(w) && !/^\d+$/.test(w))
    .map((w) => w.replace(/(ies)$/, 'y').replace(/s$/, ''));

  const structured = kinds || since || minSize || maxSize || tags.length;
  const looksLikeFiles = structured || /\bfiles?\b/.test(t);
  if (!looksLikeFiles && words.length === 0) return null;

  const files = allFiles().filter(
    (f) =>
      (!kinds || kinds.includes(f.kind)) &&
      (!since || f.modified >= since) &&
      (!minSize || (f.size ?? 0) >= minSize) &&
      (!maxSize || (f.size ?? 0) <= maxSize) &&
      (!tags.length || tags.every((g) => f.tags?.includes(g))) &&
      (!words.length || words.some((w) => f.name.toLowerCase().includes(w) || f.tags?.some((g) => g.includes(w)))),
  );
  if (!structured && files.length === 0) return null;
  if (words.length) parts.unshift(`matching “${words.join(' ')}”`);
  return { files: files.sort((a, b) => b.modified - a.modified), description: parts.join(' ') || 'files', structured: !!structured };
}
