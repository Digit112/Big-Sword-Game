extends Control

var frame_advance = false
var frame_advance_counter = 0

func _input(event):
	if event.is_action_pressed("Pause"):
		get_tree().paused = !get_tree().paused

func _physics_process(delta: float) -> void:
	frame_advance_counter += 1
	if frame_advance:
		get_tree().paused = true
		frame_advance = false
	
	if frame_advance_counter >= 8 and Input.is_action_pressed("FrameAdvance"):
		frame_advance_once()

func frame_advance_once() -> void:
	get_tree().paused = false
	frame_advance = true
	frame_advance_counter = 0
