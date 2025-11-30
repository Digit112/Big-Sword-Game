extends CharacterBody3D

@export var camera : Camera3D

@export_subgroup("Grounded Motion")

@export var run_speed : float = 12
@export var sneak_speed : float = 4
@export var walk_speed : float = 2

@export var turn_speed : float = 960 * PI/180
@export var sneak_turn_speed : float = 720 * PI/180
@export var sliding_turn_speed : float = 60 * PI/180

## Loss of velocity per second while sliding.
@export var sliding_deceleration : float = 15

## Fraction of velocity lost per second while sliding.
@export var sliding_friction : float = 2

## Rate of maximum lateral acceleration inparted by directional input while sliding.
@export var sliding_max_accel : float = 4

## Axis input threshhold between walking and running.
@export_range(0, 1) var walk_run_input_threshhold : float = 0.7

@export_subgroup("Aerial Motion")

@export var aerial_speed : float = 14

@export var aerial_turn_speed : float = 1280 * PI/180
@export var soaring_turn_speed : float = 360 * PI/180

## Rate of lateral deceleration while in freefall with no directional input.
@export var aerial_lateral_deceleration : float = 28

## Rate of lateral deceleration while soaring.
@export var soaring_lateral_deceleration : float = 12

## Rate of maximum lateral acceleration imparted by directional input while soaring
@export var soaring_max_lateral_acceleration : float = 16

## Fraction of lateral velocity lost per second while soaring.
@export var soaring_lateral_friction : float = 0.5

## Speed at which an aerial player is forced into the AERIAL_SOARING state.
@export var freefall_soaring_speed_threshhold : float = 16

## Gravity used during freefall
@export var gravity : float = -30

@export_subgroup("Dashing")

## Factor to multiply speed by when dashing.
@export var dash_speed_mul : float = 1

## Bonus speed added when dashing. Applied after multiplication.
@export var dash_speed_bonus : float = 12

## Minimum speed that the player will be raised to if their bonus speed from dashing does not bring them to this threshhold.
@export var min_dash_speed : float = 32

## Duration of dashes in seconds
@export var dash_duration : float = 0.3

## Time after the completion of a dash after which a second one can begin.
@export var dash_cooldown : float = 0.5

@export_subgroup("Jumping")

## Vertical velocity gained from a grounded jump.
@export var jump_velocity : float = 10

## Lighter gravity used up to a certain time after the player presses and holds the jump button to extend their jump.
@export var jump_gravity : float = -16

## Maximum time the player can extend their jump by holding jump in seconds.
@export var max_jump_length : float = 0.4

@export_subgroup("Clinging")

# TODO: Could swap these params out for a more physical model of friction?
## Maximum vertical acceleration applied instead of gravity
## To bring the vertical speed up to the equilibrium.
@export var cling_deceleration : float = 4

## Downward acceleration due to gravity while clinging.
@export var cling_gravity : float = -4

## Equilibrium speed at which the player will no longer vertically accelerate under the influence of gravity. If the player is already moving downward faster than this, they will accelerate towards the equilibrium.
@export var cling_vertical_equilibrium_speed : float = -12

@export_subgroup("Buffer Times & Transitions")

## How long to buffer for jumps off of the ground or walls.
@export var jump_buffer_time : float = 4.0 / 60

## How long to buffer dashes during dash cooldown.
@export var dash_buffer_time : float = 4.0 / 60

@export var stand_walk_trans_time : float = 0.5
@export var walk_run_trans_time : float = 0.2
@export var run_walk_trans_time : float = 0.1
@export var walk_stand_trans_time : float = 0.1

var stand_run_trans_time = walk_run_trans_time
var run_stand_trans_time = run_walk_trans_time

#---- State Constants ----#

const GROUNDED : int = 0
const AERIAL : int = 256
const CLUNG : int = 512
const HANGING : int = 768

const GROUNDED_STANDING      : int = GROUNDED + 1
const GROUNDED_WALKING       : int = GROUNDED + 2
const GROUNDED_RUNNING       : int = GROUNDED + 3
const GROUNDED_SLIDING       : int = GROUNDED + 4
const GROUNDED_CROUCHED      : int = GROUNDED + 5
const GROUNDED_CROUCHWALKING : int = GROUNDED + 6

