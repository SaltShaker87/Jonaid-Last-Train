extends Node
class_name Director
## 40-second capture: a day going wrong in the right order (GDD §18 step 5).
## Run with rendering (not headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -- --capture
## Saves capture/shot_*.png every 2s + capture/storyboard.md.
## Headless dry-run prints the shot list without rendering.

var game: Node
var t := 0.0
var running := false
var _shot_i := 0
var _shot_t := 0.0
var _steps: Array = []
var _done := false

static func maybe_attach(to_game: Node) -> Director:
	var args := OS.get_cmdline_user_args()
	var all_args := OS.get_cmdline_args()
	if "--capture" in args or "--capture" in all_args:
		var d := Director.new()
		d.name = "Director"
		d.game = to_game
		to_game.add_child(d)
		d._build_steps()
		d.running = true
		return d
	return null

func _build_steps() -> void:
	# (time, label, callable-name)
	_steps = [
		[0.0, "08:50 office — tube on desk, folder unpinned", "_beat_office"],
		[5.0, "Yoon refuses — lightbox sloppy, 45min billed", "_beat_lightbox"],
		[11.0, "Shuttle curb 18:10 — badge out with tube", "_beat_shuttle"],
		[16.0, "Turnstile + crowd + platform stumble", "_beat_station"],
		[23.0, "Home — slip signed, bedtime, tank prime", "_beat_home"],
		[30.0, "Couch buzz 02:00 — Jun hears the filter", "_beat_couch"],
		[35.0, "Morning — Sora sniped, slides sloppy, PIP reads file", "_beat_morning"],
	]
	for s in _steps:
		s.append(false)  # fired flag

func _process(delta: float) -> void:
	if not running or _done:
		return
	t += delta
	_shot_t += delta
	if _shot_t >= 2.0:
		_shot_t = 0.0
		_save_shot()
	for s in _steps:
		if not bool(s[3]) and t >= float(s[0]):
			s[3] = true
			call(String(s[2]))
	if t >= 40.0:
		_done = true
		_save_shot()
		_write_storyboard()
		var h = game.get("hud") if game != null else null
		if h != null and h.has_method("show_toast"):
			(h as HUD).show_toast("Capture done — see capture/shot_*.png + storyboard.generated.md")
		print("[Director] capture done.")

func _save_shot() -> void:
	# Requires rendering; headless skips gracefully.
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	await RenderingServer.frame_post_draw
	var img := tex.get_image()
	if img == null or img.is_empty():
		print("[Director] empty frame, skipping shot %d" % _shot_i)
		return
	var dir := "res://capture"
	var abs_dir := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var path := "%s/shot_%02d.png" % [dir, _shot_i]
	var err := img.save_png(path)
	print("[Director] shot %d -> %s (%s)" % [_shot_i, path, "ok" if err == OK else "err %s" % err])
	_shot_i += 1

func _write_storyboard() -> void:
	# Generated beats go to their own file. capture/storyboard.md is the
	# hand-written palette/audio checklist — the director never clobbers it.
	var lines: Array = ["# 40s capture (generated) — a day going wrong in the right order", ""]
	for s in _steps:
		lines.append("- %4.1fs %s — %s" % [float(s[0]), s[1], "shot_%02d.png" % int(float(s[0]) / 2.0)])
	lines.append("")
	lines.append("Beats: tube→Yoon refuse→sloppy trace (45min)→shuttle curb→crowd→stumble→slip→prime→couch buzz→snipe→PIP.")
	var path := "res://capture/storyboard.generated.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		print("[Director] storyboard -> %s" % path)

# --- beats (performed, sloppy on purpose) ---

func _beat_office() -> void:
	game.call("load_room", "office")
	GameState.toast.emit("08:50 Tube. Pin the folder — Park sees it.")
	StressSys.add(6.0)

func _beat_lightbox() -> void:
	game.call("load_room", "street")
	GameState.toast.emit("Yoon refuses the stamp. Lightbox: hands disagree (sloppy).")
	DayClock.bill_skill("sloppy")
	StressSys.add(10.0)
	game.call("play_audio", "jam")

func _beat_shuttle() -> void:
	DayClock.minutes = 18 * 60 + 2
	game.call("load_room", "street", "curb")
	GameState.toast.emit("18:02 curb — tube under arm, Jun collected, receipt goes cold.")
	GameState.add_kids(10.0)
	game.call("play_audio", "ping")

func _beat_station() -> void:
	game.call("load_room", "station")
	DayClock.minutes = 19 * 60 + 31
	GameState.toast.emit("19:31 platform — crowd shoves, stumble costs the door.")
	StressSys.add(14.0)
	game.call("play_audio", "turnstile")

func _beat_home() -> void:
	game.call("load_room", "apartment")
	GameState.promises["slip_signed"] = true
	GameState.add_hana(8.0)
	GameState.toast.emit("Slip signed. Cabinet open — filter ₩90,000, Friday hasn't paid. No beer.")
	game.call("play_audio", "chime")

func _beat_couch() -> void:
	GameState.toast.emit("Couch anime + buzzing filter. Jun hears it at 02:00 — Body suffers.")
	GameState.add_body(-8.0)
	game.call("play_audio", "buzz")

func _beat_morning() -> void:
	GameState.sora_sniped = true
	GameState.add_pip(15.0)
	GameState.toast.emit("Sora's number survived. PIP reads the file at 18:00, not your face.")
	game.call("play_audio", "announce")
