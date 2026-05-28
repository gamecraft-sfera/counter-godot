# COPYRIGHT Colormatic Studios
# MIT license
# Quality Godot First Person Controller v2


extends CharacterBody3D

@export var weapons: Array[PackedScene]
var actual_weapon_index: int = 0
var last_main_weapon: int = 0

#region Character Export Group

## The settings for the character's movement and feel.
@export_category("Character")
## The speed that the character moves at without crouching or sprinting.
@export var base_speed : float = 6.0
## The speed that the character moves at when sprinting.
@export var sprint_speed : float = 6.0
## The speed that the character moves at when crouching.
@export var crouch_speed : float = 1.0
@export var air_control : float = 2.5
@export var max_speed : float = 9.0
## How fast the character speeds up and slows down when Motion Smoothing is on.
@export var acceleration : float = 10.0
## How high the player jumps.
@export var jump_velocity : float = 5 
## How far the player turns when the mouse is moved.
@export var mouse_sensitivity : float = 0.1
## Invert the X axis input for the camera.
@export var invert_camera_x_axis : bool = false
## Invert the Y axis input for the camera.
@export var invert_camera_y_axis : bool = false
## Whether the player can use movement inputs. Does not stop outside forces or jumping. See Jumping Enabled.
@export var immobile : bool = false
## The reticle file to import at runtime. By default are in res://addons/fpc/reticles/. Set to an empty string to remove.
@export_file var default_reticle
@export var ground_accel : float = 10.0
@export var air_accel : float = 2.5
#endregion

#region Nodes Export Group

@export_group("Nodes")
## A reference to the camera for use in the character script. This is the parent node to the camera and is rotated instead of the camera for mouse input.
@export var HEAD : Node3D
## A reference to the camera for use in the character script.
@export var CAMERA : Camera3D
## A reference to the headbob animation for use in the character script.
@export var HEADBOB_ANIMATION : AnimationPlayer
## A reference to the jump animation for use in the character script.
@export var JUMP_ANIMATION : AnimationPlayer
## A reference to the crouch animation for use in the character script.
@export var CROUCH_ANIMATION : AnimationPlayer
## A reference to the the player's collision shape for use in the character script.
@export var COLLISION_MESH : CollisionShape3D

#endregion

#region Controls Export Group

# We are using UI controls because they are built into Godot Engine so they can be used right away
@export_group("Controls")
## Use the Input Map to map a mouse/keyboard input to an action and add a reference to it to this dictionary to be used in the script.
@export var controls : Dictionary = {
	LEFT = "ui_left",
	RIGHT = "ui_right",
	FORWARD = "ui_up",
	BACKWARD = "ui_down",
	JUMP = "ui_accept",
	CROUCH = "crouch",
	SPRINT = "sprint",
	PAUSE = "ui_cancel"
	}
@export_subgroup("Controller Specific")
## This only affects how the camera is handled, the rest should be covered by adding controller inputs to the existing actions in the Input Map.
@export var controller_support : bool = false
## Use the Input Map to map a controller input to an action and add a reference to it to this dictionary to be used in the script.
@export var controller_controls : Dictionary = {
	LOOK_LEFT = "look_left",
	LOOK_RIGHT = "look_right",
	LOOK_UP = "look_up",
	LOOK_DOWN = "look_down"
	}
## The sensitivity of the analog stick that controls camera rotation. Lower is less sensitive and higher is more sensitive.
@export_range(0.001, 1, 0.001) var look_sensitivity : float = 0.035

#endregion

#region Feature Settings Export Group

