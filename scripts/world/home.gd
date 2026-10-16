extends Location
## The apartment. Time stops here. Hana greets Jonaid at the door with a
## mood picked by how late he is (Game.lateness_tier).

## Indexed by Game.TIER_* (happy, annoyed, angry, furious).
const LINES := [
	[
		"You're home on time?! Who are you and what did you do with my husband?",
		"Dinner's still warm. It's a miracle. Light a candle.",
	],
	[
		"Oh. You're home. The rice is cold. Like my heart.",
		"Late again. I counted every minute. Out loud. To the kids.",
	],
	[
		"Do you know what time it is?! The KIDS know what time it is!",
		"I fed your dinner to the neighbour's dog. He said thank you. Unlike some people.",
	],
	[
		"I have been standing at this door since seven-thirty. WITH THE LADLE.",
		"A TAXI?! Do we look like chaebol to you?! Do we?!",
	],
]

var _greeted := false

@onready var hana: NPC = $NPCs/Hana


func on_enter(player: Node3D) -> void:
	if _greeted or not Game.in_run:
		return
	_greeted = true
	var tier := Game.lateness_tier(Clock.minutes)
	var pool: Array = LINES[tier]
	var line: String = pool[1] if tier == Game.TIER_FURIOUS and Game.took_taxi else pool[randi() % pool.size()]
	hana.play("Angry" if tier >= Game.TIER_ANGRY else ("Talk" if tier == Game.TIER_ANNOYED else "Idle"))
	await get_tree().create_timer(0.6).timeout
	Game.say(hana, line, 5.0)
	Game.add_anger(Game.TIER_ANGER[tier])
	if Game.anger >= Game.ANGER_MAX:
		await get_tree().create_timer(4.0).timeout
		Game.end_run("hana")
		return
	await get_tree().create_timer(5.5).timeout
	if is_instance_valid(hana):
		hana.play("Idle")
	if player is Player and tier >= Game.TIER_ANGRY:
		Game.say(player, "...I'll sleep on the couch. In my mind.")
