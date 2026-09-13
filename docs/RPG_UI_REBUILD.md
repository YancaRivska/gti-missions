# GTI Missions — RPG UI revision

The existing static JavaScript application is retained. No database, authentication, XP, ranking, streak, season participation, or permission logic was migrated.

## Implemented
- Shared navy/cyan visual tokens, world color variants, focus states, safe-area navigation and readable controls.
- Player hub with official pink/dark assets, live level/XP, seasonal summary, daily actions and merchandise banner.
- Four mission cards; hydration meter; orange training, purple reading with journal link, green screen-free world.
- Collectible achievement badges and unlock dialog; 1080×1920 Story and 1080×1350 Feed exports with official mascots and real achievement data.
- Top-three ranking hierarchy and current-player highlight; profile progression and collapsible weekly badges, retaining all existing badge filters.
- Drop 002 detail using supplied merchandise artwork, with encoded WhatsApp contact link. No invented price, stock, fabric or shipping claims.

## Reference mapping
Files are numbered differently from labels printed in the supplied sheets. The implementation follows their subject: 03→home/worlds; 04→water/training; 07→reading/offline; 01→profile; 06→ranking; 02→achievements; 09→progress; 05→sharing; 10→merchandise; 08→season.

## Validation and remaining work
`npm run check` passes lint, TypeScript checking, nine existing functional/share tests and static build. No runtime dependency added. Test fixtures remain outside the production build.

Browser visual verification is pending: this session’s cloud browser rejects the local preview URL with ERR_BLOCKED_BY_CLIENT. This branch must be visually checked at 360, 390, 430 and desktop widths before production merge, including long player names, ranking with 0/1/2/3 players, form controls, safe-area navigation and both exported image sizes.

Mascots reuse existing official cutouts. The exact dark-mascot training/meditation poses from the reference sheets are not available as standalone production assets; the existing dark mascot is used without generating a substitute. The merchandise sheet is converted to WebP without repainting and framed with CSS. This is not a claim of pixel-identical reproduction.
