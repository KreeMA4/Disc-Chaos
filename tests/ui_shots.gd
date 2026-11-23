extends Node
## Dev tool: screenshot every menu screen. godot --path . -- --ui-shots
func _ready() -> void:
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(3))
	await get_tree().create_timer(0.6).timeout
	var main = Game.main
	for s in ["levels", "customize", "settings", "join", "credits"]:
		main.go(s, "solo" if s == "levels" else null)
		await get_tree().create_timer(0.8).timeout
		await _shot(s)
	Net.host()
	main.go("lobby")
	await get_tree().create_timer(1.0).timeout
	await _shot("lobby")
	Net.leave()
	main.go("customize")
	await get_tree().create_timer(0.5).timeout
	main.current._randomize_all()
	await get_tree().create_timer(1.6).timeout
	await _shot("customize_random")
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/ui_%s.png" % n)
	print("shot ", n)
