extends Node3D

var recoil_pos := Vector3.ZERO
var recoil_rot := Vector3.ZERO
var start_pos : Vector3
var start_rot : Vector3

func _ready():
	start_pos = position
	start_rot = rotation_degrees

func apply_recoil():
	recoil_pos.z += 0.3
	recoil_rot.x += -4
	recoil_rot.z = randf_range(-2, 2)

func _process(delta):
	recoil_pos = recoil_pos.lerp(Vector3.ZERO, delta * 5.0)
	recoil_rot = recoil_rot.lerp(Vector3.ZERO, delta * 7.0)
	position = start_pos + recoil_pos
	rotation_degrees = start_rot + recoil_rot