const AERIAL_FREEFALL : int = AERIAL + 1
const AERIAL_SOARING  : int = AERIAL + 2

const CLUNG_SLIDING : int = CLUNG + 1

const HANGING_POINT : int = HANGING + 1
const HANGING_LEDGE : int = HANGING + 2

# Transition times between various grounded states.
# Indexed as ground_speed_trans_times[from_state][to_state]
var ground_speed_trans_times : Dictionary = {
	GROUNDED_STANDING: {
		GROUNDED_WALKING: stand_walk_trans_time, GROUNDED_RUNNING: stand_run_trans_time,
		GROUNDED_CROUCHED: 0, GROUNDED_CROUCHWALKING: stand_walk_trans_time
	},
	GROUNDED_WALKING:  {
		GROUNDED_STANDING: walk_stand_trans_time, GROUNDED_RUNNING: walk_run_trans_time,
		GROUNDED_CROUCHED: walk_stand_trans_time, GROUNDED_CROUCHWALKING: 0
	},
	GROUNDED_RUNNING:  {
		GROUNDED_STANDING: run_stand_trans_time, GROUNDED_WALKING: run_walk_trans_time,
		GROUNDED_CROUCHED: run_stand_trans_time, GROUNDED_CROUCHWALKING: run_walk_trans_time
	},
	GROUNDED_CROUCHED: {
		GROUNDED_STANDING: 0, GROUNDED_WALKING: stand_walk_trans_time,
		GROUNDED_RUNNING: stand_run_trans_time, GROUNDED_CROUCHWALKING: stand_walk_trans_time
	},
	GROUNDED_CROUCHWALKING: {
		GROUNDED_STANDING: walk_stand_trans_time, GROUNDED_WALKING: 0,
		GROUNDED_RUNNING: walk_run_trans_time, GROUNDED_CROUCHED: walk_stand_trans_time
	},
}

# Rate that facing or moving direction swivels about the y axis to match directional input.
var turning_speed_by_state : Dictionary = {
	GROUNDED_STANDING: turn_speed,
	GROUNDED_WALKING: turn_speed,
	GROUNDED_RUNNING: turn_speed,
	GROUNDED_SLIDING: sliding_turn_speed,
	GROUNDED_CROUCHED: sneak_turn_speed,
	GROUNDED_CROUCHWALKING: sneak_turn_speed,
	
	AERIAL_FREEFALL: aerial_turn_speed,
	AERIAL_SOARING: soaring_turn_speed,
	
	CLUNG_SLIDING: 0,
	HANGING_POINT: 0,
	HANGING_LEDGE: 0
}

var state_names : Dictionary = {
	GROUNDED_STANDING: "GROUNDED_STANDING",
	GROUNDED_WALKING: "GROUNDED_WALKING",
	GROUNDED_RUNNING: "GROUNDED_RUNNING",
	GROUNDED_SLIDING: "GROUNDED_SLIDING",
	GROUNDED_CROUCHED: "GROUNDED_CROUCHED",
	GROUNDED_CROUCHWALKING: "GROUNDED_CROUCHWALKING",
	
	AERIAL_FREEFALL: "AERIAL_FREEFALL",
	AERIAL_SOARING: "AERIAL_SOARING",
	
	CLUNG_SLIDING: "CLUNG_SLIDING",
	
	HANGING_POINT: "HANGING_POINT",
	HANGING_LEDGE: "HANGING_LEDGE"
}

# ---- State ---- #

var state : int = GROUNDED_STANDING

var time_since_jump : float = INF
var time_since_dash : float = INF

var currently_jumping : bool = false
var currently_dashing : bool = false
var dash_velocity : Vector3 = Vector3.ZERO

# Tweened
var current_ground_speed : float = 0

#---- Tweens ----#
var tween_ground_speed : Tween





#-------- MEMBER FUNCTIONS --------#

## Gets the category of the current state.
func get_broad_state() -> int:
	@warning_ignore("integer_division")
	return state / 256 * 256

func get_state() -> int:
	return state

func set_state(new_state: int) -> void:
	print(state_names[state], " -> ", state_names[new_state])
	state = new_state

