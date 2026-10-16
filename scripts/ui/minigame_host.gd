class_name MinigameHost
extends CanvasLayer
## Shows the minigame for a task on top of the world and reports the grade
## back to Tasks. Jonaid can't move while it's up; the clock keeps running.

signal opened
signal closed

var current: Minigame
var _task: Dictionary = {}


func _ready() -> void:
	layer = 25
	Tasks.play_requested.connect(open)


func is_open() -> bool:
	return current != null


func open(task: Dictionary) -> void:
	if current != null:
		return
	var game := _make(String(task.get("game", "")))
	if game == null:
		Tasks.complete(task, "ok")
		return
	_task = task
	current = game
	add_child(current)
	current.setup(task, Tasks.difficulty())
	current.finished.connect(_on_finished)
	opened.emit()


func _make(game: String) -> Minigame:
	match game:
		"word": return WordGame.new()
		"excel": return ExcelGame.new()
		"copier": return CopierGame.new()
		"stamp": return StampGame.new()
		"coffee": return CoffeeGame.new()
		"bow": return BowGame.new()
	return null


func _on_finished(grade: String) -> void:
	var t := _task
	_close()
	Tasks.complete(t, grade)


## Close without grading (meltdown, run over). The task stays on the list.
func abort() -> void:
	if current == null:
		return
	Tasks.playing = {}
	_close()


func _close() -> void:
	if current != null:
		current.queue_free()
		current = null
	_task = {}
	closed.emit()
