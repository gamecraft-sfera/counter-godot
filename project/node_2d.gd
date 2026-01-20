extends Node2D

var pocitadlo = 10



func _on_texture_button_pressed() -> void:
	pocitadlo = pocitadlo -1

	$Label.text = str(pocitadlo)

	print("pocitadlo: ", pocitadlo)
	#$TextureButton.visible = false
	if pocitadlo == 0:
		$Icon.visible = true
