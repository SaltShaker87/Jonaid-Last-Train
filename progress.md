# Progress

The game was rebuilt from scratch on 2026-10-15 to match DESIGN.md. The old
version (Face/Kids/PIP meters, 60-day run, floating 3D labels everywhere)
lives at git tag `legacy-v0.3`.

## Done — Phase 0 + 1 (foundation)

- **DESIGN.md** written from the owner's answers: no win state, score = days
  survived, 12-minute office day, ~2-minute commute, frozen time at home,
  stress 100 = meltdown, Hana's anger in 3 tiers with full = game over.
- **Cast as rigged cartoon models** (Blender, scripted): Jonaid, Park, Sora,
  Hana, Choi. Big heads, googly eyes, chunky suits. Shared skeleton with
  Idle, Walk, Run, Bow, Talk, Angry, Smoke, Type, Sit, SitType, Freakout.
- **Locations** (Blender, scripted, collision baked in): office 14F with
  Park's glass office, meeting room, desk clusters, copier corner, pantry and
  balcony with skyline; one-block street at dusk with shops, pojangmacha,
  cars and the subway entrance; Mullae station with gates, screen doors and a
  train; the apartment (living room, kitchen with rice cooker, bedroom).
- **Cartoon look in Godot**: toon diffuse/specular, rim light on characters,
  inverted-hull outlines (smoothed normals baked into vertex colour so boxes
  don't crack), sun shadows through non-shadow-casting ceilings.
- **Player**: third-person controller, over-the-shoulder spring-arm camera
  that collides with walls and ceilings, walk/run blending, E to interact.
- **Loop playable end to end**: title → day card → office (Park grumbles,
  smoke break drains stress, coffee/snack/copier/inbox jokes, elevator locked
  before 18:00) → street → station (live timetable board, trains arrive on
  schedule and leave without you, bench fast-forward, taxi after the last
  train) → home (Hana greets you by lateness tier, anger meter) → bed → next
  day. Meltdown and Hana-leaves both end the run on a game-over screen with
  stats and a saved best score.
- **UI**: no 3D floating labels. Speech bubbles follow speakers' heads; HUD
  with clock, drawn stress face, money, Hana meter; notifications; location
  banners; pause menu.

## Next

1. **Phase 2 — office tasks.** Park's task queue (sticky notes with timers),
   the first WarioWare minigames (Word typing, Excel, copier jam, stamp, coffee
   order, bow), money per task, stress on failure/expiry, nunchi when leaving
   before Park, Park catching you smoking.
2. **Phase 3 — commute.** Random train delays with silly announcements, a
   short ride segment, convenience-store gifts for Hana, taxi cutscene.
3. **Phase 4 — home + endings.** Day summary screen, meltdown cutscene
   variety (benign destruction + rare legendary ones), Hana-leaves cutscene.
4. **Phase 5 — look & feel.** Sound (the old WAVs in assets/audio are unused),
   facial expressions, more NPCs in the office and on the street, a chunkier
   UI font (e.g. Jua, OFL) shipped with the game.
5. **Phase 6 — home progression** (undecided).

## Known gaps

- Only playtested via the scripted screenshot tour, not by hand.
- On Day 1 the elevator stays locked until 18:00 (12 real minutes). Use F5 in
  debug builds to skip ahead.
- There's nothing to earn money with yet (that's Phase 2), so the taxi takes
  whatever you have.
