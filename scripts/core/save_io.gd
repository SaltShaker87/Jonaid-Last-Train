class_name SaveIO
## Autosave at morning arrival (GDD tech pass). One slot, overwritten each
## morning. Content is data, so the save stores meters/flags/clock only.

const PATH := "user://save.cfg"

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

static func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(PATH)

static func autosave(game: Node) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("clock", "day", DayClock.day)
	cfg.set_value("clock", "weekday", DayClock.weekday)
	cfg.set_value("clock", "minutes", DayClock.minutes)
	var state := GameState.export_state()
	for k in state.keys():
		cfg.set_value("state", k, state[k])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("[SaveIO] autosave failed: %s" % err)

static func load() -> Dictionary:
	if not has_save():
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	var state := {}
	for k in cfg.get_section_keys("state"):
		state[k] = cfg.get_value("state", k)
	return {
		"day": cfg.get_value("clock", "day", 1),
		"weekday": cfg.get_value("clock", "weekday", 1),
		"minutes": cfg.get_value("clock", "minutes", 8 * 60 + 50),
		"state": state,
	}
