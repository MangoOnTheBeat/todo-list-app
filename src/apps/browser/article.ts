/** Content of the built-in essay, shared by the page renderer and Aurora AI's summariser. */
export const ARTICLE = {
  title: 'The Glass Age of Interfaces',
  sections: [
    {
      paragraphs: [
        'For forty years the desktop has borrowed its metaphors from the office: folders, files, a trash can, a desk. Those metaphors were useful because they were heavy. A window was a sheet of paper, and paper stays where you put it.',
        'Glass works differently. It lets context through. A translucent window says that the work behind it still exists, that you have only set it aside. When the glass is tuned well — enough blur to quiet the background, enough tint to keep text readable — it lowers the cost of switching between tasks because nothing ever fully disappears.',
      ],
    },
    {
      heading: 'Depth as information',
      paragraphs: [
        'In a spatial interface, distance means something. The window you are using sits closest: brightest, sharpest, rimmed in light. Everything else recedes a little, physically and visually. This is not decoration. It is the interface telling you, without words, what has your attention.',
        'Motion carries the same message. When every surface moves on the same family of springs, the system feels like one physical object rather than a stack of animations. A window that snaps to the edge of the screen should feel caught, not teleported.',
      ],
    },
    {
      heading: 'Quiet intelligence',
      paragraphs: [
        'The most useful assistant is the one you rarely notice. It holds a notification until your meeting ends, notices that your downloads folder is full of invoices, and offers — once — to sort them. It never moves a file without asking, and every action it takes can be undone.',
        'That restraint is the real design challenge of the next decade. The technology to make interfaces louder is already here. The craft is in making them calmer.',
      ],
    },
  ],
};

export const ARTICLE_TEXT = ARTICLE.sections.flatMap((s) => s.paragraphs).join(' ');
