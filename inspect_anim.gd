extends SceneTree

func _init():
	var anim_res = load("res://yürüme.res") as Animation
	if anim_res:
		print("--- YURUME.RES TRACKS ---")
		for i in range(anim_res.get_track_count()):
			var path = str(anim_res.track_get_path(i))
			print("Track " + str(i) + ": " + path)
			
			if path.ends_with(":position"):
				print("  -> KEY COUNT: " + str(anim_res.track_get_key_count(i)))
				if anim_res.track_get_key_count(i) > 0:
					print("  -> FIRST KEY Z: " + str(anim_res.track_get_key_value(i, 0).z))
					print("  -> LAST KEY Z:  " + str(anim_res.track_get_key_value(i, anim_res.track_get_key_count(i)-1).z))
	else:
		print("yürüme.res failed to load")
	quit()
