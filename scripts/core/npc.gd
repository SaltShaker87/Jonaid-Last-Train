extends CharacterBody3D
class_name OfficeNPC
## Cast paths, waits, leaves (GDD §6). Park will not stand at your desk forever.
## Dressed: four boss busts + Hana/Sora reads at couch distance. No real names/badges.

@export var npc_name: String = "Sora"
@export var dwell_time: float = 60.0  # game-minutes they wait before leaving

var _t := 0.0
var _leaving := false
var _home := Vector3.ZERO
var _label: Label3D

const KR := {"Park": "박 부장", "Choi": "최 이사", "Sora": "소라", "Hana": "하나", "Yoon": "윤 계장", "Jun": "준", "Harin": "하린"}

func setup(p_name: String, pos: Vector3, color: Color) -> void:
	npc_name = p_name
	position = pos
	_home = pos
	_build(color)

func _cast_colors() -> Dictionary:
	# Silhouette language: Park square + dark, Choi tall + oxblood tie, Sora warm, Hana soft.
	match npc_name:
		"Park":
			return {"suit": Color(0.16, 0.16, 0.18), "trim": Color(0.85, 0.66, 0.25), "hair": Color(0.05, 0.05, 0.05), "shoulder": 0.9}
		"Choi":
			return {"suit": Color(0.20, 0.18, 0.20), "trim": Color(0.45, 0.08, 0.10), "hair": Color(0.12, 0.10, 0.10), "shoulder": 0.82}
		"Hana":
			return {"suit": Color(0.55, 0.42, 0.36), "trim": Color(0.91, 0.87, 0.77), "hair": Color(0.15, 0.10, 0.08), "shoulder": 0.62}
		"Sora":
			return {"suit": Color(0.65, 0.42, 0.32), "trim": Color(0.91, 0.87, 0.77), "hair": Color(0.25, 0.15, 0.10), "shoulder": 0.60}
		_:
			return {"suit": Color(0.35, 0.35, 0.38), "trim": Color(0.85, 0.66, 0.25), "hair": Color(0.08, 0.08, 0.08), "shoulder": 0.7}

func _build(color: Color) -> void:
	var cast := _cast_colors()
	var suit_c: Color = cast["suit"]
	var trim_c: Color = cast["trim"]
	var hair_c: Color = cast["hair"]
	var shoulder: float = cast["shoulder"]
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.65
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	# Torso with shoulder width per character (bust language).
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(shoulder, 0.95, 0.45)
	body.mesh = bm
	body.position.y = 1.05
	body.material_override = ArtDirection.mat(suit_c, 0.85)
	add_child(body)
	# Trim: tie (bosses) or scarf (Hana/Sora).
	var trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.10, 0.55, 0.03)
	trim.mesh = tm
	trim.position = Vector3(0, 1.05, 0.24)
	trim.material_override = ArtDirection.mat(trim_c, 0.6)
	add_child(trim)
	# Head + hair.
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.20
	sm.height = 0.40
	head.mesh = sm
	head.position.y = 1.78
	head.material_override = ArtDirection.mat(Color(0.93, 0.78, 0.66), 0.7)
	add_child(head)
	var hair := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.205
	hm.height = 0.28
	hair.mesh = hm
	hair.position = Vector3(0, 1.86, -0.02)
	hair.material_override = ArtDirection.mat(hair_c, 0.9)
	add_child(hair)
	_label = Label3D.new()
	var kr: String = KR.get(npc_name, npc_name)
	_label.text = "%s %s" % [npc_name, kr]
	_label.font_size = 56
	_label.pixel_size = 0.007
	_label.modulate = Color(0.96, 0.94, 0.88)
	_label.outline_size = 10
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.position = Vector3(0, 2.15, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	# Pass color hint through (kept for API compat).
	if color == Color(0, 0, 0, 0):
		pass

func _process(delta: float) -> void:
	_t += delta * DayClock.REAL_TO_GAME
	if _t > dwell_time and not _leaving:
		_leaving = true
		if _label != null:
			_label.text = "%s (left)" % npc_name
	if _leaving:
		velocity.x = 1.2
		velocity.z = 0.0
		velocity.y = -1.0
		move_and_slide()
		if position.distance_to(_home) > 12.0:
			visible = false
			set_process(false)
