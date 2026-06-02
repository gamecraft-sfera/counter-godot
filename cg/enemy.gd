extends CharacterBody3D

@export var player: CharacterBody3D


func _on_timer_timeout() -> void:
	var projectile = load("res://enemy_attack.tscn").instantiate()
	projectile.target_position = player.global_position
	add_child(projectile)
	
	

@onready var sound = $t_head/T_HEADShootSound

func _physics_process(delta):

	if is_on_wall():
		sound.play()

func die():
	visible = false
	await get_tree().create_timer(2.0).timeout
	visible = true
