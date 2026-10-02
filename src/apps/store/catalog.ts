export type Category = 'productivity' | 'creativity' | 'developer' | 'games' | 'utilities';

export interface StoreApp {
  id: string;
  name: string;
  tagline: string;
  description: string;
  category: Category;
  hue: number;
  glyph: string;
  rating: number;
  reviews: number;
  size: string;
  price: 'Free' | string;
  developer: string;
}

export const CATEGORIES: { id: Category; label: string }[] = [
  { id: 'productivity', label: 'Productivity' },
  { id: 'creativity', label: 'Creativity' },
  { id: 'developer', label: 'Developer tools' },
  { id: 'games', label: 'Games' },
  { id: 'utilities', label: 'Utilities' },
];

export const CATALOG: StoreApp[] = [
  { id: 'lumen', name: 'Lumen Sketch', tagline: 'Infinite canvas for ideas', description: 'A pressure-sensitive canvas with glass layers, smart shapes and a palette that follows your wallpaper.', category: 'creativity', hue: 300, glyph: 'L', rating: 4.8, reviews: 12400, size: '84 MB', price: 'Free', developer: 'Northlight Studio' },
  { id: 'tidewater', name: 'Tidewater Mail', tagline: 'Email that waits its turn', description: 'Bundles newsletters, surfaces replies you owe, and holds everything else until your focus block ends.', category: 'productivity', hue: 210, glyph: 'T', rating: 4.6, reviews: 8800, size: '62 MB', price: 'Free', developer: 'Harbour Labs' },
  { id: 'orbit', name: 'Orbit Tasks', tagline: 'Plans that move with you', description: 'Tasks orbit around your calendar. Drag one onto a free slot and it becomes time on your schedule.', category: 'productivity', hue: 265, glyph: 'O', rating: 4.7, reviews: 5300, size: '38 MB', price: '$4.99', developer: 'Apogee Software' },
  { id: 'prism', name: 'Prism Photo', tagline: 'Pro edits, gentle learning curve', description: 'Non-destructive photo editing with on-device subject masks and film looks.', category: 'creativity', hue: 25, glyph: 'P', rating: 4.5, reviews: 21900, size: '240 MB', price: '$12.99', developer: 'Refract Inc.' },
  { id: 'cadence', name: 'Cadence', tagline: 'Make music in minutes', description: 'Loop-based studio with a glass mixer and spatial audio export.', category: 'creativity', hue: 345, glyph: 'C', rating: 4.4, reviews: 3100, size: '410 MB', price: 'Free', developer: 'Halcyon Audio' },
  { id: 'ledger', name: 'Ledger', tagline: 'Money, calmly', description: 'Budgets that adjust themselves, receipts filed automatically, and no ads ever.', category: 'productivity', hue: 150, glyph: '$', rating: 4.7, reviews: 9600, size: '45 MB', price: 'Free', developer: 'Quiet Finance' },
  { id: 'driftwood', name: 'Driftwood', tagline: 'A distraction-free writer', description: 'Typewriter scrolling, focus mode that dims everything but the current sentence, and Markdown export.', category: 'productivity', hue: 45, glyph: 'D', rating: 4.9, reviews: 2700, size: '22 MB', price: '$7.99', developer: 'Paper Boat' },
  { id: 'moss', name: 'Moss Terminal', tagline: 'A terminal that explains itself', description: 'GPU-rendered terminal with inline command help, split panes and session restore.', category: 'developer', hue: 140, glyph: '>', rating: 4.8, reviews: 6400, size: '31 MB', price: 'Free', developer: 'Lichen Labs' },
  { id: 'forge', name: 'Pixel Forge', tagline: 'Build tiny worlds', description: 'A cosy crafting game about rebuilding a seaside town, one pixel at a time.', category: 'games', hue: 95, glyph: 'F', rating: 4.6, reviews: 18200, size: '1.2 GB', price: '$14.99', developer: 'Tinker Games' },
  { id: 'stratus', name: 'Stratus Weather', tagline: 'Forecasts you can feel', description: 'Hyperlocal forecasts with an animated sky that matches the weather outside.', category: 'utilities', hue: 220, glyph: 'S', rating: 4.5, reviews: 30100, size: '28 MB', price: 'Free', developer: 'Cirrus Co.' },
  { id: 'atlas', name: 'Atlas Maps', tagline: 'Offline maps, beautifully', description: 'Vector maps with offline regions, cycling routes and indoor plans.', category: 'utilities', hue: 175, glyph: 'A', rating: 4.3, reviews: 7700, size: '150 MB', price: 'Free', developer: 'Meridian' },
  { id: 'kilowatt', name: 'Kilowatt', tagline: 'See where your energy goes', description: 'Per-app energy use, battery health and charging that adapts to your routine.', category: 'utilities', hue: 70, glyph: 'K', rating: 4.6, reviews: 1900, size: '12 MB', price: 'Free', developer: 'Volt & Co.' },
  { id: 'nebula', name: 'Nebula Run', tagline: 'Glide through starlight', description: 'A rhythm runner where the level is generated from your music library.', category: 'games', hue: 285, glyph: 'N', rating: 4.4, reviews: 11200, size: '640 MB', price: 'Free', developer: 'Parsec Play' },
  { id: 'schema', name: 'Schema', tagline: 'Visual database design', description: 'Draw tables, relations and migrations on a canvas; export SQL for any engine.', category: 'developer', hue: 235, glyph: '{', rating: 4.7, reviews: 2300, size: '54 MB', price: '$9.99', developer: 'Keystone' },
];

export const FEATURED = ['lumen', 'driftwood', 'forge'];
