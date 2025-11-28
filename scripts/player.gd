extends CharacterBody3D

@export_category("Movement")

@export var run_speed : float = 12
@export var walk_speed : float = 2

@export var turn_speed : float = 1080 * PI/180

## Axis input threshhold between walking and running.
@export_range(0, 1) var walk_run_input_threshhold : float = 0.7

## Gravity used during freefall
@export var gravity : float = -30

## Lighter gravity used up to a certain time after the player presses and holds the jump button to extend their jump.
@export var jump_gravity : float = -14

## Vertical velocity gained from a grounded jump.
@export var jump_velocity : float = 10

# TODO: Could swap these params out for a more physical model of friction?
## Maximum vertical acceleration applied instead of gravity
## To bring the vertical speed up to the equilibrium.
@export var cling_friction : float = 4

## Downward acceleration due to gravity while clinging.
@export var cling_gravity : float = -4

## Equilibrium speed at which the player will no longer vertically accelerate under the influence of gravity. If the player is already moving downward faster than this, they will accelerate towards the equilibrium.
@export var cling_vertical_equilibrium_speed : float = -12

@export_category("Buffer Times")

@export var jump_buffer_time : float = 8.0 / 60

@export_category("Transitions")

@export var stand_walk_trans_time : float = 0.5
@export var walk_run_trans_time : float = 0.2
@export var run_walk_trans_time : float = 0.1
@export var walk_stand_trans_time : float = 0.1

var stand_run_trans_time = walk_run_trans_time
var run_stand_trans_time = run_walk_trans_time

var ground_speed_trans_times : Dictionary = {
	GROUNDED_STANDING: {GROUNDED_WALKING: stand_walk_trans_time,  GROUNDED_RUNNING: stand_run_trans_time},
	GROUNDED_WALKING:  {GROUNDED_STANDING: walk_stand_trans_time, GROUNDED_RUNNING: walk_run_trans_time },
	GROUNDED_RUNNING:  {GROUNDED_STANDING: run_stand_trans_time,  GROUNDED_WALKING: run_walk_trans_time }
}

#### State Constants ####
const GROUNDED : int = 0
const AERIAL : int = 256
const CLUNG : int = 512
const HANGING : int = 768

const GROUNDED_STANDING      : int = GROUNDED + 1
const GROUNDED_WALKING       : int = GROUNDED + 2
const GROUNDED_RUNNING       : int = GROUNDED + 3
const GROUNDED_DASHING       : int = GROUNDED + 4
const GROUNDED_SLIDING       : int = GROUNDED + 5
const GROUNDED_CROUCHED      : int = GROUNDED + 6
const GROUNDED_CROUCHWALKING : int = GROUNDED + 7

const AERIAL_FREEFALL : int = AERIAL + 1
const AERIAL_JUMPING  : int = AERIAL + 2
const AERIAL_DASHING  : int = AERIAL + 3

const CLUNG_SLIDING : int = CLUNG + 1
const CLUNG_DASHING : int = CLUNG + 2

const HANGING_POINT : int = HANGING + 1
const HANGING_LEDGE : int = HANGING + 2

#### State ####
var state : int = GROUNDED_STANDING

var current_ground_speed : float = 0

#### Tweens ####
var tween_ground_speed : Tween

