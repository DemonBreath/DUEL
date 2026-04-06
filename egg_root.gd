extends Node3D

@onready var egg_whole: Node3D = $EggWhole
@onready var egg_cracked: Node3D = $EggCracked
@onready var egg_exploded: Node3D = $EggExploded

func _ready() -> void:
	egg_whole.visible = true
	egg_cracked.visible = false
	egg_exploded.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if egg_whole.visible:
			egg_whole.visible = false
			egg_cracked.visible = true
			egg_exploded.visible = false
		elif egg_cracked.visible:
			egg_whole.visible = false
			egg_cracked.visible = false
			egg_exploded.visible = true
		else:
			egg_whole.visible = true
			egg_cracked.visible = false
			egg_exploded.visible = false
