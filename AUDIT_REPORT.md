# DISC CHAOS — Professional Audit Report

Audited build: **v1.0** (commit `8c6b1b3`), Godot 4.7.2, GDScript, Mobile renderer, Android arm64.
Audit type: read-only. **No gameplay code, scene, shader, config or test file was changed.** This file is the only addition.

---

## 0. Executive summary

Disc Chaos is a **technically coherent, feature-complete beta**. The data layer is the best part of it: one authoritative item model, a deterministic generator that survived a 188-level stress run, and a networking layer whose basics (late join, client-to-client visibility, disconnect cleanup) I verified in a 3-process run.

It is **not release-ready**. The audit found:

* **Five verified gameplay-breaking or world-breaking bugs.** Two are soft-lock or escape class: items put in a cart cannot be taken back out, and players can walk out of the map through window openings and fall forever.
* **A save/resume path that can hang the game.**
* **A cover-art system that produces near-identical covers within a genre**, which undermines the central "identify the disc" mechanic.
* **Level layouts that are boxy and sparse** compared with the brief ("should feel like actual places").
* **Almost nothing has been verified on a real phone.** Every performance, thermal, hotspot, touch-ergonomics and audio judgement in this report is either a workload measurement from a software renderer or an inference from code.

### Scorecard

| Area | Score | One-line reason |
|---|---|---|
| Overall project health | **6 / 10** | Solid core and tests; critical interaction bugs and zero device validation |
| Gameplay quality | **5.5 / 10** | Loop works and is readable; cart is broken, loop is repetitive, no catch mechanic |
| Graphics & presentation | **6 / 10** | Cohesive toon style and good UI; cover variety and environment depth are weak |
| Level design | **4.5 / 10** | Rooms are boxes with props; warehouse and store do not read as real places |
| Multiplayer quality | **6.5 / 10** | Architecture is sound and basics verified; no rejection feedback, snapshot > MTU, hotspot IP risk |
| Android performance | **6 / 10 (provisional)** | Workload numbers are good; defaults are aggressive and nothing is measured on-device |
| Code architecture | **6.5 / 10** | Clear layering in the data model; `Game` autoload is a god object; test duplication |

**How close to release-ready: roughly 60–65 %.** A realistic path is 5–6 focused milestones (section 12). The first one (critical fixes) is small.

---

## 1. Method, and what was and was not tested

### 1.1 Evidence labels used throughout

| Tag | Meaning |
|---|---|
| **[V]** | Verified by running something in this audit (existing suite, or a scratch probe) |
| **[R]** | Verified by reading the implementation (file/function cited) |
| **[S]** | Verified by rendering and looking at screenshots |
| **[U]** | **Unverified** — an inference or risk that needs a physical device or a long session |

### 1.2 What I actually ran

| Run | Result |
|---|---|
| Existing suites (`tools/run_tests.sh`: scripts, levels, gameplay) | **149 passing checks, 0 failures** (includes 60 scripts parse, 5 scenes load) |
| Existing net test (`tools/net_test.sh`, host + 2 clients) | PASS — but see E5: it asserts only checksum equality, and in this run the scripted "swap" step did not happen |
| Probe 1 (data level) | Aim-targeting of items inside containers/carts; scanner flag vs save; held items vs resume; room-code round trip (5,000 random IP/port pairs, 0 failures); cover override loader |
| Probe 2 (headless physics) | Stale-save Continue; collision at every window of every level; walking out of the store; cart into wall; slip while pushing cart |
| Probe 3 (headless physics) | Pile activation stability in levels 1, 3, 5 |
| Probe 4 (generator sweep) | The project's own validator + bot over 188 generated levels (40 seeds × L1–L4, 14 × L5, 14 × L6): **1,504 checks, 1 failure (a test false positive, see C9)** |
| Probe 5 (rendered under Xvfb) | Fully sorted shelves (L1, L5), store window view, 24-title cover sheets for two genres |
| Probe 6 (3 processes, localhost) | Client↔client visibility, late join, throw visibility, client timer, disconnect with held item |
| Probe 7 (layout data) | Floor area, prop count/variety, items per m², empty space per level |

Probe scripts live outside the repository. Section 12 (M1) recommends turning the failing ones into permanent regression tests.

### 1.3 What I did **not** and could **not** test

* **Any physical device.** No S25 Ultra, no low-end phone: frame rate, thermals, battery, touch ergonomics, haptics, safe areas, Android back gesture, keyboard overlap, hotspot behaviour. **[U]**
* **Audio by ear.** I cannot listen. Sound/music quality is assessed from the synthesis code only.
* **Long sessions.** No multi-hour soak, no memory-growth-over-time measurement. I recommend manual runs (section 9.4).
* **Network impairment** (latency, loss, 4 real phones). Localhost only, 3 processes.
* **Performance numbers** in section 8 come from the project's own `tools/perf_report.sh` (software Vulkan), which I read but did not re-run in this audit. They measure per-frame workload, not on-device FPS.

---

## 2. What is already good (and should not be rewritten)

1. **One authoritative item model** (`scripts/core/level_state.gd`). Every item is a single uid-keyed record; MultiMesh instances, physics bodies and client puppets are only views of it. Duplicate or missing items are structurally hard to produce. Host and clients ended with identical checksums in the net test, and in probe 6 a late joiner, client-to-client visibility and a leaving player's held item (released, 0 orphans) all behaved correctly. **[V]**
2. **Host-side ownership and race handling.** `Game._srv_grab` is first-come-wins; insert/open validate holders; `ItemWorld.apply_snapshot` ignores unreliable position packets for items that were meanwhile grabbed/shelved/inserted. This is careful work that avoids a common class of desyncs. **[R]**
3. **The generator is robust.** 188 generated levels, 1,504 checks, bot solves 100 % every time. **[V]**
4. **Rendering budget is well managed in design:** chunked MultiMesh batches with one unit mesh per case/box family (store ≈ 50 batches for ≈ 1,000 visible items), LOD pairs, short-range detail clutter, occluders, only items near a player are rigid bodies (capped at 90/70). **[R]**, numbers per `perf_report.md` **[U for device]**.
5. **Hi-res covers on inspected items** render crisply and use the same motif as the box/disc (confirmed in screenshots). **[S]**
6. **Nice integration details:** own bean hidden from the first-person camera but visible in the mirror via render layers; contextual touch-button labels; ghost preview for shelving; touch layout editor; room-code encode/decode correct for 5,000 random inputs. **[V][R]**
7. **Cover override pipeline works** (`user://covers_override/<id>_front.png` found and also used for the steelbook front). **[V]**
8. **Pile physics are mostly stable:** level 1 densest pile (56 items) stayed dead still; level 3 settled within 0.57 m; nothing fell through the floor or left the map. **[V]**
9. **Version gating on join** and zstd-compressed, versioned saves. **[R]**
10. **The transport seam exists** (`Net._make_server_peer/_make_client_peer`); a relay is feasible without touching gameplay RPCs (section 7.7).

---

## 3. Phase 1 — Architecture & code inspection

**Size:** ≈ 12.7 k lines of GDScript/shell. Biggest files: `game.gd` 953, `level_state.gd` 808, `world_builder.gd` 687, `cover_painter.gd` 673, `bean_model.gd` 654, `player.gd` 645.

**Layering (good):** `Defs/Catalog/Levels` (data) → `LevelLayout/Layouts/MessGen/ShelfPlanner` (generation) → `LevelState` (rules) → `ItemWorld/WorldBuilder/Player` (views) → `Game/Net` (session, RPC) → `scenes/main.gd` + `scripts/ui` (screens).

**Weaknesses:**

* **`Game` is a god autoload** (level lifecycle, 4-layer RPC plumbing for 12 actions, scanner, stats, save/load, particles, tweens). 331 references to `Game.` across the code base make it a hidden dependency of nearly everything. (E1)
* **Untyped dictionaries for core data** (`products`, `buckets`, `sections`, `stashes`, `tables`): 141 string-key reads of product fields alone; a typo is a silent `null`. `Item` is a proper inner class; the others are not. (E2)
* **Dead code:** 13 functions are never referenced, including `LevelState.release_all` (which would have prevented A4), `op_flip`, `Game.on_peer_joined_level`, `Covers.warm_titles`; 5 prop types are never placed (`chair`, `fridge`, `gondola` — the retail shelf —, `shelf_decor`, `stairs`). (E4)
* **Debug drivers ship in the APK** (`tests/*` is exported; `scenes/main.gd` loads `dev_shots`, `net_test_driver`, etc. when the matching command-line arg is present). (E6)
* **Mixed typing style:** many `:=` declarations were removed during development to dodge Variant inference errors, so static typing is inconsistent.
* **Signals/leaks:** no leak found. Connections made from screens to autoload signals are freed with the screen; `Covers._hires_cache` is LRU-capped at 64. **Disk** is the exception (B10).
* **Godot has no tracing GC**, so per-frame string/Dictionary churn (HUD context text, `_update_held_visual` signature strings, touch redraw) costs CPU, not pauses. Low priority.

