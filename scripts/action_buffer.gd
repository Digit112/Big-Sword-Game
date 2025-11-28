extends Node

var frame_count : int = 0

var pressed_frames : Dictionary
var released_frames : Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		frame_count += 1

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventKey:
		var all_actions = InputMap.get_actions()
		
		# Iterate through all action names
		for action_name in all_actions:
			if event.is_action(action_name):
				if event.pressed:
					pressed_frames[action_name] = frame_count
				else:
					released_frames[action_name] = frame_count

## Returns the physics frames since the last time the passed action was pressed, or -1 if it has never been pressed.
func get_frames_since_last_press(action: String) -> int:
	if action in pressed_frames:
		return frame_count - pressed_frames[action]
	else:
		return -1

## Returns the physics frames since the last time the passed action was released, or -1 if it has never been released.
func get_frames_since_last_release(action: String) -> int:
	if action in released_frames:
		return frame_count - released_frames[action]
	else:
		return -1

## Get the time, in seconds, since this action was last pressed, or INF if it was never pressed.
##
## If require_hold, also returns INF if the action is not currently pressed.
## Note that checking if the action is currently pressed is the same as ensuring that the action has been continuously held since the last press.
## The measured time is relative to the operation of the physics ticks, not real passed time.
## The result is that input bufferring, which is effectively frame-independant except for quantization error, nonetheless slows in response to lag.
func get_time_since_last_press(action: String, require_hold: bool) -> float:
	var frames_since_press = get_frames_since_last_press(action)
	
	if frames_since_press >= 0 and (not require_hold or Input.is_action_pressed(action)):
		# Add a slight amount of time to prevent floating-point rounding issues with boundaries meant to align exactly with frame boundaries.
		return float(frames_since_press) / Engine.physics_ticks_per_second + 0.0001
	else:
		return INF
