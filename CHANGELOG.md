# Changelog

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
