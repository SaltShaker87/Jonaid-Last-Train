class_name SleepSpot
extends Interactable
## The bed. Ends the day.


func _on_used(_by: Node) -> void:
	enabled = false
	Game.sleep()
