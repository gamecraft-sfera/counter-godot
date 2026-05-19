extends Node3D

# ---------- SHOOT SETTINGS ----------

# ---------- STATE ----------
var shooting := false
var can_fire := true

# ---------- RECOIL ----------
var recoil_pos := Vector3.ZERO
var recoil_rot := Vector3.ZERO

var start_pos : Vector3
var start_rot : Vector3

# ---------- INIT ----------
func _ready():
	start_pos = position
	start_rot = rotation_degrees


# ---------- AUTO SHOOT LOOP ----------
func try_shoot():

	if not shooting:
		return

	if not can_fire:
		return

	can_fire = false

	shoot()
	apply_recoil()

	await get_tree().create_timer(0.05).timeout
	can_fire = true

	if shooting:
		try_shoot()

# ---------- SHOOT LOGIC ----------
func shoot():
	print("BANG") # потом сюда пуля / raycast

# ---------- RECOIL ----------
func apply_recoil():

	recoil_pos.z += 0.09
	recoil_rot.x += 0.8

	recoil_rot.z = randf_range(-2, 2)

# ---------- UPDATE ----------
func _process(delta):

	recoil_pos = recoil_pos.lerp(Vector3.ZERO, delta * 8.0)
	recoil_rot = recoil_rot.lerp(Vector3.ZERO, delta * 10.0)

	position = start_pos + recoil_pos
	rotation_degrees = start_rot + recoil_rot