@export_group("Feature Settings")
## Enable or disable jumping. Useful for restrictive storytelling environments.
@export var jumping_enabled : bool = true
## Whether the player can move in the air or not.
@export var in_air_momentum : bool = true
## Smooths the feel of walking.
@export var motion_smoothing : bool = true
## Enables or disables sprinting.
@export var sprint_enabled : bool = true
## Toggles the sprinting state when button is pressed or requires the player to hold the button down to remain sprinting.
@export_enum("Hold to Sprint", "Toggle Sprint") var sprint_mode : int = 0
## Enables or disables crouching.
@export var crouch_enabled : bool = true
## Toggles the crouch state when button is pressed or requires the player to hold the button down to remain crouched.
@export_enum("Hold to Crouch", "Toggle Crouch") var crouch_mode : int = 0
## Wether sprinting should effect FOV.
@export var dynamic_fov : bool = true
## If the player holds down the jump button, should the player keep hopping.
@export var continuous_jumping : bool = true
## Enables the view bobbing animation.
@export var view_bobbing : bool = true
## Enables an immersive animation when the player jumps and hits the ground.
@export var jump_animation : bool = true
## This determines wether the player can use the pause button, not wether the game will actually pause.
@export var pausing_enabled : bool = true
## Use with caution.
@export var gravity_enabled : bool = true
## If your game changes the gravity value during gameplay, check this property to allow the player to experience the change in gravity.
@export var dynamic_gravity : bool = false

var can_shoot := true
@export var fire_rate := 1.2
var shooting := false
var weapon_changed := false


#endregion

#region Member Variable Initialization

# These are variables used in this script that don't need to be exposed in the editor.
var speed : float = base_speed
var current_speed : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
var low_ceiling : bool = false # This is for when the ceiling is too low and the player needs to crouch.
var was_on_floor : bool = true # Was the player on the floor last frame (for landing animation)

# The reticle should always have a Control node as the root
var RETICLE : Control

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity") # Don't set this as a const, see the gravity section in _physics_process

# Stores mouse input for rotating the camera in the physics process
var mouseInput : Vector2 = Vector2(0,0)


#endregion



#region Main Control Flow

func _ready():
	#It is safe to comment this line if your game doesn't start with the mouse captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	$Head/MuzzleFlash.visible = false
	$Head/MuzzleFlashAWP.visible = false
	$Head/MuzzleFlashDeagle.visible = false

	# If the controller is rotated in a certain direction for game design purposes, redirect this rotation into the head.
	HEAD.rotation.y = rotation.y
	rotation.y = 0

	if default_reticle:
		change_reticle(default_reticle)

	initialize_animations()
	check_controls()
	enter_normal_state()
	
	if OS.get_name() == "Web":
		Input.set_use_accumulated_input(false)
		
	$Head/blockbench_export.visible = false
	$Head/blockbench_export2.visible = false
	$Head/blockbench_export3.visible = false
	$Head/blockbench_export4.visible = false


func _process(_delta):
	if pausing_enabled:
		handle_pausing()

	update_debug_menu_per_frame()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		if actual_weapon_index == 1:  # калаш - авто
			shooting = true
			auto_shoot()
		elif actual_weapon_index == 0 or actual_weapon_index == 2:  # авп и дигл
			if can_shoot and not shooting:
				shoot()
	if event.is_action_released("shoot"):
		shooting = false
		%Head.get_node("AKShootSound").stop()
	if event.is_action_pressed("deagel"):
		set_deagel()
		
	if event.is_action_pressed("main_gun"):
		if actual_weapon_index == 2:
			if last_main_weapon == 0:
				set_awp()
			else:
				set_ak()
		elif actual_weapon_index == 0:
			set_ak()
		elif actual_weapon_index == 1:
			set_awp()
			
	if event.is_action_pressed("main_gun_no_switch"):
		if actual_weapon_index == 2:
			if last_main_weapon == 0:
				set_awp()
			else:
				set_ak()

func set_awp():
	can_shoot = false
	
	if actual_weapon_index == 0:
		return
		
	last_main_weapon = 1
	
	for node in %Deagel.get_children():
		node.queue_free()
	for node in %AK.get_children():
		node.queue_free()
	for node in %Weapon.get_children():
		node.queue_free()
		
	actual_weapon_index = 0
	var awp = weapons[actual_weapon_index].instantiate()
	%Weapon.add_child(awp)
	awp.name = "Meshy_AI__0310164825_texture2"
	
	$Head/blockbench_export.visible = true
	$Head/blockbench_export2.visible = true
	$Head/blockbench_export3.visible = false
	$Head/blockbench_export4.visible = false
	$Head/blockbench_export5.visible = false
	$Head/blockbench_export6.visible = false
	$Head/AWPAnimation.play("awp_gun")
	await $Head/AWPAnimation.animation_finished
	can_shoot = true

