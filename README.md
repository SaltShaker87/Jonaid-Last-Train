# JONAID: LAST TRAIN v0.3 — Korean salaryman simulator

3D world, performed tasks, stress that gets into your hands.
Godot 4 3D · Blender · data-driven content pipe.

> No MCP servers were detected in opencode config on this machine, so the
> pipe runs via direct CLI (`Godot --headless`, `Blender --background --python`),
> which exposes the same capability. If you add Godot-MCP / Blender-MCP servers
> to `opencode.jsonc`, point them at `tools/place_manifest.json` + `blender/export_props.py`.

## Run

- Open `project.godot` in Godot 4.7 (Godot.app on this machine).
- Press Play. Title → **Start Tuesday 08:50** (or **Continue — last morning**, autosaved each morning).
- WASD walk · mouse look · E interact · Q phone · F drop · Shift sprint (low stress + high body) · **Esc pause**.
- White=errand · Gold=manual · Oxblood=heavy.

Headless gate (content + engine asserts, exits nonzero on failure):

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 --auto-test
```

Scripted multi-day playtest (`--sim`) plays the real game like a person —
every live job per room, scripted skill grades, night trains, mornings.
Three runs per launch, each reporting per-meter min/max/avg plus a tally of
jobs fired vs skipped, so balance findings are measured rather than eyeballed:

1. **clean** — grades lean clean/sloppy; must survive 25 days.
2. **greed** — every task signed perfectly for 60 days; asserts the balance
   stays solvent and Face is damped rather than pinned.
3. **chaos** — skills mostly fail; the run must reach a legal loss through
   the real game-over signal.

Exits nonzero on any failed assertion (~90s wall time):

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --sim
```

40s capture (needs a display; shots are gitignored, storyboard goes to `capture/storyboard.generated.md` — the hand-written `capture/storyboard.md` is never clobbered):

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --capture
```

## Content pipeline — jobs are data, not code

Every interactable resolves through `scripts/core/job_board.gd` and a declarative effect
list interpreted by `scripts/core/effects.gd`:

- `data/jobs/catalog.json` — the catalog. Each job: `id/weight/scene/skill/once`,
  date gating (`days` ANDed with `day_min`/`day_max`, `weekdays`, `requires`), and effects.
- `data/jobs/days/*.json` — day defs (briefing + script lines) keyed by exact day,
  else weekday with `from_day`. This is how weeks 2–12 exist without 60 files.
- Effects vocabulary (one interpreter, ~13 verbs): `meter money flag promise carry
  toast audio minutes travel engine ending vfx`. `engine` verbs are the few genuinely
  procedural hooks that live in `scripts/world/main.gd` (`resolve_shuttle`,
  `resolve_dash`, `resolve_hoesik`, `resolve_shop`, `sleep_bed`, `sora_snipe`, …).
  `vfx` fires world effects (`stamp_thump`, `doors_shut`) so content can hit props.
- Gating runs in `load_room()`: interactables whose job is off today are hidden and
  disabled. `weight` in the catalog is authoritative — it overrides the room default
  so the two can never drift. `once: "day" | "week" | "game"` consume jobs per day,
  per calendar week (cleared on the Sunday→Monday rollover), or per run. An
  unrecognised `once` value toasts rather than silently behaving as unlimited.
- A whole effect list is validated before any of it runs, so a typo in the last
  effect cannot leave the first three applied.
- `money` with a negative `delta` routes through the guarded spend: the list aborts
  on poverty instead of driving the balance negative.
- A new joke is a JSON entry, not a match statement.

## Blender pipe

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/export_props.py
```

Outputs `assets/models/*.glb` with `SOCKET_*` empties. Rooms register matching sockets
(`copier`, `sedan`, `tank`, `couch`) so `RoomBuilder.try_swap_blender_model()` lands the
model at the prop position. `tools/place_manifest.json` is the Godot-MCP placement manifest.

## Structure

- `scripts/autoload/` DayClock (1s=20 game-sec, freeze + bill 20/45/30), StressSys (bands), GameState (6+2 meters, endings, save export/import)
- `scripts/core/` Interactable, Salaryman, RoomBase, NPC, **Effects (interpreter)**, **JobBoard (catalog/day loader + gating)**, **SaveIO (autosave)**
- `scripts/world/` Main (day loop, travel, engine verbs, save calls), RoomBuilder + rooms office/street/station/apartment/restaurant, art_direction, Director, **vfx (stamp glow, door slide, motes)**
- `scripts/skills/` 5 kits: trace (lightbox), hold (bow/crop/prime/pour), digits (G90/sign), slides, kakao + dash overlay
- `scripts/ui/` HUD, Phone, MainMenu (+ Continue), EndingScreen, PauseMenu (Esc, tree.paused)
- `scripts/tests/` TestRig (101 headless asserts, `--auto-test`) + Playthrough (`--sim`, three scripted multi-day profiles)
- `data/jobs/` catalog.json + days/*.json; `data/jobs/days/` covers Tue→Mon so weeks 2–12 loop

## Save / continue

One slot at `user://save.cfg`, written every morning in `advance_morning()` (day, weekday,
clock, meters, flags, used-jobs). "Start Tuesday" clears it. Content is data, so saves
store meters — not the authored world.

## Locked calls (GDD §21)

Third person except lightbox/slides first-person. World clock runs walking/typing.
Skills freeze + bill. Returnee reads the stamp. One office loss, one apartment loss.
English UI + Korean texture.

## Production order

1. Floor+clock ✅ 2. Three skills ✅ 3. Home invoice ✅
4. The knife ✅ 5. Dress+voice ✅
6. Content is data ✅ (v0.3 — pipeline + weeks 2–12 + tests + save)