**Export/build:** arm64 only, landscape, min SDK 24 (verified in manifest), permissions correct plus VIBRATE. CI gate (`[release]` or tag) works and v0.1–v1.0 published. Risks: B16 (signing key), E6, `build.sh` mutates tracked files via `sed` (E7).

---

## 4. Phase 2 — Gameplay & interaction audit

### 4.1 The ten questions

1. **Intuitive?** Mostly. One contextual Grab and one Interact button cover the loop, labels change with context, and shelving has a ghost preview. The rule "a case must be open before a disc goes in; `Interact` opens it" is the one thing newcomers must be taught; the tutorial is a single text card (C11).
2. **Unreliable interactions?** Yes: **targeting is distance-first, so containers shadow their contents** (A1). Also silent rejections in co-op (B14).
3. **Stuck / inaccessible / lost objects?** Yes: items in carts (A1), items held by a player at save time in multiplayer (A4), carts pushed into walls (A5), players leaving the map (A2). Items thrown out of the map *are* rescued (`ItemWorld._rescue`). Good.
4. **Collision and grabbing consistent?** Grabbing is ray-vs-AABB, collision is physics; they disagree for open cases/boxes (the AABB of an open flip-case spans both panels). Players do not collide with items at all (see 5.1).
5. **Carrying multiple objects natural?** A stack of up to 6 closed cases is simple and readable. Carts are not (B5).
6. **Frustrating / repetitive?** Yes (B4, B6): ≥ 6 inputs per product, wrong-disc correction needs "open, take out (drops to floor), put case down, grab disc, find right case, insert".
7. **Enjoyable after several levels?** Not on current evidence. New mechanics stop after level 4 (flashlight/retro formats) and level 5 (carts, which don't work well). The bot estimates the store at ≈ 205 min solo with **≈ 16 km walked** (≈ 27 m per product) — walking dominates.
8. **Enough variety?** Editions add rule variety (steelbook, Collector's box, multi-disc, jewel/long/big box with manual) — that is good. Verbs do not vary.
9. **Funny co-op moments?** Present: bumping, slipping, emotes, quick chat, throwing. Missing: anything that *requires* cooperation, and thrown items cannot be caught or even hit a friend (B19).
10. **Mechanics to add/improve?** See B4, B5, B6, B19, D1–D10.

### 4.2 Interaction-by-interaction

| Interaction | Verdict |
|---|---|
| Pick up disc | Works; ray-AABB padded 3 cm; 2.5 m reach is generous. A disc inside an open case on the floor **cannot be aimed at** (case wins) [V] |
| Inspect | Good: hi-res covers, drag-rotate, info card. First grab shows a flat grey placeholder until the async render finishes (B8) |
| Flip disc | Free discs: works. Held disc: only rotates the view (no state) — fine |
| Open/close | Works; `Interact` toggles. Open flip-cases get a 3×-wide AABB which makes aiming ambiguous |
| Insert / remove | "Scoop" and "Insert" are excellent one-press actions. **Remove** is weak: ejected item drops on the floor (B6) |
| Edition matching | Enforced by `LevelState.is_solved`; visible via banners/steel shader. Look-alike covers (B3) make it harder than it should be |
| Stack carry | Works; visual stack is fine |
| Throw | Works, charge-to-throw; no catch (B19); items ignore players (collision mask excludes players) |
| Carts | **Broken**: A1, A5, B5 |
| Search furniture | Works (one press empties a stash); no animation variety beyond a short tween |
| Sort table | 18 cells, snap placement; no automation. Only in some rooms (not "each room") |
| Scanner | Works, cooldown, casual mode; highlight flag leaks into saves (C1) |
| Shelve | Good. Wrong bucket / full bucket give a toast. A–Z is satisfied by auto-sorted insertion, so the player only needs the correct *bucket* — forgiving by design |
| Friends | Bumps, emotes, chat, shared state all fine |

---

## 5. Phase 3 — Physics & character audit

### 5.1 Physics

* **Engine:** Jolt, 60 Hz fixed, `max_physics_steps_per_frame=4`.
* **Layers:** world 1, player 2, item 4, cart 8. Player mask = world | player | cart; item mask = world | item | cart. **Players and items never collide**, so a player walks through every pile and thrown items pass through every player. Kicking items is a script (`ItemWorld.kick_near`), applied only to already-active bodies. It is a deliberate simplification that makes piles cheap, but it is also why catch/hit-a-friend can't work (B19).
* **Items:** one `BoxShape3D` per body sized from the item AABB; friction 0.75, bounce 0.12; masses: disc 0.03, case 0.15, big box 0.6, collector's box 1.2; CCD for discs and fast throws. Reasonable, and piles proved stable in the probe **[V]**. In the store pile one item peaked at 10.5 m/s on activation (interpenetration pop, C2). All discs/cases share one collider type, so open flip-cases get a very wide, thin box that can overhang surfaces.
* **Stacking:** carried stacks are visual only (no physics) — stable by construction. Floor "stacks" are placed with computed heights, stable in the probe.
* **Cart:** kinematic `AnimatableBody3D` with mask 0, placed in front of the player every physics tick, with **no collision test** → passes through walls (A5).
* **Frame-rate dependence:** movement, springs and lerps use `delta` correctly; footsteps use distance; slip checks are timer-based. The real problem is the opposite: **everything visible is updated at the physics rate** (B1).

### 5.2 Player movement and camera

* Walk 3.3, sprint 5.6, crouch 1.7 m/s, jump 4.6 m/s, gravity 13.
* Acceleration `18 × max(speed, 3)` ≈ 59 m/s² → **full speed in ≈ 0.06 s**. Responsive but weightless; no step-up, coyote time or jump buffering; stack slows only 4 % per item. For a game whose references (Human Fall Flat, Peak) sell physical clumsiness, the bean *looks* wobbly but *moves* like a standard FPS controller (B2).
* **Look input is consumed in `_physics_process`** and no physics interpolation is enabled (B1).
* Slip: probabilistic, camera roll tumble, drops all held items "in a comedic spray" — including a pushed cart (A5). Toggle "Ragdoll" only shortens the tumble.

### 5.3 Character animation

Procedural spring lean/squash/waddle/arm swing, blink, 6 emotes, cape sway: charming and cheap. Personality gaps: no expression changes on events (slip, success), remote crouch is a flat scale, remote slip is a fixed roll, `BeanModel.talk_t` is set when chat arrives but never read (dead stub). Own bean is correctly hidden in first person and visible in the mirror. **[R][S]**

---

## 6. Phase 4 & 5 — Environments, graphics, presentation

### 6.1 Level metrics (from the actual layouts, probe 7)

| Level | Rooms | Floor m² | Props (types) | Shelf units | Items | Items/m² | Floor > 2 m from any prop | Largest empty circle |
|---|---|---|---|---|---|---|---|---|
| 1 Bedroom | 1 | 36 | 55 (37) | 3 | 150 | 4.2 | 0 % | 0.7 m |
| 2 Living + Den | 2 | 90 | 81 (38) | 7 | 300 | 3.3 | 0 % | 1.7 m |
| 3 Basement | 3 | 124 | 82 (38) | 12 | 506 | 4.1 | 0 % | 2.0 m |
| 4 Attic | 2 | 116 | 69 (27) | 17 | 601 | 5.2 | 0 % | 1.8 m |
| 5 Store | 2 | 585 | 144 (31) | 39 | 1561 | 2.7 | 9.6 % | 3.4 m |
| 6 Warehouse (400) | 1 | 178 | 30 (12) | 10 | 401 | 2.3 | 1.2 % | 2.5 m |

### 6.2 Per-level assessment

* **Teen's Bedroom (6.5/10).** The strongest space: bed, desk with PC, TV corner, beanbags, rugs, string lights, figurines, posters, a mirror, hiding spots in the nightstand/dresser/beanbags/TV stand. It reads as a bedroom. It does not yet read as *someone's* bedroom: posters are random catalog covers, nothing tells a story (a half-built model, a half-eaten pizza on the bed, a game-night setup). One room, one wall of shelves.
* **Living Room & Game Den (6/10).** Coherent living room (sofa, fireplace, TV wall) and a den with arcades and neon. Two rooms joined by one door. Layout bug: the den PC tower overhangs the desk edge by ≈ 0.14 m (C7). Shelving is wall-hugging along one wall.
* **Basement Collector's Room (5/10).** Glass cabinets and a neon "HALL OF DISCS" are on-brief. But it reads as a **wood-panelled rec room**, not a basement (no concrete, pipes, boiler-room feel in the main room); the laundry and workshop are prop lists. A "collector's personal collection" would show curation (display plinths, labelled boxes, a desk with an open price guide).
* **Retro Attic (6/10).** Best *atmosphere*: fog, dust motes, rafters, bulbs, trunks, dust sheets, flashlight. But the walls are vertical: **an attic with no sloped roof**. The rafters sell it less than a pitched ceiling would.
* **Level Up Loot (5/10).** 585 m², neon zone signs, checkerboard floor, windows, kiosks, arcades, delivery boxes. It does not feel like retail: **aisles reuse the bedroom's white household shelf units** (the retail `gondola` prop exists but was never placed), no end-caps, price tags, promo stands, wall displays, queue rails; one checkout counter that does nothing; 9.6 % of the floor is > 2 m from anything, which in a big room reads as empty. The sorted result is a store with spine-out cases on bedroom shelves.
* **Warehouse (3.5/10).** 178 m² at the default 400 items (12.8 × 13.9 m), 30 props of 12 types. That is a large garage, not a warehouse. The hall grows with the item count but never gains racking variety, forklifts, pallet stacks, loading doors, or multiple bays.

**Common issues:** rectangular volumes; flat vertex-colour walls/floors (no texture, trim, wear, or decals); **windows are painted sky planes with no collision** (A2); at most 3 rooms per level; no hallways, stairs, or vertical variety; interactive furniture limited to "search" (one tween); the layouts are hand-placed lists of `add_prop` calls, so every future room costs the same effort.

### 6.3 Graphics & presentation

* **Style consistency:** good. Toon shader, rim light, outlines on props, rounded UI, chunky bean. One coherent look. **[S]**
* **Covers (the weak spot).** **[S][V]** The painter has 14 genre templates drawn from fixed fractions of the cover; only the palette (hue/lightness) and text vary per title. Rendering 16 consecutive stealth-genre titles gives **identical composition, figure, spotlight and laser lines on a teal-navy palette**; 23 kart-racer titles share the same road/sun/car and differ only in sky hue and title text. Platform banner, rating badge, publisher logo and title typography do vary, but "I recognise this game by its art" will not happen. Same-name titles on different platforms (e.g. a franchise appearing on ORBIX 4 and ORBIX 5) look nearly identical (B3).
* **Resolution:** atlas cells are 96×136 (fronts), 96×96 (labels), 204×20 (spines). A case 0.5 m away fills ≈ 700 px of an S25-Ultra-class screen, so covers on the floor look soft; the crisp 528 px version appears only when held (B8).
* **Disc/case models:** clean, bevelled where it matters; steelbook shader reads as metal; discs have a rainbow underside and ring text. **[S]**
* **Shelves:** spine-out with letter dividers and coloured lips. Legible up close; in the store the finished result looks sparse because buckets carry 32 % slack and many rows hold 1–4 cases. **[S]**
* **Lighting:** one directional light (shadowed) + unshadowed omni lights + strong ambient. Pleasant but flat; no AO except vertex gradients and blob shadows (SSAO is unavailable on Mobile by design). Store/warehouse look pastel and shadowless from distance. The store uses up to 20 omni lights; the engine documents per-mesh light limits on the Mobile renderer and `WorldBuilder` merges the whole architecture into **one mesh** per channel, so a light-limit/pop risk exists **[U]** (C5).
* **Post-processing/particles:** AgX, glow, saturation grade, dust motes, sparkles on stashes. Fine.
* **UI presentation:** consistent and appealing (section 10).

---

## 7. Phase 6 — Multiplayer audit

### 7.1 Architecture

ENet, host-authoritative. Pattern per action: `request_*` (any peer) → `rq_*` RPC → `_srv_*` validation → `ev_*` reliable broadcast applied by every peer to its own `LevelState`. Moving items: host RigidBody3D → 15 Hz unreliable snapshots → client puppets. Players: each peer owns its body, 20 Hz unreliable state. Time: 2 s unreliable sync. **Good and appropriate for LAN.**

### 7.2 Verified behaviour (3 processes, localhost) [V]

| Check | Result |
|---|---|
| Late join into a running level | Joiner loaded and saw the other players |
| Client A sees client B (client→client relay through the server) | **Works** |
| Leaving player holding an item | Item released; 0 items left owned by a missing peer |
| Contested grab | One winner (net test prints it but does not assert it) |
| Client HUD timer | Updates every 2 s only (B13) |
| Item snapshot packet | **Godot warned: "Sending 1940 bytes unreliably which is above the MTU (1392)"** (B11) |
| Client puppets in a busy area | A client held **76 individual puppet node trees** at once (B11) |

### 7.3 Findings list (full detail in section 11)

* No feedback when the host rejects an action (B14).
* Snapshot bigger than MTU; up to 90 puppets per client (B11).
* Client timer steps (B13).
* Hotspot IP selection risk (B12).
* Host trusts clients for distance/line of sight; no password; beacon is public on the LAN (B18).
* Save/resume with other peers' held items orphans them (A4).
* No automatic reconnect UI (a dropped client can simply rejoin: the late-join path works).
* Backgrounded phones: Android may suspend the app; ENet will time the peer out; host auto-saves only for itself **[U]**.

### 7.4 Desync scenarios considered

* *Duplicates:* none possible (single uid model). *Missing objects:* a late joiner depends on `srv_client_ready`; the host drops that request if it has not finished loading (`if not is_host() or st == null: return`). Because the generator is deterministic, both sides still start identical, so the result is benign unless the host resumed a save (that path re-sends full state after deserialize). **[R]**
* *Different states:* the scanner highlight flag is serialized into full-state syncs and saves (C1).
* *Players stuck:* A2/A5 are local-physics problems, not sync problems.
* *Handler race while a client is building its world:* `Game.ev_*` guard on `st == null` but some handlers also dereference `world`, which is created later than `st` during `load_level`. Not reproduced in probe 6 (no script errors in any log); noted as a latent risk **[R, not reproduced]** (E11).

### 7.5 Latency and reliability

Reliable events are ordered; unreliable snapshots can arrive after the event that made them stale — `apply_snapshot` guards this correctly. No client-side prediction for item actions: every grab/insert/shelve waits for the host round trip. Fine on a quiet LAN, likely noticeable on a congested hotspot **[U]**; hence B14's optimistic-with-rollback proposal.

### 7.6 Throwing between players

The thrown item is simulated only on the host and shown as puppets elsewhere. It collides with world/items/carts, **not with players** — so there is no catching, no hitting, no handing-off (B19).

### 7.7 Internet relay feasibility

* **Seam is good:** `Net._make_*_peer()` is the only place a transport is chosen; `players[1]`, `rpc_id(1, …)` assume a server with id 1, which any server-emulating transport provides.
* **Real work:** (a) a relay/lobby service; (b) room codes that carry a relay room id instead of IPv4+port; (c) NAT traversal if WebRTC is chosen (cellular CGNAT frequently needs TURN); (d) the "tiny relay that forwards packets" in the README is optimistic: Godot's multiplayer protocol means either a relay that speaks it (a dedicated Godot headless "router") or WebRTC mesh + signalling.
* **Cost estimate:** M–L, **no rewrite of gameplay**. Do it after B11/B14 because lossy long-haul links punish the current snapshot size and no-feedback design.

---

## 8. Phase 7 — Android performance audit

### 8.1 Workload (existing `perf_report.md`, software renderer, **not re-run**; see 1.3)

| Level | Preset | Max draw calls | Max primitives |
|---|---|---|---|
| Bedroom | Low / Med / High / Ultra | 75 / 141 / 216 / 261 | 35 k / 109 k / 181 k / 181 k |
| Basement | Low / Med / High / Ultra | 103 / 155 / 249 / 210 | 93 k / 226 k / 270 k / 363 k |
| Store | Low / Med / High / Ultra | 179 / 208 / 239 / 234 | 106 k / 162 k / 250 k / 258 k |
| Warehouse | Low / Med / High / Ultra | 86 / 121 / 228 / 158 | 52 k / 67 k / 188 k / 108 k |

* **Draw calls and primitives are modest for a phone GPU** and scale sensibly with presets. Good design, not over-optimized. No further optimization is recommended on these numbers.
* **Active bodies:** capped at 90 (70 in store); the densest piles simulated 32–79 bodies in my probes and settled.
* **VRAM/RAM:** ≈ 275–485 MB VRAM, 150–280 MB RAM in the report; one row shows 771 MB RAM for the store on Low (cause unconfirmed: likely transient first-run cover painting, which holds several 2048² images at once). **[U]** — profile on device.
* **Atlas memory:** a store level builds ≈ 5 uncompressed 2048² RGBA texture-array layers (≈ 22 MB each with mips ≈ 110 MB). Acceptable on a 12 GB device; relevant on low-end.

### 8.2 Risks (all **[U]** until measured on a device)

1. **Default quality is aggressive.** On mobile the default is preset **High**: render scale 1.0 at native resolution (≈ 3120×1440), MSAA 2×, outlines on props, 2048 shadow map, up to 6 lights, with a custom `light()` toon function per light. No dynamic resolution, no thermal governor, `Engine.max_fps = 60` with vsync on a 120 Hz-class panel. Expect the S25 Ultra to manage, a mid-range phone not, and heat in long sessions (B9).
2. **Frame pacing:** 60 fps cap on a 120 Hz display and 60 Hz physics with no interpolation (B1).
3. **Mirror:** a second full-scene render while within 4.5 m and facing it; the spawn is near the mirror in every level; disabled on Low (C10).
4. **Light limits on merged meshes** (C5).
5. **Client puppet spikes** when entering a dense pile (B11).
6. **Loading:** every level start repaints all cover atlas pages (B10); on first launch this is seconds of main-thread frame-waiting; I could not measure it on a phone.
7. **First grab hitch:** hi-res cover is rendered on demand (3 async renders + PNG saves per product) (B8).

### 8.3 Presets

Low (0.67 scale + FSR, no shadows/glow, 2 lights, mirror off), Medium, High, Ultra form a sensible ladder. Applying a preset requires a level reload (outlines/shadows are baked at build time) — documented in the UI but easy to miss. No "battery saver / 30 fps" profile that also lowers physics distance.

---

## 9. Phases 8 & 9 — UI/UX and testing

### 9.1 UI/UX

**Strengths:** one coherent chunky style, good contrast, clear contextual labels, loading tips, safe-area handling in code, adjustable touch layout, quick chat + emote wheel, results screen with stars and per-player stats. **[S][R]**

**Issues:**

* **Touch target / text sizes (computed for a 6.9″ 3120×1440 panel at 1920×886 base scale, ≈ 19.6 px/mm):** settings toggle/choice rows 5.3 mm, sliders 4.6 mm tall with a **3.6 mm grabber**, section/secondary labels ≈ 1.7 mm em, hint text ≈ 2.2 mm. Android guidance is ≈ 7–9 mm targets and ≥ 12 sp text (≈ 1.9 mm em). Menu buttons (7.0 mm) and HUD buttons (≥ 7.3 mm) are fine (B17).
* **Gamepad menu navigation:** buttons accept focus, but nothing ever calls `grab_focus()`, so a pad-only user lands on a screen with no focused control **[R; Godot's fallback behaviour unverified]**.
* **Colour picker** uses Godot's default popup, not touch-sized **[U]**.
* **Tutorial:** static card; no in-world guidance (C11).
* **No error/rejection toasts** for failed multiplayer actions (B14).
* **No accessibility options** (colour-blind-safe section colours, text size, reduced motion/camera roll).
* Level cards are in a horizontal scroll; HUD progress panel collapses on tap with no visual affordance.

### 9.2 Existing tests: what they prove

* **Suites (149 checks):** parse/load; generator invariants for 2 seeds per level; bot solves each; save/sync round trip; real-scene gameplay (solve through requests, throw, stack, ownership, stash, save/resume, cart push, level completion → results → unlock).
* **Net test:** 3 processes, late join, swap, throw, state-checksum equality.

### 9.3 Gaps

* **Rendering is never exercised by CI.** `Covers` returns early when headless, so the atlas pipeline, hi-res covers, every shader and the cover painter are untested by automation; a shader typo or painter regression would ship. (E5)
* **UI scenes and touch controls are never instantiated** by the suites.
* **Net test asserts too little:** checksum equality only. In my run `swap result parent=10` (the swap did not happen) and the test still printed PASS; the contested-grab result is printed, not asserted. No 4-player, host-leaves, packet-loss or latency tests.
* **Only seeds 1 and 2 per level** are tested while the game uses random seeds up to 100,000. My 188-seed sweep found no real failure, so this is a coverage rather than a quality problem.
* **Save/resume edge cases untested:** stale version (A3), multiplayer holders (A4), flags (C1).
* **No physics-stability or "can this item be reached by aiming" tests.** The cart "take out" test passed because it called `request_grab(uid)` directly, bypassing aiming (A1).
* **The level validator has a false positive:** `_valid_point` treats raised obstacles (desk-top PC tower at y = 0.77) as full-height columns, so a floor item under it fails (C9).

### 9.4 Manual tests I recommend (too long/hardware-bound to run here)

1. 30-minute soak on S25 Ultra per preset: FPS trace, temperature, battery %/10 min, RAM.
2. 120 Hz judder check with look-around (B1).
3. Hotspot session: host on phone A with mobile data on, joiners on B and C; verify the room code decodes to a reachable IP.
4. Full store with 4 phones: item flow, cart usage, snapshot bandwidth.
5. Touch ergonomics with 3 testers; gamepad-only menu navigation.
6. Aural review of SFX/music (C4).
7. Update-install test across two CI-built APKs (B16).

---

## 10. Phase 10 — Features and future potential

See section 11-D for the list. Guiding principle: **deepen the existing verbs** (find → match → carry → shelve) and give friends reasons to coordinate, rather than adding unrelated modes.

---

## 11. Findings catalogue

Format per finding: **Where / Currently / Why it matters / Recommendation / Complexity & risk / How to test.**
Complexity: S < ½ day, M ≈ 1–3 days, L ≈ a week+. Priority: Critical / High / Medium / Low.

---

### A. Critical issues

#### A1 — Containers shadow their contents: items in a cart are unreachable; discs in open cases and pieces in open boxes cannot be aimed at
* **Category / Priority:** A / **Critical** (a soft-lock on the store level)
* **Where:** `scripts/core/level_state.gd` (`raycast`, `local_aabb`), `scripts/player/player.gd` (`_do_grab`, `context`), `scripts/core/game.gd` (`_srv_grab`)
* **Currently [V]:** `raycast` returns the hit with the smallest entry distance. A container's AABB (cart 0.7×0.9×1.0 from the floor; open flip case ≈ 2× wide; open box) is always entered before the items inside it. Probe: items placed in a cart were reachable by aiming from above or the side in **0 of 4** cases; a disc in an open case on the floor and an artbook in an open collector's box could not be targeted either (the container was returned). While *holding* the cart the cart is excluded from the ray (so contents are aimable) but `_do_grab` returns immediately for carts and `_srv_grab` rejects grabs with a non-empty hand.
* **Why:** Anything a player puts into a cart is stranded; if it is a needed item the level can never be completed. The gameplay test missed it because "items can be taken out of a cart" called `request_grab(uid)` directly.
* **Recommendation:** In `raycast`, when a hit item's ancestor is also hit, prefer the **descendant** (deepest child wins; tie-break by smaller AABB). Also allow grab/insert while pushing a cart (grab = move into cart; "Take out" = aimed grab from cart).
* **Complexity / Risk:** S–M / Medium (targeting touches everything; keep the old rule for non-nested items).
* **Test:** unit test on raycast (cart, open case, open CE box) from above/side; in-engine aiming test; keep the failing probe as a permanent regression test.

#### A2 — The map is not closed: window openings have no collision and the player has no out-of-bounds recovery
* **Category / Priority:** A / **Critical** (store), High (levels 1–4 via furniture)
* **Where:** `scripts/world/world_builder.gd` (`_wall`, `_window`), `scripts/player/player.gd`
* **Currently [V][R]:** `_wall` creates colliders only for wall pieces above/below a hole; `_window` creates visuals only (glass quad + sky plane). In every level at least one window opening had nothing blocking a ray through it (the others were blocked only by furniture standing in front). In the store the windows start at 0.35 m and 0.05 m: a probe walking toward the 2.6 m window left the building and **fell to y = −163 m in 6 s**, with no respawn. Levels 1–4 have 1.0–1.85 m sills, reachable by jumping from a bed/beanbag (apex 0.81 m + 0.55–0.65 m furniture) **[inference]**. Items are rescued (`_rescue` at y < −3); players are not.
* **Why:** Breaks the game for the one player who tries, and in co-op desynchronizes the group's play space; a bored tester will find this in minutes.
* **Recommendation:** Invisible window collider (full opening, glass layer) in `_window`; `Player` out-of-bounds guard (outside all room rects + margin, or y < −3 → teleport to spawn with a joke toast).
* **Complexity / Risk:** S / Low.
* **Test:** the window-ray probe across all levels (assert every window blocked); walk-into-window test with y bound.

#### A3 — "Continue" on a save from an older version hangs the game on the loading screen
* **Category / Priority:** A / **High**
* **Where:** `scripts/core/game.gd` (`has_save`, `load_save`, `resume`), `scenes/main.gd` (`start_solo`/`host_start`), `scripts/ui/level_select.gd`
* **Currently [V]:** `Defs.CATALOG_VERSION` doubles as the save-compat and the network-compat version (it was bumped 3→4→5 during development). `has_save` only checks that the file exists, so Continue is offered; `load_save` returns `{}` for another version and `resume` simply returns. `main` has already shown the loading screen. Probe: after 3 s, loading screen visible, `Game.running = false`, no level.
* **Why:** Every catalog change silently bricks every player's save *and* traps them on a screen they can only leave by killing the app.
* **Recommendation:** Separate `SAVE_VERSION`; validate the header in `has_save`; `resume()` returns bool and `main` returns to the menu with a message; offer "delete old save". Consider keeping seeds stable so older saves remain loadable.
* **Complexity / Risk:** S / Low.
* **Test:** stale-save probe → expect menu + message; version-bump test.

#### A4 — Items held at save time are permanently lost when the game is resumed with different peer ids
* **Category / Priority:** A / **High** (multiplayer saves)
* **Where:** `scripts/core/level_state.gd` (`serialize/deserialize/hands`), `scripts/core/game.gd` (`save_game`)
* **Currently [V]:** `hands` and `Item.holder` (peer ids) are serialized. A client's peer id is random each session. Probe: an item held by peer 1865923442 at save → after resume the holder is still that id, `op_grab` by another peer fails and `held_by(new peer)` is empty. Nobody can ever pick it up. `LevelState.release_all` exists but is never called.
* **Why:** In co-op, saving mid-task silently deletes whatever friends were carrying; the level can become uncompletable. Solo is unaffected (host id is always 1).
* **Recommendation:** On save, release every non-host holder's items (or store holders as player *index*, not peer id, and remap on resume).
* **Complexity / Risk:** S / Low.
* **Test:** the probe, plus a 3-process save-with-held-items → resume test.

#### A5 — Carts pass through walls, and slipping while pushing a cart teleports it into the air
* **Category / Priority:** A / **High** (store)
* **Where:** `scripts/player/player.gd` (`cart_xf`, `_update_cart_push`, `start_slip`), `scripts/items/cart_node.gd`, `scripts/core/game.gd` (`local_cart_move`)
* **Currently [V]:** the cart transform is `player position + 0.95 m forward` with no collision test; its collider is kinematic with mask 0. Probe: pushing into the store's west wall left the cart's centre at x = −0.53 (wall at 0) → cart and cargo inside/through the wall. `start_slip()` releases *everything held* including the cart at `global_position + (0, 1.0, 0)` with a random yaw: cart y went 0.04 → **1.04**, un-held.
* **Why:** Carts get lost in geometry and float after a slip — slips are common in the store's disc piles.
* **Recommendation:** Move the cart with a shape cast/`move_and_collide` against the world layer and slide; skip carts in the slip spray (or drop them at floor height). Add a collision exception only for the pusher.
* **Complexity / Risk:** M / Medium (kinematic body + network smoothing).
* **Test:** the two probes (wall, slip) become tests; manual push through the 1.1 m basement door.

---

### B. Important improvements

#### B1 — Camera/look and movement run at the 60 Hz physics rate; no physics interpolation; FPS cap offers 120
* **Where:** `scripts/player/player.gd:145–156` (`_physics_process`, `_look_accum`), `project.godot` (no `physics_interpolation`), `scripts/ui/settings_menu.gd` (FPS cap 30/60/120)
* **Currently [R]:** look input is accumulated and applied in `_physics_process`; the camera is a child of a `CharacterBody3D` moved in the physics tick.
* **Why [U]:** On a 120 fps cap the picture will update at 60 Hz for look and movement and add up to a tick of look latency — on a touch game where look-drag is the main control.
* **Recommendation:** Apply rotation in `_process` (render rate), enable 3D physics interpolation for the player/cart/remote bodies (or interpolate the camera pivot), and set the cap from `DisplayServer.screen_get_refresh_rate()`.
* **Complexity / Risk:** M / Medium (hands, held-item sway, ghost preview depend on camera transform).
* **Test:** on-device 120 Hz look-around frame-time capture; regression via screenshot of two consecutive render frames' camera yaw delta.

#### B2 — Movement is responsive but weightless; the "wobble" is cosmetic
* **Where:** `player.gd` (accel `18 × max(speed,3)`, no coyote/step), `bean_model.gd`
* **Currently [R]:** full walking speed in ≈ 0.06 s; stack slows 4 %/item; bean lean/squash is a visual spring, not tied to physics; players don't collide with items.
* **Why:** The funny physical clumsiness is a core pillar (references: Human Fall Flat, Peak) yet the controller is a standard FPS one.
* **Recommendation:** Lower acceleration (≈ 20–30 m/s²), heavier stack slowdown/lean, landing/turn recovery, mild "stumble" on sprint-turns, coyote time. Keep it forgiving.
* **Complexity / Risk:** S–M / Low.
* **Test:** playtest A/B; unit-test acceleration constants; ensure carts/inspect still work.

#### B3 — Covers are nearly identical within a genre
* **Where:** `scripts/covers/cover_painter.gd` (`motif`), `scripts/covers/cover_palette.gd`
* **Currently [V][S]:** one fixed composition per genre; per-title variation is palette + typography + banner. 16 stealth titles and 23 kart titles in a row were visually the same picture.
* **Why:** The loop is "identify the disc". With look-alike art, identification reduces to reading small text; the 480-title catalog's variety is invisible; same-name titles on different platforms are indistinguishable except by banner.
* **Recommendation:** Per-title composition seed (positions, counts, scale, hero shape, time of day, extra props), 2–3 layout variants per genre, publisher-specific frame styles, era-specific art (16-bit pixel look for Sprocket, CD-era for Prism), tagline strip. Keep the same motif function for box/disc/spine so the matching property is preserved.
* **Complexity / Risk:** M–L / Medium (cover cache keys, atlas budget).
* **Test:** regenerate per-genre sheets; automated pairwise-difference metric between covers of the same genre above a threshold; confirm disc label still matches box.

#### B4 — The loop is repetitive and walking-dominated; verbs stop evolving after level 4
* **Where:** design; `mess_gen.gd`, `levels.gd`
* **Currently [R][V]:** ≥ 6 inputs per product; bot: store ≈ 205 min solo, ≈ 16.1 km walked; new mechanics: L2 steelbooks, L3 Collector's/multi-disc, L4 flashlight/retro formats, L5 carts (weak).
* **Why:** The store alone is ≈ 3.5 hours of the same 6 actions with long walks.
* **Recommendation (small, loop-preserving):** one-press "shelve" for a held stack's matching cases; auto-snap a held disc into an aimed open case; shared pings; make the sort table a real tool (auto-open/pair); level events (section 11-D); lighter walking (shorter hall, better bucket locality, working carts). Re-run the bot after each change.
* **Complexity / Risk:** M–L / Medium (balance, test estimates).
* **Test:** bot playtime report; input-count-per-product metric; playtest sessions.

#### B5 — Cart UX: can't collect while pushing, one item per action, retrieval broken
* **Where:** `player.gd` (`_do_grab`), `game.gd` (`_srv_grab`), `level_state.gd` (`slot_xf`)
* **Currently [R]:** holding a cart blocks every other action; to load it you let go, grab an item, aim "Into cart", repeat; cargo is laid out on a fixed 3×5 grid with row spacing 0.17 m, so big boxes (0.33 m) overlap visually.
* **Why:** The store was built around carts ("carts carry 30 items") but using one costs more steps than not using it; the bot never uses one, so the 205-minute estimate may be wrong either way.
* **Recommendation:** After A1: allow grab-to-cart while pushing, "Take out" from aimed cargo, layout that respects item size, optional auto-load when walking over items.
* **Complexity / Risk:** M / Medium.
* **Test:** cart scenario test with aiming; bot variant that uses carts.

#### B6 — Removing a disc from a case drops it on the floor; wrong-disc correction is a long chain
* **Where:** `game.gd` (`ev_eject`), `level_state.gd` (`op_eject`), `player.gd` (`_do_interact`)
* **Currently [R]:** "Take out" releases the item onto the floor; the hand rule (only closed cases stack) forbids holding a disc and a case together.
* **Why:** Swapped discs are a major part of the mess (the generator swaps roughly 14 % of cased discs in the store and 28–38 % in the other levels).
* **Recommendation:** Allow one disc in the "off-hand" while carrying a case, or put the ejected disc in hand when the hand allows; show the matching case with the scanner.
* **Complexity / Risk:** M / Medium (touches ownership validation and net).
* **Test:** gameplay test of swap in ≤ 4 inputs; net test of the same.

#### B7 — Environments are boxy and thin; store, warehouse and attic don't match their identity
* **Where:** `scripts/world/layouts.gd`, `layout.gd`, `world_builder.gd`, `prop_factory.gd`
* **Currently [V][S]:** see 6.1/6.2. Single-volume rooms, ≤ 3 rooms per level, vertical attic walls, household shelves in the store, 30-prop warehouse.
* **Why:** The brief asks for places, not prop collections; levels 5 and 6 are the most-played.
* **Recommendation (prioritized):** (1) warehouse scale/racking/pallet/forklift/loading-bay pass and a proper hall that grows by bays; (2) store retail fixtures (use the existing `gondola`, add end-caps, price/sale signage, wall displays, a working-looking counter with register, queue rails); (3) attic pitched ceiling with dormer window; (4) basement concrete/pipes/boiler cues and a curated collector's alcove; (5) one more connected room for L1–L3 (hallway/closet); (6) environmental stories per room (one detail that explains who lives/works there); (7) interactive furniture (drawers, closet doors, trunk lids) replacing single-press stashes.
* **Complexity / Risk:** L / Low–Medium (layouts feed tests; new layouts must pass the suite).
* **Test:** the level suite + multi-seed sweep; empty-space/prop-density metrics (probe 7); walkthrough screenshots; navigation check through doors/aisles for a 0.64 m capsule.

#### B8 — Floor covers are soft; the first grab of each product shows a grey placeholder
* **Where:** `scripts/covers/covers.gd` (`COVER_CELL = 96×136`), `scripts/items/hires_materials.gd`
* **Currently [R][S]:** hi-res (528 px) renders asynchronously on first grab; until then the material uses a flat grey 4×4 texture; renders + PNG saves happen on the main thread.
* **Recommendation:** use the already-resident atlas cell as the placeholder; promote the *aimed* item to hi-res; pre-render the 3–4 nearest; consider a 192×272 tier for fronts; compress atlases.
* **Complexity / Risk:** M / Low–Medium.
* **Test:** screenshot comparison on grab (frame 1 vs frame 10); frame-time capture on first grab per product on device.

#### B9 — Android defaults and thermal behaviour
* **Where:** `scripts/core/settings.gd` (default preset High, render scale 1.0), `project.godot`
* **Currently [R], risk [U]:** see 8.2.
* **Recommendation:** first-launch auto preset (e.g. render scale ≈ 0.8 + FSR on devices above 2 M pixels), adaptive resolution based on frame time, "Battery saver (30 fps)" profile, thermal-aware step-down using `OS` heat callbacks if available.
* **Complexity / Risk:** M / Low.
* **Test:** 30-minute soak per preset on the S25 Ultra and one mid-range phone; frame-time histogram; temperature log.

#### B10 — The cover cache is per-level-seed: every level start repaints everything and the cache grows without bound
* **Where:** `scripts/covers/covers.gd` (`build_level_atlases`, `_render_array`, cache key `ver_level_seed_count`)
* **Currently [V]:** each play uses a random seed, so cache keys never repeat except for resume. This dev machine accumulated **342 MB in 494 files** from test/dev runs. Store pages alone are several MB each.
* **Why:** Load time (repaint every start), storage creep on a phone, and "generate at build/first launch and cache" is only half met.
* **Recommendation:** Generate one **global atlas** for all 480 titles (fronts, spines) and all disc labels once (≈ 2+1+3 pages) at first launch; levels index into it; delete other-version caches at boot; cap the hi-res cache.
* **Complexity / Risk:** M / Medium (index mapping, multi-disc labels, overrides).
* **Test:** level load-time before/after; cache directory size after 20 level starts; visual diff of a level.

#### B11 — Item snapshots exceed the MTU, and clients build dozens of puppet node trees at once
* **Where:** `scripts/items/item_world.gd` (`pack_snapshot`, `apply_snapshot`, `activate`), `game.gd` (`_process`)
* **Currently [V]:** Godot warned "Sending 1940 bytes unreliably which is above the MTU (1392)"; a client held 76 puppets simultaneously (28 B/body × 76 per tick).
* **Why:** Fragmented unreliable packets are lost as a unit (worse on hotspots); 76 individually drawn items on a phone client cause a spike when entering a pile.
* **Recommendation:** ≤ 40 bodies per packet, prioritized by distance to each client; half-float/quantized transforms; pool puppets; draw puppets through the MultiMesh path; or throttle host activation around remote players.
* **Complexity / Risk:** M / Medium.
* **Test:** 3–4 process run logging bytes/s and MTU warnings in a dense pile; client frame time while entering a pile.

#### B12 — Room code / hotspot IP selection may be wrong on a phone hosting a hotspot
* **Where:** `scripts/net/net.gd` (`local_ipv4`, `_start_beacon`)
* **Currently [R], impact [U]:** `local_ipv4()` returns the *first* address in `IP.get_local_addresses()` that starts with `192.168.`, `10.` or `172.`. A hotspot host phone also has cellular interfaces whose addresses are often `10.x`/`172.x` (CGNAT); ordering is unspecified, so the room code and lobby text could carry the wrong IP. `172.` also matches non-private 172.x. Discovery is *not* affected (the listener uses the packet's source IP), and subnet broadcasts are derived per address as `a.b.c.255` (fine for /24, wrong for /16 or /8).
* **Recommendation:** prefer `192.168.43/44.x` then other `192.168.x`, then `172.16–31`, then `10.x`; show every candidate in the lobby; let "Join by code" try the decoded IP and fall back to discovery.
* **Complexity / Risk:** S / Low.
* **Test:** unit tests with mocked address lists; on-device hotspot session with mobile data on.

#### B13 — Client HUD timer updates in 2-second steps
* **Where:** `game.gd` (`_process`, `ev_time`)
* **Currently [V]:** `st.elapsed` is advanced only on the host; clients receive it every 2 s — 90 rendered frames showed 1 distinct value.
* **Recommendation:** advance locally between syncs and correct on receipt.
* **Complexity / Risk:** S / Low. **Test:** probe 6.

#### B14 — Rejected multiplayer actions give no feedback; no optimistic response
* **Where:** `game.gd` (`_call_host`, `_srv_*`), `player.gd`
* **Currently [R]:** `request_*` is fire-and-forget; `_srv_*` returns silently on failure (taken by someone else, capacity, bucket full).
* **Why:** On a slow link the player taps and nothing happens, and cannot tell "someone beat me" from "network lag".
* **Recommendation:** `ev_reject(code)` to the requester (toast + haptic), optimistic hand fill for grab with rollback, brief "pending" visual.
* **Complexity / Risk:** M / Medium.
* **Test:** contested-grab test asserting the loser gets the rejection; latency injection.

#### B15 — No periodic autosave
* **Where:** `game.gd` (`save_game` call sites: pause menu, leave, app pause)
* **Currently [R]:** the store is ≈ 3.5 h solo; a crash or dead battery loses everything.
* **Recommendation:** autosave every 2–3 minutes on the host (≈ 35 KB compressed) and offer resume.
* **Complexity / Risk:** S / Low. **Test:** kill-process test then Continue.

#### B16 — Release signing key stability
* **Where:** `tools/setup_toolchain.sh`, `.github/workflows/android.yml`
* **Currently [R], impact [U]:** the debug keystore is generated into `.toolchain/` and survives only through `actions/cache` (evicted after 7 days of disuse). A new keystore means an APK that Android refuses to install over the previous one; players must uninstall (losing saves/profile). Local builds use a different keystore than CI.
* **Recommendation:** commit a dedicated debug keystore or provide one via a repository secret; keep it identical locally and in CI.
* **Complexity / Risk:** S / Low. **Test:** install v(n) then v(n+1) built on different days.

#### B17 — Touch target and text sizes in menus/HUD; gamepad focus
* **Where:** `scripts/ui/ui_kit.gd`, `settings_menu.gd`, `hud.gd`, `customize.gd`
* **Currently [R], computed:** see 9.1. No `grab_focus()` anywhere.
* **Recommendation:** raise slider/toggle heights and grabbers to ≈ 8 mm, set HUD secondary text ≥ 24 virtual px, add initial focus per screen, theme the colour picker for touch, collapse affordance on the progress panel.
* **Complexity / Risk:** S–M / Low. **Test:** on-device ergonomics test; screenshot review at S25 Ultra and a 1080p phone.

#### B18 — Host trusts clients; session is open to the whole LAN
* **Where:** `game.gd` (`_srv_insert/_srv_open/_srv_eject/_srv_reveal/_srv_bump/_srv_release`), `net.gd`
* **Currently [R]:** no distance/line-of-sight checks; `xf` and velocity from clients are used as sent (velocity clamped); the beacon advertises the game to the LAN and joining needs no password; the `look` dictionary from clients is not validated (an out-of-range index would throw a script error in `BeanModel`).
* **Why:** Fine with friends; matters on shared/public Wi-Fi and for future relay play.
* **Recommendation:** reach/line-of-sight sanity checks on the host (generous), optional room PIN, validate look ranges.
* **Complexity / Risk:** S–M / Low. **Test:** protocol test sending out-of-range requests.

#### B19 — No catch mechanic; thrown items pass through players
* **Where:** `scripts/core/defs.gd` (layers), `player.gd`, `item_world.gd`
* **Currently [R]:** the original brief lists "throw, catch"; only throw exists. Item bodies don't collide with players.
* **Why:** Passing items between friends is the most natural funny co-op moment in this game.
* **Recommendation:** a catch window (hold Grab as an item approaches within a cone/radius → auto-grab with a satisfying sound), optional "bonk" feedback when hitting a friend (no damage).
* **Complexity / Risk:** M / Medium (host-authoritative grab of an in-flight body).
* **Test:** two-process throw/catch test; latency injection.

---

### C. Polish

| ID | Name | Where | Currently / evidence | Recommendation | Priority | Cx / Risk | Test |
|---|---|---|---|---|---|---|---|
| C1 | Scanner highlight flag persists in saves and full-state syncs | `level_state.gd` serialize | **[V]** `flags` bit 2 survives save/load; never cleared → permanent glow | Mask runtime bits out of `serialize` | Low | S / Low | probe 1 |
| C2 | Dense piles can "pop" on activation | `item_world.gd` | **[V]** store pile: one item peaked at 10.5 m/s (≤ 0.34 m displacement) | Slight separation, zero-velocity wake, damping for the first 0.3 s | Low | S / Low | probe 3 |
| C3 | Character personality | `bean_model.gd`, `remote_player.gd` | **[R]** `talk_t` unused; remote crouch = scale; no event reactions | Reaction faces (slip, success), shelve celebration, squash on throw, name-tag colour | Medium | S–M / Low | visual review |
| C4 | Audio depth | `tools/synth_audio.py`, `sfx.gd` | **[R]** 28 SFX, 7 loops; single footstep sample; no ambience/cart rolling; quality not heard | Ambience per level, surface/pitch variation, cart rolling, ducking; human review | Medium | S–M / Low | listening test |
| C5 | Lighting flatness and per-mesh light risk | `world_builder.gd` | **[S]** ambient-dominated; architecture is one mesh spanning the level; store has up to 20 omni lights; Mobile renderer has per-mesh light caps **[U]** | Split architecture into 8 m chunks like props; warm/cool accent zones; emissive bounce quads; check on device | Medium | M / Low | on-device walk, light-count log |
| C6 | Sorted shelves look sparse | `shelf_planner.gd`, `world_builder.gd` | **[S]** 32 % slack, 1–4 cases per row in places | Tighter packing, face-out "featured" slot per bucket, end-caps | Low–Med | S–M / Low | screenshot |
| C7 | Den PC tower overhangs the desk | `layouts.gd:183` | **[R]** desk spans z 0.9–2.3, tower at z 2.55 | Move tower to z ≈ 2.1 | Low | S / None | layout check |
| C8 | Cart cargo overlaps visually | `level_state.gd` `slot_xf` | **[R]** fixed 0.17 m row spacing | Size-aware packing | Low | S / Low | screenshot |
| C9 | Level validator false positive | `tests/suite_levels.gd` `_valid_point` | **[V]** flagged L2 seed 30: floor item under the raised tower | Compare obstacle y-range | Low | S / None | multi-seed sweep |
| C10 | Mirror renders full scene at full frame rate | `mirror_node.gd` | **[R]** active within 4.5 m and facing; spawn is near the mirror | Update at 15–20 fps, lower res | Low | S / Low | device frame time at spawn |
| C11 | Tutorial is a text card | `hud.gd`, `tutorial.gd` | **[S]** | Guided first-product steps with highlights, skippable | Medium | M / Low | new-player test |
| C12 | `README` claims the on-device override path (`/sdcard/Android/data/…/files/covers_override/`) | `README.md` | **[U]** the code reads `user://covers_override/`; whether `user://` maps to that folder on Android 7–15 was not verified | Verify on device, document the real path or add an in-app "open folder" | Low | S / None | on-device |

---

### D. New features (suggestions, ordered by fit)

1. **Catch & pass, two-person carry** (B19): heavy Collector's boxes need two players; handing a stack over; funny failure modes.
2. **Shared pings/markers**: point at an item/shelf; "I need this disc" call with the scanner target highlighted for the teammate.
3. **Mess events**: delivery truck drops boxes, a shelf slips a row of cases, lights flicker (attic), a cat knocks things off a table, a "rush hour" in the store — breaks monotony without new verbs.
4. **Hidden collectibles / rare editions**: golden disc, misprint (wrong art), signed edition; a collection book that rewards stars and drives cosmetic unlocks.
5. **Interactive furniture**: drawers that slide, closet doors, trunk lids, rolling ladders; replaces single-press stashes and makes "searching" a small game.
6. **Challenge modes / daily seed**: time attack, no-scanner, "blackout" (flashlights only), shareable Warehouse seed codes.
7. **Sorting aids that fit the theme**: sorting tray/basket, price-gun style "tag" to mark cases for a teammate, label maker for custom shelf sections in Warehouse.
8. **More cosmetics and emotes**: high-five/fist-bump between two players, seasonal sets, store-themed outfits unlocked by collectibles.
9. **Better communication**: off-screen player indicators, "who holds what" chips, a section minimap.
10. **Replayability for Warehouse**: modifiers (slippery floor, double-sided boxes, speed shelving), rotating layouts.

---

### E. Technical debt

| ID | Item | Evidence | Recommendation | Priority | Cx / Risk |
|---|---|---|---|---|---|
| E1 | `Game` is a 953-line god autoload | 331 `Game.` references | Split into `LevelSession`, `ItemActions` (RPC), `SaveService`, `ScannerService`; keep `Game` as a thin facade first | Medium | L / Medium |
| E2 | Core data as untyped Dictionaries | 141 string-key reads of product fields | Typed `Product`, `Bucket`, `Section` inner classes (like `Item`) | Medium | M / Low |
| E3 | Three copies of "solve a product" | `tests/bot_solver.gd`, `suite_gameplay._solve`, `net_test_driver._solve_index` | Share one helper that goes through the public request path | Low | S / Low |
| E4 | Dead code | 13 unreferenced functions; 5 prop types never placed | Delete or use (`release_all` → A4; `gondola` → B7) | Low | S / None |
| E5 | Test gaps | See 9.3 | Rendering smoke test under Xvfb in CI; net test assertions; multi-seed sweep in CI; save/resume edge cases; "aim reach" tests | High | M / None |
| E6 | Debug drivers shipped in the APK | `tests/*` exported; cmdline handlers in `main.gd` | Exclude `tests/*` in export filter; gate handlers behind a debug feature tag | Low | S / Low |
| E7 | `build.sh` mutates tracked files | `sed` on `export_presets.cfg`, `project.godot` | Generate to a temp copy; or commit version bump explicitly | Low | S / Low |
| E8 | Preset changes need a level reload | `world_builder.gd` bakes shadows/outlines | Rebuild on change or label clearly | Low | S–M / Low |
| E9 | Inconsistent static typing | `:=` removed in many places | Gradual typing pass with the editor's warnings on | Low | M / Low |
| E10 | Per-frame allocations in UI/HUD | `player.context()` called twice per frame (HUD and touch), signature strings in `_update_held_visual` | Cache per-frame/on-change | Low | S / Low |
| E11 | Latent null-`world` window while a client loads | `Game.load_level` sets `st` before `world`; some `ev_*` handlers dereference `world` | Guard all `ev_*` on `world` as well; **not reproduced** | Low | S / Low |

---

## 12. Recommended development roadmap

Small, independently testable milestones. Each ends with the test gate named. Dependencies in brackets.

### M1 — Critical fixes and regression tests (≈ 1 week)
A1 (targeting priority), A2 (window colliders + out-of-bounds respawn), A3 (save version + hang), A4 (release held items on save), A5 (cart collision + slip), C1, C7, C9, B13, B15 (autosave).
**Gate:** the failing probes from this audit become permanent tests (aim-reach, window-block, stale-save, held-after-resume, cart-wall, cart-slip, flag-in-save); 188-seed sweep in CI.

### M2 — Device validation round (≈ 2–3 days, **do right after M1 so later work is informed**)
Install on the S25 Ultra and one mid-range phone; run section 9.4 manual tests 1, 2, 3, 5, 7. Add an optional on-screen perf log (FPS, frame time, temperature) to the existing counter.
**Gate:** a measured performance table per preset and a list of device-only bugs. Re-rank B1/B9/B11/B12/B17 with real numbers.

### M3 — Input, feel and interaction (≈ 1–1.5 weeks) [M1, M2]
B1 (look in `_process`, interpolation, refresh-matched cap), B2 (movement weight), B5 (cart UX), B6 (take-out into hand), B19 (catch).
**Gate:** 120 Hz capture; gameplay tests for each interaction through *aiming*; bot variant using carts; playtest.

### M4 — Multiplayer hardening (≈ 1 week) [M1; B11 before any relay work]
B11 (snapshot budget, puppets), B14 (rejections + optimistic grab), B12 (hotspot IP), B18 (sanity checks, optional PIN), net test assertions, 4-process and host-leaves tests, latency injection.
**Gate:** net test asserts contested-grab loser gets a rejection, swap success, no MTU warnings in a 90-body pile, hotspot session passes on devices.

### M5 — Cover system (≈ 1–1.5 weeks) [independent of M3/M4; before M6 final art]
B3 (variation), B10 (global atlas + cache hygiene), B8 (hi-res placeholder/aim promotion).
**Gate:** per-genre variety metric, load-time and cache-size targets, visual diffs; override loader test retained.

### M6 — Environment redesign (≈ 3–4 weeks, level by level) [M2 numbers; M5 for final look]
B7 in this order: Warehouse → Store → Attic → Basement → Living/Den → Bedroom polish. C5 (split architecture, light budget), C6 (shelf presentation), interactive furniture (D5).
**Gate per level:** level suite + multi-seed sweep; empty-space/prop-density metric; navigation check; on-device frame time; screenshot review.

### M7 — Graphics, audio, character polish (≈ 1–2 weeks)
C3, C4, C10, lighting passes, effects polish, store/warehouse materials.
**Gate:** art/audio review on device; no regression in draw calls/primitives.

### M8 — UI/UX polish and accessibility (≈ 1 week)
B17 (sizes, focus, colour picker), C11 (guided tutorial), accessibility options, error toasts.
**Gate:** three-tester touch session; gamepad-only walkthrough of menus.

### M9 — Content and features (≈ 3–5 weeks, split further as needed) [M3 interactions stable]
D1–D10 in order of fit; each shipped as its own milestone with bot/test updates.

### M10 — Release preparation (≈ 1 week)
B16 (signing), E6, E7, final soak tests per preset, crash/log capture, store listing assets, update-install test, final README/changelog, relay decision (section 7.7).
**Gate:** 3 consecutive clean soak runs; update-install passes; zero open Critical/High.

**Dependencies in one line:** M1 → M2 → {M3, M4, M5 in parallel} → M6 → M7 → M8 → M9 → M10; B11 → relay; A1 → B5 → D1/D7; M5 → M6 (final look).

---

## 13. The 10 most important improvements

1. **Fix targeting priority and cart interaction** (A1, B5, B6): stops a soft-lock and unlocks the store's main mechanic.
2. **Close the world** (A2): window colliders plus out-of-bounds recovery.
3. **Make save/resume trustworthy** (A3, A4, B15): version header, held-items, autosave.
4. **Validate on real hardware** (M2): everything performance-related is currently inference.
5. **Cart physics** (A5): collide with walls; never drop a cart in the air.
6. **120 Hz input path** (B1): look in `_process`, interpolation, refresh-matched cap — fundamental to touch feel on the target device.
7. **Cover variety plus a global atlas** (B3, B10): restores the "identify the disc" payoff and fixes load time and storage creep.
8. **Level redesign, warehouse and store first** (B7): the most-played spaces currently read as props in boxes.
9. **Multiplayer feedback and bandwidth** (B14, B11, B13, B12): rejection feedback, snapshot budget, timer, hotspot IP.
10. **Deepen the loop and add the catch/pass verb** (B4, B19, D1–D3): variety and the funny co-op moments the game promises.

**Quick wins (each ≤ ½ day):** A3, A4, C1, C7, C9, B13, B15, B16, B12.

---

## 14. Honest assessment

Disc Chaos has a **strong skeleton**: the item/ownership model, the generator, the editions, the batching strategy and the test harness are the things most prototypes never get right, and they should be kept. What it does not yet have is **the experience layer on top**: interactions that never trap the player, covers and rooms that look different from each other, levels that feel like places, controls tuned for a 120 Hz touch phone, and any evidence from real devices.

Today it is a **polished-looking beta with five serious bugs, a design that gets repetitive around the one-hour mark, and unvalidated mobile performance**. None of the problems requires a rewrite; most of the critical ones are small fixes behind clear tests. Recommended order: **M1 (critical fixes) → M2 (device validation) → then decide the remaining scope from real measurements.** I would not call it release-ready until M1–M4 and the warehouse/store passes of M6 are done and verified on hardware; in my estimate that is about 60–65 % of the way to a polished release.

---

## Appendix A — Probe summary (reproducible descriptions)

* **P1 aim priority:** build the store state; assemble an open flip-case with its disc, an open collector's box with a piece, and put 4 cases in a cart; cast rays from above and from the side at each contained item; record the returned uid.
* **P2 world:** for each level, cast a ray from 0.6 m inside to 1.2 m outside every window at its centre height against the world layer; start `Player` inside the store facing the 2.6 m window and walk 6 s; push a cart into the west wall for 150 ticks; call `start_slip()` while pushing; write a version-1 save for level 1 and call `start_solo(1, true)`.
* **P3 piles:** stand at the densest free-item cluster for 4 s; record peak body speed, displacement, items below floor/outside map (free world-space items only).
* **P4 sweep:** run `suite_levels._test_level` for 40 seeds each on L1–L4 and 14 each on L5–L6 (including warehouse sizes).
* **P5 renders:** solve levels with the bot and screenshot shelves; render 24 covers of one genre with `Covers._render_page`.
* **P6 multiplayer:** host + C1 + late C2 on localhost; check remotes, positions, timer steps, puppets during a throw, held-item release on leave, logs for warnings.
* **P7 metrics:** floor area, props and types, shelf units, items/m², empty space on a 0.4 m grid.

## Appendix B — Where each claim comes from

Every **[V]** statement corresponds to a probe above or to the existing suites run during this audit. Every **[U]** statement is a hypothesis for the device test round, not a finding.
