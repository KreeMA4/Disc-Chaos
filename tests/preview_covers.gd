extends Node
## Dev tool: renders a contact sheet of generated cover parts to tests/out/covers_sheet.png
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(3))
	await get_tree().process_frame
	var jobs: Array = []
	var picks := [3, 70, 130, 190, 250, 300, 370, 430, 15, 95, 222, 455]
	for i in picks.size():
		var t: Dictionary = Catalog.titles[picks[i]]
		jobs.append({"part": "front", "title": t, "edition": [0, 0, 3, 0, 2, 0, 0, 0, 0, 3, 0, 0][i], "rect": Rect2(10 + (i % 6) * 270, 10 + (i / 6) * 360, 260, 340)})
	var t0: Dictionary = Catalog.titles[picks[0]]
	jobs.append({"part": "back", "title": t0, "edition": 0, "rect": Rect2(1640, 10, 260, 340)})
	jobs.append({"part": "steel", "title": Catalog.titles[picks[1]], "edition": 1, "rect": Rect2(1640, 370, 260, 340)})
	for i in 8:
		jobs.append({"part": "spine", "title": Catalog.titles[picks[i]], "edition": [0, 1, 3, 2, 0, 0, 0, 0][i], "rect": Rect2(10, 740 + i * 34, 520, 30)})
	for i in 6:
		jobs.append({"part": "label", "title": Catalog.titles[picks[i]], "edition": 0, "disc": i % 2, "rect": Rect2(560 + i * 225, 740, 215, 215)})
	var img: Image = await Covers._render_page(jobs, Vector2i(1910, 1020))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	img.save_png("res://tests/out/covers_sheet.png")
	print("saved sheet")
	get_tree().quit()
