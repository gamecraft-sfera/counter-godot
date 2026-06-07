extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.add_theme_constant_override("outline_size", 2)
	$Label.add_theme_color_override("font_outline_color", Color.BLACK)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
