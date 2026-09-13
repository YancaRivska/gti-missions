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

## 5.2 — profile persistence and daily sharing

Avatar replacement invalidates the profile cache after the database acknowledges the new path. A later rendering error cannot delete a committed image; uncertain network results are read back before cleanup. Editing profile fields also clears the cache.

Ranking rows have a full-row pointer target and keyboard focus outline; the first page resolves real avatars concurrently. Member profiles emphasize identity, tagline, actual XP and active joined challenges. Existing badge, public-note and season screens remain accessible. The member RPC retains its permanent-account and per-section visibility checks, with joined active custom worlds added. Migration timestamp matches the applied remote migration.

Every successful activity submission (water, training, reading, screen-free and community challenges) offers an optional receipt with Story/Feed export. Receipts are transient and available immediately after registering; this release does not add a historical activity gallery. Cards contain the entered detail, date in São Paulo, server-awarded XP, username and the currently working Vercel website. No speculative custom domain is advertised. Export code and mascot images load on demand. No new runtime dependency.

Validation: `npm run check` passes 12 tests including avatar-cache invalidation, post-save rendering failure, member navigation, receipt amount/XP, all four activity card types, native sharing and download fallback. The live member RPC returned valid profiles with two and three active worlds. Authenticated browser upload was not exercised with a real account. Supabase advisors flag existing security-definer endpoints (including the intentional guarded member RPC); grants/guards were preserved. Unrelated existing project advisories were not changed: [Supabase advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