func set_ak():
	can_shoot = false
	
	if actual_weapon_index == 1:
		return
	last_main_weapon = 0
	for node in %Weapon.get_children():
		node.queue_free()
	for node in %Deagel.get_children():
		node.queue_free()
	for node in %AK.get_children():
		node.queue_free()
	actual_weapon_index = 1
	var ak = weapons[actual_weapon_index].instantiate()
	%AK.add_child(ak)
	
	$Head/blockbench_export.visible = false
	$Head/blockbench_export2.visible = false
	$Head/blockbench_export3.visible = true
	$Head/blockbench_export4.visible = true
	$Head/blockbench_export5.visible = false
	$Head/blockbench_export6.visible = false
	$Head/AKAnimation.play("gun")
	await $Head/AKAnimation.animation_finished
	can_shoot = true

func set_deagel():
	can_shoot = false
	
	if actual_weapon_index == 2:
		return
	last_main_weapon = actual_weapon_index
	for node in %Weapon.get_children():
		node.queue_free()
	for node in %AK.get_children():
		node.queue_free()
	for node in %Deagel.get_children():
		node.queue_free()
	actual_weapon_index = 2
	var deagel = weapons[actual_weapon_index].instantiate()
	%Deagel.add_child(deagel)
	deagel.name = "Meshy_AI__0414155015_texture2"
	
	$Head/blockbench_export.visible = false
	$Head/blockbench_export2.visible = false
	$Head/blockbench_export3.visible = false
	$Head/blockbench_export4.visible = false
	$Head/blockbench_export5.visible = true
	$Head/blockbench_export6.visible = true
	$Head/DEAGLEAnimation.play("deagle_gun")
	await $Head/DEAGLEAnimation.animation_finished
	can_shoot = true

func shoot():
	if not can_shoot:
		return
	can_shoot = false
	var weapon_at_shot = actual_weapon_index

	if %RayCast3D.is_colliding():
		var collider = %RayCast3D.get_collider()
		if collider.name == "t_head":
			print("HEADSHOT!")
			collider.get_node("T_HEADShootSound").play()
			await get_tree().create_timer(0.5).timeout
			collider.get_parent().queue_free()
		# звук
		else:
			collider.queue_free()

	match actual_weapon_index:
		0:
			%Weapon.apply_recoil()
			$Head/MuzzleFlashAWP.visible = true
			await get_tree().create_timer(0.05).timeout
			$Head/MuzzleFlashAWP.visible = false
			await get_tree().create_timer(1.15).timeout
		2:
			%Deagel.apply_recoil()
			$Head/MuzzleFlashDeagle.visible = true
			await get_tree().create_timer(0.05).timeout
			$Head/MuzzleFlashDeagle.visible = false
			await get_tree().create_timer(0.3).timeout
	if actual_weapon_index == weapon_at_shot:
		can_shoot = true

func auto_shoot():
	while shooting and actual_weapon_index == 1:
		if can_shoot:
			can_shoot = false

			if %RayCast3D.is_colliding():
				var collider = %RayCast3D.get_collider()
				if collider.name == "t_head":
					print("HEADSHOT!")
					collider.get_node("T_HEADShootSound").play()
					await get_tree().create_timer(0.5).timeout
					collider.get_parent().queue_free()
				# звук
				else:
					collider.queue_free()

			%AK.apply_recoil()
			%Head.get_node("AKShootSound").play()
			# мазл флеш
			$Head/MuzzleFlash.visible = true
			await get_tree().create_timer(0.05).timeout
			$Head/MuzzleFlash.visible = false
			await get_tree().create_timer(0.05).timeout
			if weapon_changed:
				weapon_changed = false
				return
			can_shoot = true
		else:
			await get_tree().process_frame

