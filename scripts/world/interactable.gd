class_name Interactable
extends Area3D
## Something Jonaid can press E on. The player's sensor finds these on
## physics layer 4 ("interact"); the HUD shows `prompt`.

signal used(by: Node)

@export var prompt := "Use"
@export var enabled := true
@export var radius := 1.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_child_count() == 0 or not (get_child(0) is CollisionShape3D):
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		add_child(shape)


func can_use() -> bool:
	return enabled and is_visible_in_tree()


func interact(by: Node) -> void:
	if can_use():
		used.emit(by)
		_on_used(by)


## Override in subclasses.
func _on_used(_by: Node) -> void:
	pass
