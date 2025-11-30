extends Panel

@export var player : CharacterBody3D

@export var lbl_state : Label
@export var lbl_is_jumping : Label
@export var lbl_is_dashing : Label

func _physics_process(delta: float) -> void:
	lbl_state.text = player.state_names[player.get_state()]
	lbl_is_jumping.text = "JUMPING" if player.currently_jumping else ""
	lbl_is_dashing.text = "DASHING" if player.currently_dashing else ""