func _physics_process(delta):
	# Get Stick Inputs
	var directional_input = Globals.get_normalized_input_vec(
		"MoveForward", "MoveRight", "MoveBackward", "MoveLeft"
	)
	
	var camera_input = Globals.get_normalized_input_vec(
		"CamUp", "CamRight", "CamDown", "CamLeft"
	)
	
	# Swap stick inputs
	if Input.is_action_pressed("StickSwap"):
		var temp = directional_input
		directional_input = camera_input
		camera_input = temp
	
	# Calculate direction to move
	var grounded_movement_dir : Vector2 = Vector2.ZERO
	var grounded_velocity = Vector2(velocity.x, velocity.z)
	var turning_speed_multiplier : float = 1
	if directional_input.length() > 0:
		if grounded_velocity.length() > 0:
			# Turn to face input direction.
			var angle_to = grounded_velocity.angle_to(directional_input)
			var turn_this_frame = max(min(angle_to, turn_speed*delta), -turn_speed*delta)
			
			# Slow down while turning.
			turning_speed_multiplier = max(cos(angle_to), 0.2)
			
			grounded_movement_dir = grounded_velocity.rotated(turn_this_frame)
			look_at(transform.origin +
				Vector3(grounded_movement_dir.x, 0, grounded_movement_dir.y),
				Vector3.UP
			)
		
		else:
			grounded_movement_dir = directional_input.normalized()
		
	elif grounded_velocity.length() > 0:
		grounded_movement_dir = grounded_velocity.normalized()
	
	if get_broad_state() == GROUNDED:
		if get_state() in [GROUNDED_STANDING, GROUNDED_WALKING, GROUNDED_RUNNING]:
			var threshholds_states_and_speeds = [
				[walk_run_input_threshhold, GROUNDED_RUNNING, run_speed],
				[0, GROUNDED_WALKING, walk_speed],
				[-1, GROUNDED_STANDING, 0]
			]
			
			# Potentially adjust to new travel speed.
			for entry in threshholds_states_and_speeds:
				if directional_input.length() > entry[0]:
					if state != entry[1]:
						kill_tween_if_alive(tween_ground_speed)
						
						tween_ground_speed = create_tween()
						tween_ground_speed.tween_property(
							self, "current_ground_speed", entry[2],
							ground_speed_trans_times[state][entry[1]]
						)
						
						set_state(entry[1])
					
					break
			
			var ground_speed_this_frame : float = current_ground_speed * turning_speed_multiplier
			
			if grounded_movement_dir.length() > 0:
				grounded_movement_dir = grounded_movement_dir.normalized()
				velocity.x = grounded_movement_dir.x * ground_speed_this_frame
				velocity.z = grounded_movement_dir.y * ground_speed_this_frame
			
			#print("Raw: ", directional_input, " Dir: ", grounded_movement_dir, " SPD: ", ground_speed_this_frame)
			#for tween in get_tree().get_processed_tweens():
				#print("Valid: ", tween.is_valid(), " Covered: ", tween.get_total_elapsed_time())
			
			if ActionBuffer.get_time_since_last_press("Jump", true) < jump_buffer_time:
				set_state(AERIAL_JUMPING)
				velocity.y += jump_velocity
	
	elif get_broad_state() == AERIAL:
		if not is_on_floor():
			if get_state() == AERIAL_JUMPING:
				print("Jumping")
				velocity.y += jump_gravity*delta
			
				if not Input.is_action_pressed("Jump"):
					set_state(AERIAL_FREEFALL)
			
			elif get_state() == AERIAL_FREEFALL:
				print("freefall")
				velocity.y += gravity*delta
		
		# On floor, become grounded.
		else:
			var lateral_vel = Vector2(velocity.x, velocity.z)
			
			if lateral_vel.length() > run_speed:
				set_state(GROUNDED_SLIDING)
			
			elif lateral_vel.length() > walk_speed:
				set_state(GROUNDED_RUNNING)
			
			elif lateral_vel.length() > 0.1:
				set_state(GROUNDED_WALKING)
			
			else:
				# TODO: If crouching pressed, transition to crouching instead
				set_state(GROUNDED_STANDING)
	
	move_and_slide()

func get_state() -> int:
	return state

func set_state(new_state: int) -> void:
	state = new_state

func kill_tween_if_alive(tween : Tween) -> void:
	if tween == null:
		return
	
	else:
		tween.kill()

func get_broad_state():
	@warning_ignore("integer_division")
	return state / 256 * 256