func get_current_weapon():
	match actual_weapon_index:
		0:
			if %Weapon.get_child_count() > 0:
				return %Weapon.get_child(0)
		1:
			if %AK.get_child_count() > 0:
				return %AK.get_child(0)
		2:
			if %Deagel.get_child_count() > 0:
				return %Deagel.get_child(0)
	return null

func _physics_process(delta): # Most things happen here.
	# Gravity
	if dynamic_gravity:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	if not is_on_floor() and gravity and gravity_enabled:
		velocity.y -= gravity * delta

	handle_jumping()

	var input_dir = Vector2.ZERO

	if not immobile: # Immobility works by interrupting user input, so other forces can still be applied to the player
		input_dir = Input.get_vector(controls.LEFT, controls.RIGHT, controls.FORWARD, controls.BACKWARD)

	handle_movement(delta, input_dir)

	handle_head_rotation()

	# The player is not able to stand up if the ceiling is too low
	low_ceiling = $CrouchCeilingDetection.is_colliding()

	handle_state(input_dir)
	if dynamic_fov: # This may be changed to an AnimationPlayer
		update_camera_fov()

	if view_bobbing:
		play_headbob_animation(input_dir)

	if jump_animation:
		play_jump_animation()

	update_debug_menu_per_tick()

	was_on_floor = is_on_floor() # This must always be at the end of physics_process

#endregion

#region Input Handling

func handle_jumping():
	if jumping_enabled:
		if continuous_jumping: # Hold down the jump button
			if Input.is_action_pressed(controls.JUMP) and is_on_floor() and !low_ceiling:
				if jump_animation:
					JUMP_ANIMATION.play("jump", 0.25)
				velocity.y += jump_velocity # Adding instead of setting so jumping on slopes works properly
		else:
			if Input.is_action_just_pressed(controls.JUMP) and is_on_floor() and !low_ceiling:
				if jump_animation:
					JUMP_ANIMATION.play("jump", 0.25)
				velocity.y = jump_velocity
				if is_on_floor():
					velocity.y = max(velocity.y, 0)


func handle_movement(delta, input_dir):
	var direction = input_dir.rotated(-HEAD.rotation.y)
	direction = Vector3(direction.x, 0, direction.y)

	if is_on_floor():
		# ground movement
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
	else:
		# air movement (bhop)
		if in_air_momentum:
			var wish_dir = direction.normalized()
			wish_dir.y = 0
			wish_dir = wish_dir.normalized()
			
			var wish_speed = direction.length() * speed
			wish_speed = min(wish_speed, max_speed)
			
			if abs(input_dir.y) > 0:
				wish_speed *= 0.3
			
			var current_speed = velocity.dot(wish_dir)
			var add_speed = wish_speed - current_speed
			
			if add_speed > 0:
				var accel_speed = air_control * wish_speed * delta
				accel_speed = min(accel_speed, add_speed)
				
				velocity.x += accel_speed * wish_dir.x
				velocity.z += accel_speed * wish_dir.z
			var horizontal_speed = Vector2(velocity.x, velocity.z).length()

			if horizontal_speed > max_speed:
				var limited = Vector2(velocity.x, velocity.z).normalized() * max_speed
				velocity.x = limited.x
				velocity.z = limited.y

	# 👇 TOHLE JE MUST
	move_and_slide()

