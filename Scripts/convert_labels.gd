extends SceneTree

var new_font_path = "res://Assets/Fonts/Stencil Intellecta Trash Free.ttf"

func _init():
	print("--- Label to RichTextLabel Conversion Started ---")
	
	var files = _get_all_tscn_files("res://")
	var replaced_count = 0
	
	for file_path in files:
		if _hacky_text_replace(file_path):
			replaced_count += 1
			
	print("Converted scenes: ", replaced_count)
	print("--- Done ---")
	quit()

func _get_all_tscn_files(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				# Skip imported/addon/Godot internal folders
				if file_name in [".godot", "addons"]:
					file_name = dir.get_next()
					continue
					
				var full_path = path

				if full_path.ends_with("/"):
					full_path += file_name
				else:
					full_path += "/" + file_name
					
				if dir.current_is_dir():
					result.append_array(_get_all_tscn_files(full_path))
				elif file_name.ends_with(".tscn"):
					result.append(full_path)
			file_name = dir.get_next()
	return result

func _hacky_text_replace(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return false
	var text = f.get_as_text()
	f.close()
	
	var modified = false
	
	# Replace normal Labels
	if "type=\"Label\"" in text:
		# Convert type
		text = text.replace("type=\"Label\"", "type=\"RichTextLabel\"")
		modified = true
		
	# Now let's try to remove/replace incompatible properties
	if modified:
		# Godot 4 RichTextLabel has "text" property too. But no horizontal_alignment.
		# A proper regex or string manipulation to replace [theme_override_fonts/font] with [theme_override_fonts/normal_font]
		text = text.replace("theme_override_fonts/font", "theme_override_fonts/normal_font")
		text = text.replace("theme_override_colors/font_color", "theme_override_colors/default_color")
		text = text.replace("theme_override_colors/font_outline_color", "theme_override_colors/font_outline_color") # same
		text = text.replace("theme_override_font_sizes/font_size", "theme_override_font_sizes/normal_font_size")
		
		# Remove alignment properties safely by dropping them
		var lines = text.split("\n")
		var new_lines = []
		for line in lines:
			var trimmed = line.strip_edges()
			if trimmed.begins_with("horizontal_alignment") or trimmed.begins_with("vertical_alignment") or trimmed.begins_with("autowrap_mode") or trimmed.begins_with("clip_text") or trimmed.begins_with("text_overrun_behavior"):
				continue
			new_lines.append(line)
			
		text = "\n".join(new_lines)
		
	# Replace font paths everywhere just in case
	if "Stencil Intellecta Trash Free.ttf" in text or "Retro Shine.ttf" in text:
		text = text.replace("Stencil Intellecta Trash Free.ttf", "Stencil Intellecta Trash Free.ttf")
		text = text.replace("Retro Shine.ttf", "Stencil Intellecta Trash Free.ttf")
		modified = true
		
	if modified:
		var fw = FileAccess.open(path, FileAccess.WRITE)
		fw.store_string(text)
		fw.close()
		
	return modified