func can_slide() -> bool:
	# We can slide if we are moving fast enough to stay sliding for at least 0.1 seconds.
	var speed_threshhold = run_speed + sliding_deceleration / 10
	return Globals.lateralize(velocity).length() >= speed_threshhold

func can_soar() -> bool:
	# We can soar if we are moving faster than the top normal aerial speed by a bit.
	return Globals.lateralize(velocity).length() >= freefall_soaring_speed_threshhold

## Transistions to the appropriate grounded state based on velocity.
func become_grounded() -> void:
	var lateral_velocity = Globals.lateralize(velocity)
	currently_jumping = false
	
	if lateral_velocity.length() > run_speed and can_slide():
		set_state(GROUNDED_SLIDING)
	
	elif lateral_velocity.length() > walk_speed:
		set_state(GROUNDED_RUNNING)
		current_ground_speed = run_speed
	
	elif lateral_velocity.length() > 0.1:
		set_state(GROUNDED_WALKING)
		current_ground_speed = walk_speed
	
	else:
		current_ground_speed = 0
		# TODO: If crouching pressed, transition to crouching instead
		set_state(GROUNDED_STANDING)

## Transistions to the appropriate aerial state based on velocity.
func become_aerial() -> void:
	var lateral_velocity = Globals.lateralize(velocity)
	
	if lateral_velocity.length() >= freefall_soaring_speed_threshhold:
		set_state(AERIAL_SOARING)
	
	else:
		set_state(AERIAL_FREEFALL)

## Performs a jump. This involves adding velocity, performing a state transition, and setting state variables
func jump() -> void:
	time_since_jump = 0
	currently_jumping = true
	
	if get_broad_state() == GROUNDED:
		if currently_dashing:
			dash_velocity.y += jump_velocity
		
		else:
			velocity.y += jump_velocity
		
		become_aerial()
	
	elif get_broad_state() == CLUNG:
		dash_velocity.y += jump_velocity
		become_aerial()
	
	elif get_broad_state() == HANGING:
		# TODO
		become_aerial()
	
	else:
		push_warning("Cannot jump from state " + state_names[get_state()])

func can_dash() -> bool:
	return not currently_dashing and time_since_dash > dash_duration + dash_cooldown

## Performs a dash. This involves setting velocity and state variables. Directional input must already be corrected for camera yaw.
##
## The dash direction becomes the camera direction if aiming, otherwise it will be projected crudely onto the floor or wall the player is in contact with if there is any. Otherwise it is simply lateralized.
## If the directional input is zero, the dash takes the player's velocity. If this too is zero, it takes the player's facing direction.
func dash(directional_input : Vector2) -> void:
	
	#---- Calculate dash direction ----#
	
	var dash_direction : Vector3 = Vector3.ZERO
	var lateral_velocity = Globals.lateralize(velocity)
	
	# Dash where camera is pointingv
	if Input.is_action_pressed("Aim"):
		dash_direction = -camera.basis.z.normalized()
	
	# Take directional input
	elif directional_input.length() > 0:
		# Dash along ground.
		if get_broad_state() == GROUNDED and is_on_floor():
			# Rotates the dash direction until it is coplanar with the floor.
			# Rotation is performed in the plane of the normal and lateralized directional input.
			var flat_dir : Vector3 = Vector3(directional_input.x, 0, directional_input.y)
			dash_direction = get_floor_normal().cross(flat_dir).cross(get_floor_normal()).normalized()
		
		# Dash along wall
		elif get_broad_state() == CLUNG and is_on_wall():
			# Dash direction mapped onto vertical circle which billboards towards the camera.
			# Directional input is rotated off this circle until it is coplanar with the wall.
			var vert_dir : Vector3 = Vector3(directional_input.x, directional_input.y, 0)
			vert_dir = vert_dir.rotated(Vector3.UP, camera.yaw)
			dash_direction = get_wall_normal().cross(vert_dir).cross(get_floor_normal()).normalized()
		
		# Dash along lateral (XZ) plane.
		else:
			dash_direction = Vector3(directional_input.x, 0, directional_input.y).normalized()
	
	# Take velocity.
	elif lateral_velocity.length() > 0.01:
		dash_direction = Vector3(lateral_velocity.x, 0, lateral_velocity.y).normalized()
	
	# Take facing dir.
	else:
		dash_direction = -basis.z.normalized()
	
	#---- Perform Dash ----#
	
	currently_dashing = true
	time_since_dash = 0
	
	var new_speed : float = max(
		velocity.length() * dash_speed_mul + dash_speed_bonus, min_dash_speed
	)
	
	# Note: if dashing, velocity and rotation will be set based on this at the start of every frame.
	# While dashing, only move_and_slide and state transition detections will runn.
	dash_velocity = dash_direction * new_speed