func handle_head_rotation():
	if invert_camera_x_axis:
		HEAD.rotation_degrees.y -= mouseInput.x * mouse_sensitivity * -1
	else:
		HEAD.rotation_degrees.y -= mouseInput.x * mouse_sensitivity

	if invert_camera_y_axis:
		HEAD.rotation_degrees.x -= mouseInput.y * mouse_sensitivity * -1
	else:
		HEAD.rotation_degrees.x -= mouseInput.y * mouse_sensitivity

	if controller_support:
		var controller_view_rotation = Input.get_vector(controller_controls.LOOK_DOWN, controller_controls.LOOK_UP, controller_controls.LOOK_RIGHT, controller_controls.LOOK_LEFT) * look_sensitivity # These are inverted because of the nature of 3D rotation.
		if invert_camera_y_axis:
			HEAD.rotation.x += controller_view_rotation.x * -1
		else:
			HEAD.rotation.x += controller_view_rotation.x

		if invert_camera_x_axis:
			HEAD.rotation.y += controller_view_rotation.y * -1
		else:
			HEAD.rotation.y += controller_view_rotation.y

	mouseInput = Vector2(0,0)
	HEAD.rotation.x = clamp(HEAD.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func check_controls(): # If you add a control, you might want to add a check for it here.
	# The actions are being disabled so the engine doesn't halt the entire project in debug mode
	if !InputMap.has_action(controls.JUMP):
		push_error("No control mapped for jumping. Please add an input map control. Disabling jump.")
		jumping_enabled = false
	if !InputMap.has_action(controls.LEFT):
		push_error("No control mapped for move left. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.RIGHT):
		push_error("No control mapped for move right. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.FORWARD):
		push_error("No control mapped for move forward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.BACKWARD):
		push_error("No control mapped for move backward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.PAUSE):
		push_error("No control mapped for pause. Please add an input map control. Disabling pausing.")
		pausing_enabled = false
	if !InputMap.has_action(controls.CROUCH):
		push_error("No control mapped for crouch. Please add an input map control. Disabling crouching.")
		crouch_enabled = false
	if !InputMap.has_action(controls.SPRINT):
		push_error("No control mapped for sprint. Please add an input map control. Disabling sprinting.")
		sprint_enabled = false

#endregion

#region State Handling

func handle_state(moving):
	if sprint_enabled:
		if sprint_mode == 0:
			if Input.is_action_pressed(controls.SPRINT) and state != "crouching":
				if moving:
					if state != "sprinting":
						enter_sprint_state()
				else:
					if state == "sprinting":
						enter_normal_state()
			elif state == "sprinting":
				enter_normal_state()
		elif sprint_mode == 1:
			if moving:
				# If the player is holding sprint before moving, handle that scenario
				if Input.is_action_pressed(controls.SPRINT) and state == "normal":
					enter_sprint_state()
				if Input.is_action_just_pressed(controls.SPRINT):
					match state:
						"normal":
							enter_sprint_state()
						"sprinting":
							enter_normal_state()
			elif state == "sprinting":
				enter_normal_state()

	if crouch_enabled:
		if crouch_mode == 0:
			if Input.is_action_pressed(controls.CROUCH) and state != "sprinting":
				if state != "crouching":
					enter_crouch_state()
			elif state == "crouching" and !$CrouchCeilingDetection.is_colliding():
				enter_normal_state()
		elif crouch_mode == 1:
			if Input.is_action_just_pressed(controls.CROUCH):
				match state:
					"normal":
						enter_crouch_state()
					"crouching":
						if !$CrouchCeilingDetection.is_colliding():
							enter_normal_state()


# Any enter state function should only be called once when you want to enter that state, not every frame.
func enter_normal_state():
	#print("entering normal state")
	var prev_state = state
	if prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "normal"
	speed = base_speed

func enter_crouch_state():
	#print("entering crouch state")
	state = "crouching"
	speed = crouch_speed
	CROUCH_ANIMATION.play("crouch")

func enter_sprint_state():
	#print("entering sprint state")
	var prev_state = state
	if prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "sprinting"
	speed = sprint_speed

#endregion

#region Animation Handling

func initialize_animations():
	# Reset the camera position
	# If you want to change the default head height, change these animations.
	HEADBOB_ANIMATION.play("RESET")
	JUMP_ANIMATION.play("RESET")
	CROUCH_ANIMATION.play("RESET")

func play_headbob_animation(moving):
	if moving and is_on_floor():
		var use_headbob_animation : String
		match state:
			"normal","crouching":
				use_headbob_animation = "walk"
			"sprinting":
				use_headbob_animation = "sprint"

		var was_playing : bool = false
		if HEADBOB_ANIMATION.current_animation == use_headbob_animation:
			was_playing = true

		HEADBOB_ANIMATION.play(use_headbob_animation, 0.25)
		HEADBOB_ANIMATION.speed_scale = (current_speed / base_speed) * 1.75
		if !was_playing:
			HEADBOB_ANIMATION.seek(float(randi() % 2)) # Randomize the initial headbob direction
			# Let me explain that piece of code because it looks like it does the opposite of what it actually does.
			# The headbob animation has two starting positions. One is at 0 and the other is at 1.
			# randi() % 2 returns either 0 or 1, and so the animation randomly starts at one of the starting positions.
			# This code is extremely performant but it makes no sense.

	else:
		if HEADBOB_ANIMATION.current_animation == "sprint" or HEADBOB_ANIMATION.current_animation == "walk":
			HEADBOB_ANIMATION.speed_scale = 1
			HEADBOB_ANIMATION.play("RESET", 1)

func play_jump_animation():
	if !was_on_floor and is_on_floor(): # The player just landed
		var facing_direction : Vector3 = CAMERA.get_global_transform().basis.x
		var facing_direction_2D : Vector2 = Vector2(facing_direction.x, facing_direction.z).normalized()
		var velocity_2D : Vector2 = Vector2(velocity.x, velocity.z).normalized()

		# Compares velocity direction against the camera direction (via dot product) to determine which landing animation to play.
		var side_landed : int = round(velocity_2D.dot(facing_direction_2D))

		if side_landed > 0:
			JUMP_ANIMATION.play("land_right", 0.25)
		elif side_landed < 0:
			JUMP_ANIMATION.play("land_left", 0.25)
		else:
			JUMP_ANIMATION.play("land_center", 0.25)

#endregion

#region Debug Menu

func update_debug_menu_per_frame():
	$UserInterface/DebugPanel.add_property("FPS", Performance.get_monitor(Performance.TIME_FPS), 0)
	var status : String = state
	if !is_on_floor():
		status += " in the air"
	$UserInterface/DebugPanel.add_property("State", status, 4)


func update_debug_menu_per_tick():
	# Big thanks to github.com/LorenzoAncora for the concept of the improved debug values
	current_speed = Vector3.ZERO.distance_to(get_real_velocity())
	$UserInterface/DebugPanel.add_property("Speed", snappedf(current_speed, 0.001), 1)
	$UserInterface/DebugPanel.add_property("Target speed", speed, 2)
	var cv : Vector3 = get_real_velocity()
	var vd : Array[float] = [
		snappedf(cv.x, 0.001),
		snappedf(cv.y, 0.001),
		snappedf(cv.z, 0.001)
	]
	var readable_velocity : String = "X: " + str(vd[0]) + " Y: " + str(vd[1]) + " Z: " + str(vd[2])
	$UserInterface/DebugPanel.add_property("Velocity", readable_velocity, 3)


func _unhandled_input(event : InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseInput = event.relative
	# Toggle debug menu
	elif event is InputEventKey:
		if event.is_released():
			# Where we're going, we don't need InputMap
			if event.keycode == 4194338: # F7
				$UserInterface/DebugPanel.visible = !$UserInterface/DebugPanel.visible

#endregion

#region Misc Functions

func change_reticle(reticle): # Yup, this function is kinda strange
	if RETICLE:
		RETICLE.queue_free()

	RETICLE = load(reticle).instantiate()
	RETICLE.character = self
	$UserInterface.add_child(RETICLE)


func update_camera_fov():
	if state == "sprinting":
		CAMERA.fov = lerp(CAMERA.fov, 85.0, 0.3)
	else:
		CAMERA.fov = lerp(CAMERA.fov, 75.0, 0.3)

func handle_pausing():
	if Input.is_action_just_pressed(controls.PAUSE):
		# You may want another node to handle pausing, because this player may get paused too.
		match Input.mouse_mode:
			Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				#get_tree().paused = false
			Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				#get_tree().paused = false

#endregion
