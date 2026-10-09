# Progress — Jonaid: Last Train

## Done
- **End-to-end game (GDD v0.2):** Godot 4.7 project boots from title → Tuesday 08:50 day loop → endings. DayClock (1s = 20 game-sec, skills freeze + bill 20/45/30), StressSys bands, GameState meters (Hana/Kids/Face/Body/Money + hidden PIP/Jealousy), Interactable weights (white/gold/oxblood), third-person Salaryman with carry/crowd/sprint rules.
- **World + skills:** office 14F / street-Mullae / station / apartment / hoesik rooms behind masked loads; 5 skill kits (trace, hold, digits, slides, kakao + dash overlay); jobs JSON (`catalog.json`, `tuesday.json`); hard clocks (shuttle 18:10, family 19:40, last 23:18), taxi-after-doors, morning invoice, day-60 endings.
- **Art pass:** palette locked (`art_direction.gd`), fluorescent office / tungsten home / platform glow, bilingual signage, readable DO NOT COPY plate, dressed Jonaid (oversized suit + 5 stress faces) and NPC bust language, Blender re-export of 8 GLB hero props/heads/busts, remixed 6 audio beds with mix levels + crossfading beds.
- **Capture rig:** `-- --capture` director plays a 40s day-going-wrong + saves `capture/shot_*.png`; `capture/storyboard.md` documents the beats.
- **Repo:** public GitHub `SaltShaker87/Jonaid-Last-Train`, initial commit `7da08eb`, `main` tracks `origin/main`. Verified headless import + auto-test clean.

## Next steps
1. **Run the capture with a display** (`Godot --path . -- --capture`), review shots, fix unreadable-at-couch-distance issues.
2. **Playtest Tuesday end-to-end** (tube → trace → shuttle → train → home → morning); tune clock scale, crowd slow, skill windows, billed minutes.
3. **Content:** author weeks 2–12 overlaps (Sora snipe, nanny, hoesik-vs-recital, fish-during-lightbox, gym Saturday).
4. **Dress + voice:** composed beds/chime/announcement mix, VFX (stamp glow, door close), Korean VO/texture pass.
5. **Tech:** optional GDAI-MCP install, export presets (Mac/Win), save/continue, crash/bug pass.
6. **Keep this file updated** after each session: move finished items to Done, re-list Next.