func _physics_process(delta):
	time_since_jump += delta
	time_since_dash += delta
	
	# Get Stick Inputs
	var directional_input : Vector2 = Vector2.ZERO
	if Input.is_action_pressed("StickSwap"):
		directional_input = Globals.get_normalized_input_vec(
			"CamUp", "CamRight", "CamDown", "CamLeft"
		)
	
	else:
		directional_input = Globals.get_normalized_input_vec(
			"MoveForward", "MoveRight", "MoveBackward", "MoveLeft"
		)
	
	# Adjust directional input to match camera.
	directional_input = directional_input.rotated(-camera.yaw)
	
	# Consider dashing.
	if ActionBuffer.get_time_since_last_press("Dash", true) < dash_buffer_time and can_dash():
		dash(directional_input)
	
	# Consider ending an ongoing dash
	if currently_dashing and time_since_dash > dash_duration:
		currently_dashing = false
	
	# If (still) dashing, set a specific velocity.
	if currently_dashing:
		velocity = dash_velocity
		look_at(position + Vector3(dash_velocity.x, 0, dash_velocity.z))
	
	# ONLY IF NOT DASHING, handle movement including turning, friction, and acceleration.
	else:
		# Calculate direction to move this frame, not accounting for turning
		var lateral_velocity = Globals.lateralize(velocity)
		var lateral_movement_dir : Vector2 = Vector2.ZERO
		if lateral_velocity.length() > 0 and get_broad_state() != AERIAL:
			lateral_movement_dir = lateral_velocity.normalized()
		else:
			lateral_movement_dir = Globals.lateralize(-basis.z).normalized()
		
		# Turn to face input direction.
		var lateral_speed_multiplier : float = 1
		if directional_input.length() > 0:
			var max_turn_this_frame = turning_speed_by_state[get_state()] * delta
			if max_turn_this_frame > 0:
				var angle_to = lateral_movement_dir.angle_to(directional_input)
				
				var turn_this_frame = clamp(angle_to, -max_turn_this_frame, max_turn_this_frame)
				
				# Slow down while turning, only used while grounded.
				lateral_speed_multiplier = max(cos(angle_to), 0.2)
				
				# Rotate velocity and face in moving direction.
				lateral_movement_dir = lateral_movement_dir.rotated(turn_this_frame)
				look_at(transform.origin +
					Vector3(lateral_movement_dir.x, 0, lateral_movement_dir.y),
					Vector3.UP
				)
		
		if get_broad_state() == GROUNDED:
			var ground_speed_this_frame : float = current_ground_speed * lateral_speed_multiplier
			
			if get_state() in [GROUNDED_STANDING, GROUNDED_WALKING, GROUNDED_RUNNING]:
				# TODO: Make a named dictionary maybe? Something for better readability.
				var threshholds_states_and_speeds = [
					[walk_run_input_threshhold, GROUNDED_RUNNING,  run_speed],
					[0,                         GROUNDED_WALKING,  walk_speed],
					[-1,                        GROUNDED_STANDING, 0]
				]
				
				var sneaking_threshholds_states_and_speeds = [
					[0,  GROUNDED_CROUCHWALKING, sneak_speed],
					[-1, GROUNDED_CROUCHED,      0]
				]
				
				# Potentially adjust to new travel speed.
				if Input.is_action_pressed("Sneak"):
					for entry in sneaking_threshholds_states_and_speeds:
						if directional_input.length() > entry[0]:
							if get_state() != entry[1]:
								reset_ground_speed_tween(entry[2], ground_speed_trans_times[get_state()][entry[1]])
								set_state(entry[1])
							break
				
				else:
					for entry in threshholds_states_and_speeds:
						if directional_input.length() > entry[0]:
							if get_state() != entry[1]:
								reset_ground_speed_tween(entry[2], ground_speed_trans_times[get_state()][entry[1]])
								set_state(entry[1])
							break
				
				#print("Raw: ", directional_input, " Dir: ", lateral_movement_dir, " SPD: ", ground_speed_this_frame)
				#for tween in get_tree().get_processed_tweens():
					#print("Valid: ", tween.is_valid(), " Covered: ", tween.get_total_elapsed_time())
			
			elif get_state() == GROUNDED_SLIDING:
				ground_speed_this_frame = move_toward(
					lateral_velocity.length(), 0, sliding_deceleration * delta
				) * exp(-sliding_friction * delta)
				
				if ground_speed_this_frame < run_speed:
					current_ground_speed = run_speed
					set_state(GROUNDED_RUNNING)
				
			if lateral_movement_dir.length() > 0:
				#print(lateral_movement_dir, ", ", ground_speed_this_frame, ", ", current_ground_speed, ", ", state_names[get_state()])
				lateral_movement_dir = lateral_movement_dir.normalized()
				velocity.x = lateral_movement_dir.x * ground_speed_this_frame
				velocity.z = lateral_movement_dir.y * ground_speed_this_frame
		
		elif get_broad_state() == AERIAL:
			# Apply gravity.
			if currently_jumping:
				velocity.y += jump_gravity*delta
			
				if not Input.is_action_pressed("Jump") or time_since_jump > max_jump_length:
					currently_jumping = false
			
			else:
				velocity.y += gravity*delta
			
			var lateral_speed_this_frame : float = 0
			if get_state() == AERIAL_FREEFALL:
				if directional_input.length() == 0:
					lateral_speed_this_frame = move_toward(
						lateral_velocity.length(), 0, aerial_lateral_deceleration * delta
					)
				
				else:
					lateral_speed_this_frame = directional_input.length() * aerial_speed
			
			elif get_state() == AERIAL_SOARING:
				# While soaring, carry momentum.
				lateral_movement_dir = lateral_velocity.move_toward(
					Vector2.ZERO, soaring_lateral_deceleration * delta
				) * (
					exp(-soaring_lateral_friction * delta)
				) + (
					directional_input * soaring_max_lateral_acceleration * delta
				)
				
				lateral_speed_this_frame = lateral_movement_dir.length()
			
			if lateral_movement_dir.length() > 0:
				lateral_movement_dir = lateral_movement_dir.normalized()
				velocity.x = lateral_movement_dir.x * lateral_speed_this_frame
				velocity.z = lateral_movement_dir.y * lateral_speed_this_frame
	
	# Consider jumping
	var attempting_jump : bool = ActionBuffer.get_time_since_last_press("Jump", true) < jump_buffer_time
	var can_jump : bool = not currently_jumping and get_broad_state() in [GROUNDED, CLUNG, HANGING]
	if attempting_jump and can_jump:
		jump()
	
	move_and_slide()
	
	# Possibly perform a state transition in response to move_and_slide results.
	if is_on_floor():
		if get_broad_state() != GROUNDED:
			become_grounded()
		
		if get_state() != GROUNDED_SLIDING and can_slide():
			set_state(GROUNDED_SLIDING)
	
	elif is_on_wall():
		if get_broad_state() != CLUNG:
			pass # Begin clinging!
	
	else:
		if get_broad_state() != AERIAL:
			become_aerial()
		
		if get_state() != AERIAL_SOARING and can_soar():
			set_state(AERIAL_SOARING)

# Correctly sets up a tween on ground speed which controls velocity in most grounded states.
# Used to smoth the transition between standing/walking/running/crouched/sneaking (crouchwalking)
func reset_ground_speed_tween(final_speed: float, trans_time: float):
	if tween_ground_speed != null and tween_ground_speed.is_valid():
		tween_ground_speed.kill()
	
	tween_ground_speed = create_tween()
	tween_ground_speed.tween_property(self, "current_ground_speed", final_speed, trans_time)
