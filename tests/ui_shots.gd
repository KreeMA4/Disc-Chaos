extends Node
## Dev tool: screenshot every menu screen. godot --path . -- --ui-shots
func _ready() -> void:
	get_tree().create_timer(200).timeout.connect(func(): get_tree().quit(3))
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
	main.start_solo(2)
	await Game.level_loaded
	await get_tree().create_timer(0.5).timeout
	main.close_overlay()
	main.overlay("pause")
	await get_tree().create_timer(0.5).timeout
	await _shot("pause")
	main.close_overlay()
	main.overlay("emotes")
	await get_tree().create_timer(0.5).timeout
	await _shot("emotes")
	main.close_overlay()
	main.overlay("results", {"time": 1534.0, "par": 2040.0, "stars": 3, "products": 150, "level": Levels.get_def(2),
		"stats": {"1": {"name": "Sir Sprout", "sorted": 61, "matched": 70, "mistakes": 3, "slips": 4, "distance": 812.0},
			"2": {"name": "Turbo Pickle", "sorted": 52, "matched": 58, "mistakes": 6, "slips": 9, "distance": 1040.0}}})
	await get_tree().create_timer(1.6).timeout
	await _shot("results")
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/ui_%s.png" % n)
	print("shot ", n)
