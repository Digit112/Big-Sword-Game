extends Camera3D

@export var player : CharacterBody3D

@export var camera_yaw_speed : float = 360 * PI/180
@export var camera_pitch_speed : float = 180 * PI/180

## Fraction of remaining camera rotation speed realized per second.
## Basically, higher values give snappier camera motion.
## If it exceeds the number of physics ticks per second, the camera will always go exactly the speed requested by the input.
@export var camera_acceleration : float = 5

@export var camera_focus_offset : Vector3 = Vector3(0, 1, 0)
@export var max_camera_distance : float = 5

# TODO: It is likely possible to adjust this value more automatically based on the camera's projection matrix or FOV in addition to the raycast collision normal.
# TODO: Consider adjusting the camera's position along the collision normal? Could cause jittery movement.
## Distance the camera is nudged forward from the nearest wall.
##
## It's best to keep this comparable to the near clipping plane. That helps ensure that the near clipping plane doesn't intersect any geometry.
@export var camera_wall_buffer : float = 0.12
@export_flags_3d_physics var camera_raycast_collision : int = 1

@export_range(0, PI/2) var max_pitch : float = 82 * PI/180

# Direction the camera is facing.
var yaw : float = 0
var pitch : float = -30 * PI/180

var current_camera_speed_mul : float = 0

func _physics_process(delta: float) -> void:
	# Get Stick Inputs
	var camera_input : Vector2 = Vector2.ZERO
	if Input.is_action_pressed("StickSwap"):
		camera_input = Globals.get_normalized_input_vec(
			"MoveForward", "MoveRight", "MoveBackward", "MoveLeft"
		)
	
	else:
		camera_input = Globals.get_normalized_input_vec(
			"CamUp", "CamRight", "CamDown", "CamLeft"
		)
	
	# Adjust camera in response to input
	current_camera_speed_mul = lerpf(
		current_camera_speed_mul, camera_input.length(), camera_acceleration*delta
	)
	
	rotate_yaw_pitch(
		camera_input * Vector2(camera_yaw_speed, camera_pitch_speed) * delta * current_camera_speed_mul
	)
	
	var facing = Vector3.FORWARD.rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var focus = player.position + camera_focus_offset
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(focus, focus - facing * max_camera_distance, camera_raycast_collision)
	var col = space.intersect_ray(query)
	
	var current_camera_distance = max_camera_distance
	if "position" in col:
		current_camera_distance = focus.distance_to(col["position"]) - camera_wall_buffer
		
		print(col["collider"])
	
	position = focus - facing * current_camera_distance
	look_at(focus)

## Adjust the camera yaw by the given amount in radians
func rotate_yaw(delta_rad : float) -> void:
	yaw = fposmod(yaw + delta_rad, 2*PI)

## Adjust the camera pitch up to the given amount in radians
func rotate_pitch(delta_rad : float) -> void:
	pitch = clamp(pitch + delta_rad, -max_pitch, max_pitch)

## Receives vector formed from a pair of inputs. x for yaw and y for pitch
func rotate_yaw_pitch(delta : Vector2) -> void:
	rotate_yaw(delta.x)
	rotate_pitch(delta.y)
