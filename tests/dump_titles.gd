extends Node
func _ready() -> void:
	var f := FileAccess.open("res://tests/out/titles.txt", FileAccess.WRITE)
	for t in Catalog.titles:
		f.store_line("%s\t%s" % [t.gid, t.name])
	f.close()
	get_tree().quit()
