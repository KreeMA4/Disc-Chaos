# Changelog

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
