extends Area3D

@export var target_position: Vector3
@export var speed: float = 1.0 

func _physics_process(delta: float) -> void:
	var direction:= target_position - global_position
	direction = direction.normalized()
	global_position = global_position + (direction * speed * delta)
	
	if global_position.distance_to(target_position) <= 1.0:
		queue_free()
