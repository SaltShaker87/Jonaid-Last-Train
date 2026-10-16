# Jonaid: Last Train

A silly, over-the-top, cartoony salaryman survival game. You are Jonaid, a
Korean office worker. Survive the boss, catch the last train, keep Hana from
leaving you. Nobody wins; the score is how many days you last.

**What the game is: [DESIGN.md](DESIGN.md).** Where it's at: [progress.md](progress.md).

Godot 4.7 (GL Compatibility) · Blender 5.2 for models.
The pre-rebuild version is preserved at git tag `legacy-v0.3`.

## Play

Open `project.godot` in Godot 4.7 and press Play.

WASD move · mouse look · Shift run · E use · Esc pause

Debug builds only: F5 = +60 game minutes, F6/F7 = stress up/down,
F8 = Hana's anger up.

## Layout

```
DESIGN.md                 what the game should be (source of truth)
blender/                  Python scripts that build every model
  lib.py                  shared helpers (materials, shapes, outline normals, export)
  build_characters.py     the cast: rig + hand-keyed animations
  build_world.py          office, street, station, train, home
assets/models/*.glb       exported models (rebuild with the scripts below)
scenes/main.tscn          Main: World + Player
scenes/characters/        player.tscn + one scene per cast member
scenes/locations/         office, street, station, home (edit these in Godot)
scripts/autoload/         Clock, Stress, Game (money, anger, score, message bus)
scripts/main.gd           day loop, travel between locations, UI layers
scripts/player/           Jonaid's controller + camera
scripts/world/            Location, Interactable, Door, Quip, NPC, ToonKit, station/home/office logic
scripts/ui/               HUD (clock, stress face, bubbles), title, pause, game over
shaders/outline.gdshader  cartoon outline pass
```

Locations are normal `.tscn` scenes. Spawn points are `Marker3D`s under
`Spawns` (their -Z is the facing direction). Anything you can press E on is an
`Area3D` with an `Interactable` script (`Door`, `Quip`, `SmokeSpot`, …);
`Quip` takes a list of lines in the inspector, so small jokes need no code.

## Rebuilding models

```bash
blender --background --factory-startup --python blender/build_characters.py
```

```bash
blender --background --factory-startup --python blender/build_world.py
```

Both accept `-- --only name1,name2` and `-- --preview DIR` (Workbench renders
for a quick look). Layout numbers in `build_world.py` are in Godot
coordinates, so they match the positions used in the scenes. After a rebuild,
let the Godot editor reimport (or run `godot --headless --path . --import`).

## Screenshot tour

```bash
godot --path . -- --shots=/some/folder
```

Plays a scripted tour (title, office, balcony, street, station, train, home,
meltdown, game over), saves a PNG at each stop and quits.
