class_name HUDUtil
extends RefCounted

static func fmt_time(s: float) -> String:
	var t := int(s)
	if t >= 3600:
		return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
	return "%d:%02d" % [t / 60, t % 60]
