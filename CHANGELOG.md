# Changelog

### v1.0.1
Critical fixes (audit milestone M1). No gameplay features were added and the item model, level
generation, catalog and network protocol are unchanged, so v1.0 and v1.0.1 players can still
share a session. Existing saves keep working.
- Aiming: items inside a push cart, an open case or an open collector's box can be targeted and
  picked up again (the container used to shadow its contents). Loose carts no longer turn into
  tumbling rigid bodies when you walk up to them.
- Map boundary: storefront and other windows are solid; a recovery guard puts anyone who ends up
  outside the building (or under the floor) back at their last safe spot.
- Carts: stop at walls and shelves and slide along them, the pusher is held back behind a blocked
  cart, a cart is only picked up when there is room in front, and a slip (or any drop) leaves it
  upright on the floor instead of throwing it into the air.
- Saves: old or damaged saves never hang the loading screen (clear message + **Discard old save**);
  v1.0 saves are migrated (backup kept as `level_N.save.v1.bak`); items carried by co-op players at
  save time are restored to whoever plays that slot, or put back on the floor, instead of being lost;
  the scanner glow is no longer saved; saves are written atomically and the host autosaves every
  2.5 minutes when something changed.
- Co-op: the client timer ticks every frame instead of every 2 seconds.
- Layout: the level-2 den PC tower sits on its desk. Level validator no longer flags floor items
  under a desk-top PC.
- Discs (M1.1): discs are now visible on the tray of an open case (they used to be buried inside the
  case's back panel, which also made them seem to vanish when put back); "Take out" puts the disc in
  your hand so it can be inserted elsewhere, dropped or placed immediately (loose only when your hands
  are full); aiming at a loose disc picks that disc instead of a neighbour in a pile; dropped or thrown
  items can no longer spawn inside walls or furniture, are rescued the instant they leave the level, and
  are not frozen in mid-air at the top of a throw.
- Hands (M1.1): holding and inspecting no longer cross the forearms; opening/closing a case moves both
  hands symmetrically; emotes are performed by your own first-person hands (no other hands).
- Bedroom (M1.1): the sorting table in the middle of level 1 is gone (more floor for co-op). Saves that
  had items on it load fine; those items go to the floor.
- Tests: regression suites for every fix above (`tools/run_tests.sh reg_*`), a 188-level validator
  sweep, real v1.0 save fixtures, and a client-clock check in `tools/net_test.sh`.

### v1.0
Polish release.
- Rendering: every case/box format now shares one unit mesh scaled per instance, so the store's
  ~1,000 visible items draw in ~50 batches (store draw calls roughly halved again); color grading
  pass (richer saturation/contrast under AgX); warmer store palette with checkerboard floor.
- Android: hardware back button pauses / goes back instead of quitting, screen stays awake while
  playing, the host auto-saves when the app is backgrounded, VIBRATE permission for haptics,
  Wi-Fi multicast lock for LAN discovery.
- Tutorial is a proper overlay (touch-friendly), long titles wrap on the inspect card, HUD panels
  take taps through the touch layer, hiding spots behind the TV.
- Co-op: per-player walked distance on the results screen, resumed saves are re-sent to clients
  that finished loading first.
- Title generator hardened against accidental real-game names (extended blocklist, whimsical
  words for generic genres).
- Tests: level completion -> results -> unlock, per-preset performance report
  (tools/perf_report.sh), README with playtime estimates and performance tables.

### v0.4
The store, endless mode and carts.
- Level 5 "Level Up Loot": a full fictional game store with ~1,550 items: storefront windows,
  New Releases wall (newest titles get their own section), double-sided platform aisles, Retro
  Zone (long boxes, big boxes, jewel cases), Pre-Owned & Golden Greats wall, Collector's Vault
  glass cabinets, bargain bins (hidden items), checkout counter, demo kiosks, arcade machines and
  a backroom with 8 delivery boxes to unpack. Estimated 4-player time ~50–60 min.
- Warehouse (Endless) mode: random platforms and a random mess every time, adjustable item
  count (100–2,000); the hall, aisles and loading bay are sized from the item count.
- Push carts: push with Interact, load up to 30 items, take items back out; synced in co-op.
- Bonus cosmetics unlock from total stars (crown, halo, disc hat, jetpack, wings, golden cape...).
- Performance: item LOD pairs, short-range detail clutter, flat floor tiles, lighter shelving,
  occlusion culling with wall/shelf occluders (store: ~1.4M -> ~0.16M primitives per frame).
- Mess generator: localized messes (discs land near their own case), per-level mess profiles;
  par times now come from the bot solver's playtime estimates.

### v0.3
More levels and every edition type.
- Level 2 "Living Room & Game Den" (~300 items, ORBIX 4/5 + Kestrel, steelbooks): sofa corner,
  fireplace, TV wall, arcade cabinets, gaming desk, neon sign, two rooms joined by a doorway.
- Level 3 "Basement Collector's Room" (~500 items): glass display cabinets for Collector's
  Editions, multi-disc games, laundry room and workshop, pinball machine, low warm lighting.
- Level 4 "Retro Attic" (~600 items): Sprocket 16 long boxes, Prism-32 jewel cases, HomeRig PC
  big boxes with manuals, dusty fog, floating dust motes, rafters, cobwebs, dim bulbs and a
  flashlight (L / touch button).
- Editions: standard, steelbook (metallic embossed shader), Collector's Edition (box + case +
  artbook + figurine + poster, every piece must be reunited), Golden Greats reprints (own
  banner, exact match required), multi-disc games (2–4 labelled discs), retro formats.
