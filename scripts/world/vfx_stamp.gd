extends Node3D
class_name StampFX
## The DO NOT COPY stamp as a live object (VFX pass).
## Pulses oxblood so the eye lands on it; thump() fires when the folder
## is pinned (Main.vfx verb -> catalog effect).

var _plate: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _burst: CPUParticles3D
var _ambient: CPUParticles3D
var _t := 0.0
var _flash := 0.0

func _ready() -> void:
	add_to_group("vfx_stamp")
	# Emissive backing plate behind the ivory stamp label.
	_plate = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.85, 0.62, 0.03)
	_plate.mesh = bm
	_mat = ArtDirection.mat(ArtDirection.OXBLOOD, 0.5, 0.0, ArtDirection.OXBLOOD.lightened(0.25), 0.35)
	_plate.material_override = _mat
	_plate.position = Vector3(0, -0.06, -0.05)
	add_child(_plate)
	_light = OmniLight3D.new()
	_light.light_color = ArtDirection.OXBLOOD.lightened(0.35)
	_light.light_energy = 0.0
	_light.omni_range = 2.6
	_light.position = Vector3(0, 0, 0.4)
	add_child(_light)
	_ambient = VFX.motes(self, Vector3(0, -0.1, 0.3), Vector3(0.9, 0.4, 0.4), ArtDirection.OXBLOOD.lightened(0.3), 0.8, Vector3(0, 1, 0), 0.05)
	_burst = VFX.burst(self, Vector3(0, 0.1, 0.2), ArtDirection.IVORY, 10)

func _process(delta: float) -> void:
	# Slow oxblood breath + a flash that decays after a thump.
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	_mat.emission_energy_multiplier = 0.35 + pulse * 0.3 + _flash * 1.6
	_light.light_energy = pulse * 0.35 + _flash * 2.0
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.8)
		_plate.scale = Vector3.ONE * (1.0 + _flash * 0.12)

func thump() -> void:
	# Pin moment: the stamp agrees with you, once.
	_flash = 1.0
	_burst.restart()
	_burst.emitting = true
