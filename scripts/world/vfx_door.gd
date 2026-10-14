extends Node3D
class_name DoorFX
## Station doors with weight (VFX pass): two slabs that slide shut, an oxblood
## seam flash, a platform dust puff. The board flips on its own clock.

var _left: MeshInstance3D
var _right: MeshInstance3D
var _seam: OmniLight3D
var _puff: CPUParticles3D
var _t := 0.0
var _closing := 0.0      # 0..1 progress
var _open_t := 0.0
var _closed := false
var _half_width := 2.0

func _ready() -> void:
	add_to_group("vfx_door")
	for half in ["L", "R"]:
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 2.4, 0.3)
		slab.mesh = bm
		slab.material_override = ArtDirection.mat(ArtDirection.SUBWAY_DARK, 0.35, 0.4)
		add_child(slab)
		if half == "L":
			_left = slab
		else:
			_right = slab
	_seam = OmniLight3D.new()
	_seam.light_color = ArtDirection.OXBLOOD.lightened(0.3)
	_seam.light_energy = 0.0
	_seam.omni_range = 5.0
	_seam.position = Vector3(0, 0.5, 0.3)
	add_child(_seam)
	_puff = VFX.burst(self, Vector3(0, 0.1, 0.6), ArtDirection.SUBWAY, 14)

func set_width(w: float) -> void:
	_half_width = w * 0.5

func close() -> void:
	_closing = 0.0
	_closed = true
	_puff.restart()
	_puff.emitting = true

func _process(delta: float) -> void:
	if _closing < 1.0:
		_closing = minf(1.0, _closing + delta * 0.9)
	_offset_slabs(1.0 - ease(_closing, 0.4))
	if _closed:
		# Oxblood seam breathes while the doors are shut.
		_open_t += delta
		_seam.light_energy = 0.25 + 0.2 * sin(_open_t * 2.4)

func _offset_slabs(gap: float) -> void:
	_left.position = Vector3(-gap * _half_width, 1.2, 0)
	_right.position = Vector3(gap * _half_width, 1.2, 0)