- Sort Scanner highlights the held item's correct case or shelf section (8 s, 20 s recharge;
  always on in Casual mode). Results screen with stars and per-player stats; host save/resume.
- Bot solver now solves every level; playtime estimates in tests/out/level_report.txt.

### v0.2
Co-op and customization.
- 1–4 player co-op over ENet with an authoritative host: grab ownership, compact events for
  inserts/shelving/opening, 15 Hz snapshots of moving items with client interpolation, 20 Hz
  player states, late-join full state sync, clean disconnects (host leaving returns everyone to
  the menu with a message, dropped players release what they held).
- Join via automatic LAN discovery (UDP broadcast, works on Wi-Fi and phone hotspots), room code
  (IP + port in 10 characters) or manual IP.
- Lobby with roster, ready-up, host level select, room code and a 3D line-up of everyone's bean.
- Character customization: body color palette + custom picker, 12 patterns, 12 eyes/expressions,
  16 hats, 11 glasses, 12 shirts, 11 backpacks, 11 gloves, 11 scarves, 11 capes; big RANDOMIZE
  with animation and confetti, per-category shuffle, nickname; synced to all players; mirror at
  the spawn; bonus cosmetics unlock with stars.
- Emote wheel (wave, dance, point, facepalm, cheer, shrug), quick chat, player bumping.
- Headless network test (host + 2 clients incl. late join, contested grab, swap, shelve, throw).
- "Unlock all levels" option, hat fit and UI fixes, brighter horror covers.

### v0.1
Vertical slice.
- Level 1 "Teen's Bedroom": ~150 items, ORBIX 5 + Pip-Go sections, dense procedural room
  (bed, desk, TV corner, beanbags, rugs, posters, string lights, windows with sky, mirror).
- First-person bean with walk/sprint/crouch/jump, wobbly body, mitten hands, slips on disc piles.
- Touch controls (floating joystick, drag-to-look, contextual buttons), keyboard/mouse, gamepad.
- Grab, carry, stack-carry (6), throw (charge), drop, inspect with drag-rotate and hi-res covers.
- Open/close cases, insert/scoop/eject discs, flip face-down discs, A–Z shelving with ghost
  preview and snap, sorting table, hidden stashes, Sort Scanner.
- Seeded catalog of 480 fictional games on 8 fictional platforms; procedural cover painter
  (front, back, spine, disc label, steelbook, posters) with texture-array atlases.
- Progress per section and level, timer, results with stars, save/resume.
- Synthesized SFX and music, settings (graphics presets, render scale, FPS cap/counter, audio,
  controls), headless tests and bot solver.
