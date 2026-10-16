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

## Done — Phase 2 (office)

- **Park's task queue** (`Tasks` autoload, templates in `data/tasks.json`,
  16 tasks). Tasks arrive faster through the day (-30% interval by 18:00)
  and each day (38 → 29 → 20 → 13 game-min base), deadlines shrink each
  day, max 6 on the list. Perfect pays 1.5x and relieves stress, ok pays,
  fail/expire add stress and Park yells. Park's lines queue so bubbles
  don't overwrite each other.
- **Six minigames** in a fake desktop-app window, keyboard only, clock
  keeps running: Wurd (retype his sentence; stress makes fingers slip),
  Excelsior (napkin numbers, sum by hand), COPYMASTER (needle timing),
  도장 stamping conveyor with decoys, Park's coffee (memorise, rebuild),
  bowing to Director Choi (hold in the band, too deep is sarcastic).
- **Sticky-note HUD** column: what / where / due / pay, red and shaking when
  due soon, stamped DONE / FAILED / LATE / ABANDONED.
- **Stations** in the office: desk PC, copier, stamp table, pantry, meeting
  room (Choi appears when a bow task is pending).
- **Park walks**: catches long smoke breaks on the balcony (+task, +stress),
  goes home at a random time 19:00–21:30 (rarely 18:05).
- **Nunchi**: leaving after 18:00 while Park is in costs stress and an extra
  personal task next morning. Walking out with open tasks abandons them.

## Next

1. **Balance by hand.** The ramp numbers are from arithmetic, not play.
   Target: day 1 busy but fair, day 2 overwhelming, day 3+ chaos.
2. **Phase 3 — commute.** Random train delays with silly announcements, a
   short ride segment, convenience-store gifts for Hana, taxi cutscene.
3. **Phase 4 — home + endings.** Day summary screen, meltdown cutscene
   variety (benign destruction + rare legendary ones), Hana-leaves cutscene.
4. **Phase 5 — look & feel.** Sound (task cues reuse the old placeholder WAVs),
   facial expressions, more NPCs in the office and on the street, a chunkier
   UI font (e.g. Jua, OFL) shipped with the game.
5. **Phase 6 — home progression** (undecided).

## Known gaps

- Only playtested via the scripted screenshot tour, not by hand.
- On Day 1 the elevator stays locked until 18:00 (12 real minutes). Use F5 in
  debug builds to skip ahead.
- Money has nothing to spend it on yet except the taxi (shop is Phase 3).
