# Jonaid: Last Train — Design

This file is the source of truth for what the game is. If code and this file
disagree, this file wins (or gets updated on purpose). Keep it short and current.

## Pitch

A silly, over-the-top, cartoony third-person office survival game. You are
**Jonaid**, a Korean salaryman at Hansung Electronics. Your boss buries you in
stupid tasks, your stress climbs, the last train leaves without you, and your
wife Hana is waiting at home with a clock in her head.

There is **no winning**. A run is "how many days can Jonaid last?" — a score
game. A run should take **20–60 minutes** depending on skill.

## Tone

- Cartoony, loud, physical comedy. Chunky low-poly characters with big heads
  and big hands, exaggerated animation, saturated colors.
- The humor is the absurdity of office life: the boss asks for really stupid
  things, and you have to do them anyway.
- Adult-ish humor is fine (swearing in bubbles, smoking, drinking, office
  rage). **Nobody dies**: no shootings, no suicide, no weapons. Meltdowns are
  property damage and public humiliation.
- English text with Korean flavor: honorifics (부장님), Korean signage,
  Korean food and brands made fictional.

## Cast

| Character | Role |
|---|---|
| **Jonaid** | You. Oversized suit, tired eyes. |
| **Park 부장** | Your boss. Lives in a glass office. Hands out tasks. Never goes home. |
| **Choi 이사** | The director. Rare visits. Everyone must bow. |
| **Sora** | Coworker. Competent, smug, steals credit. |
| **Taeyang** | Coworker who is never at his desk. Running gag. |
| **Yoon** | Clerk at the copy shop on the street. Refuses everything. |
| **Hana** | Your wife. Greets you at the door. Has a temper meter. |
| **Jun, Harin** | Your kids. Flavor at home. |

## The loop (one day)

1. **Morning card** — "Day N". Jonaid arrives at the office at 09:00.
2. **Office (09:00 → 18:00, ~12 real minutes)** — Park assigns tasks. Do
   them, take smoke breaks, don't melt down.
3. **Overtime** — 18:00 is the official end, but Park is still at his desk.
   Leaving before the boss has a cost (see *Nunchi*). Park leaves at a
   random time each day.
4. **Hana texts** sometime in the afternoon: "Home by 19:30."
5. **Commute (~2 real minutes)** — elevator down, walk one block, subway.
6. **Home (time is frozen)** — Hana greets you, mood depends on how late you
   are. Free roam the apartment. Sleep → next day.

### Clock

