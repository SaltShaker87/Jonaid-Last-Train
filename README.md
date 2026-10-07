# JONAID: LAST TRAIN v0.2 — Korean salaryman simulator

3D world, performed tasks, stress that gets into your hands.
Godot 4 3D · Blender · MCP asset and placement pipe.

> No MCP servers were detected in opencode config on this machine, so the
> pipe runs via direct CLI (`Godot --headless`, `Blender --background --python`),
> which exposes the same capability. If you add Godot-MCP / Blender-MCP servers
> to `opencode.jsonc`, point them at `tools/place_manifest.json` + `blender/export_props.py`.

## Run

- Open `project.godot` in Godot 4.7 (Godot.app on this machine).
- Press Play. Title → **Start Tuesday 08:50**.
- WASD walk · mouse look · E interact · Q phone · F drop · Shift sprint (low stress + high body).
- White=errand · Gold=manual · Oxblood=heavy.

Headless smoke:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5 --auto-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script res://scripts/world/main.gd
```

## Blender pipe

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/export_props.py
```

Outputs `assets/models/*.glb` with `SOCKET_*` empties. `RoomBuilder.try_swap_blender_model()`
loads them if present, graybox otherwise. `tools/place_manifest.json` is the
Godot-MCP placement manifest.

## Structure

- `scripts/autoload/` DayClock (1s=20 game-sec, freeze + bill 20/45/30), StressSys (bands), GameState (6+2 meters, wins/losses)
- `scripts/core/` Interactable (weight+prompt color), Salaryman (3rd-person carry/crowd), RoomBase, NPC, JobBoard
- `scripts/world/` Main (day loop, travel, hard clocks, taxi, mornings, endings), RoomBuilder + rooms office/street/station/apartment/restaurant
- `scripts/skills/` 5 kits: trace (lightbox), hold (bow/crop/prime/pour), digits (G90/sign), slides (vendor pack), kakao + dash overlay
- `scripts/ui/` HUD (clock/stress/departures), Phone (no pause), MainMenu, EndingScreen
- `data/jobs/` catalog.json (client/weight/scene/skill/clock/comply-defect) + tuesday.json sample Tuesday
- `scenes/main.tscn` boots Main; rooms are built at runtime (graybox + glTF swap)

## Locked calls (GDD §21)

Third person except lightbox/slides first-person. World clock runs walking/typing.
Skills freeze + bill. Returnee reads the stamp. One office loss, one apartment loss.
English UI + Korean texture.

## Production order

1. Floor+clock ✅ (office/street/station/apartment, badge-out, doors shut)
2. Three skills ✅ (trace/bow/dash + stress bands, Tuesday tube→couch)
3. Home invoice ✅ (cabinets, fish prime, beer, taxi, Hana routes)
4. The knife ✅ (slides/Sora/PIP/nanny/G90/hoesik/endings)
5. Dress+voice ✅ (this pass — see below)

## Art pass (v0.2 §16)

- Palette locked: `scripts/world/art_direction.gd` (espresso/gold/ivory/oxblood/subway).
- Godot lights rooms: fluorescent office / tungsten home / subway platform edge glow; beds crossfade on travel.
- Cast dressed: Jonaid oversized suit + shirt/tie/gold pin + 5 stress faces (brows+tint); Park/Choi/Sora/Hana bust language + KR nameplates.
- Bilingual signage (EN + KR) + `DO NOT COPY` ivory-plate stamp readable at couch distance.
- Blender re-export: beveled hero props + `heads.glb` (5) + `busts.glb` (4) — `tools/place_manifest.json` v2.
- Audio mix: announce 0dB > chime -4 > turnstile/jam -8 > ping -10 > buzz -14; beds duck on travel.
- 40s capture: `Godot --path . -- --capture` (needs display) → `capture/shot_*.png` + `capture/storyboard.md`.

> Found your GDAI MCP (`~/Downloads/addons/gdai-mcp-plugin-godot`, v0.3.2 + `~/Documents/Empiric/addons/...`).
> Left uninstalled on purpose — GDExtension native lib is risk without need; CLI pipe covers it.
> Say the word and I'll drop it into `addons/` + wire `tools/place_manifest.json` to it.