| Area | Speed |
|---|---|
| Office (incl. balcony) | 0.75 game-min per real second (09:00→18:00 = 12 min) |
| Street / station / train | 0.5 game-min per real second |
| Home | frozen |
| Minigames | clock keeps running (that's the pressure) |

All of these are tuning knobs in one place (`scripts/autoload/clock.gd`).

## Office

### Tasks

- Park (and sometimes Sora/Choi) assigns tasks. Each one appears as a sticky
  note in the task list: what, where, deadline, pay.
- You walk to the location (your PC, copier, Park's office, coffee machine,
  stamp table, meeting room…) and press **E** to play a **WarioWare-style
  minigame** of 5–20 seconds.
- **Success** pays ₩ (more for a perfect). **Failure** or **missing the
  deadline** adds stress and Park yells.
- Tasks arrive faster through the day and faster each day. Being overwhelmed
  is the point.
- Some minigames are **deliberately boring but funny**: typing short, stupid
  things into a Word doc or Excel sheet because the boss said so.

Minigame ideas (the list will grow; each is a small scene with a shared
`start()` / `finished(grade)` contract):

- **Word:** retype Park's email but in a bigger font; replace every "Dear" with
  "Most Esteemed"; write his daughter's birthday card; apology letter to the
  printer.
- **Excel:** enter five numbers; color the cells Park's favorite yellow; sum a
  column by hand because "the formula is suspicious"; make the chart "a
  slightly different blue".
- **Copier jam:** mash and yank the paper out at the right moment.
- **Stamp (도장):** stamp 15 documents in rhythm. Don't stamp the lunch menu.
- **Coffee run:** remember Park's insane order, then build it.
- **Bow to Director Choi:** hold the bow at the perfect angle for the right
  time.
- **Laugh at Park's joke:** hit the laugh at the punchline. Not too early.
- **Shredder:** feed the evidence before the auditors walk in.
- **Fix Park's PC:** it's not plugged in.

Stress makes minigames harder (shaky cursor, typos creep in, tighter
windows).

### Balcony smoke break

- A door off the office leads to a small balcony with a city view.
- Smoking drains stress over time while the clock (and task deadlines) keep
  running.
- Park sometimes comes out and catches you: "Smoking again? Here's another
  task."

### Nunchi (leaving before the boss)

- After 18:00 you may leave. If Park is still at his desk, leaving costs
  stress and he starts tomorrow with an extra task for you.
- Some days Park leaves early (rare joy). Some days he announces a team dinner
  (회식) — later feature.

## Commute

- Elevator → **street (one block)** → **station** → **train** → home.
- The street has a convenience store (gifts for Hana, cigarettes) and maybe a
  coworker trying to drag you to drinks.
- **Timetable** (sparse on purpose, so missing one hurts):
  18:30 · 19:15 · 20:00 · 21:00 · 22:15 · **23:10 last**.
- The station board shows a live countdown. A bench lets you skip ahead to
  the next train (time passes).
- **Random delays** of 15–30 real seconds, with a silly announcement ("a man
  is arguing with the doors", "a pigeon has boarded the driver's cab").
- **Missed the last train → taxi.** Short cutscene, costs money, straight
  home (late).

## Home

- No time passes at home. No rush.
- **Hana greets you at the door.** Your arrival time against the time she
  asked for picks her mood:

| Arrival | Mood | Anger |
|---|---|---|
| On time or early | Happy | −10 |
| 1–30 min late | **Annoyed** (tier 1) | +15 |
| 31–90 min late | **Angry** (tier 2) | +30 |
| 90+ min late, or taxi | **Furious** (tier 3) | +45 |

- Anger persists across days. **Full anger = game over** (she leaves, takes
  the kids and the rice cooker).
- Gifts from the convenience store soften the hit.
- Home is where **progression** will live (not decided yet). Candidates:
  apartment upgrades with perks (a good bed means less stress in the
  morning), bills that eat money (rent, kids' hagwon), evening activities with
  Hana and the kids that lower anger.
- Sleep → next day. Stress carries over partially (halved overnight).

## Losing

- **Stress hits 100 → meltdown cutscene.** Picked at random from a pool.
  Common: smash the printer, sweep everything off Sora's desk, flip your desk,
  scream into the copier, eat all of Park's snacks. Rare "legendary": hijack
  the PA system and read Park's browser history aloud, throw the monitor out
  the window and leave in your underwear, ride an office chair through Park's
  glass wall.
- **Hana's anger hits 100 → she leaves.** Cutscene: door code changed, a note,
  the rice cooker is gone.

## Score

- Primary: **days survived**. Tie-break: total money earned.
- Game-over screen: days, money earned, tasks done/failed, cigarettes
  smoked, trains missed, cause of death (of career).
- Local high score.

### Difficulty target

With a 12-minute office day, a run of 20–60 minutes is roughly **2–4 days**.
Day 1 is busy but fair, day 2 is overwhelming, day 3+ is chaos. If runs
should be longer, shorten the office day before softening the ramp.

## Presentation

- **Camera:** third person, over the shoulder, pulled back and offset so
  Jonaid isn't in the middle of the screen. Mouse orbit, wall collision.
- **No floating 3D text labels.** Information lives in 2D UI: task list,
  speech bubbles, phone. World signs are part of the geometry and only where
  a real sign would be.
- **HUD:** clock + day (top left), stress (a face icon that gets more frazzled
  + bar), money, Hana's anger (only shown after the first evening), task
  sticky notes, interaction prompt "E — Unjam copier".
- **Art:** low-poly cartoon models built in Blender (`blender/`), exported as
  GLB. Toon shading with outlines in Godot. Squash-and-stretch animation.

## Tech

- Godot 4.7, GL Compatibility renderer, GDScript.
- Every location is a real `.tscn` you can open in the editor:
  `scenes/locations/{office,street,station,train,home}.tscn`.
- Models: `blender/*.py` → `assets/models/*.glb`. Objects named `*-col` in
  Blender get collision on import.
- Autoloads: `Clock` (time), `Stress`, `Game` (money, anger, day, score, save).
- Tasks: templates in `data/tasks.json` (what, where, deadline, pay, which
  minigame); the `Tasks` autoload runs Park's queue.
- Minigames: `scripts/minigames/*.gd`, all extend `Minigame`
  (`setup(task, difficulty)` → `finished(grade)`), grades `perfect / ok / fail`.

## Roadmap

0. ✅ This document.
1. ✅ **Foundation** — scenes, animated Jonaid, camera, transitions, minimal HUD.
2. ✅ **Office** — task queue, first minigames, money, stress, balcony, meltdown.
3. **Commute** — street, station timetable, delays, train ride, taxi.
4. **Home** — Hana greeting, anger tiers, day summary, next day, game over.
5. **Look & feel** — toon shader polish, more animation, sound, writing.
6. **Home progression** — once decided.

The pre-rebuild game is preserved at git tag `legacy-v0.3`.
