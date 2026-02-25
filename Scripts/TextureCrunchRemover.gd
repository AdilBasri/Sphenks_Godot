@tool
# ============================================================
#   TEXTURE CRUNCH UN-APPLIER — Revert Degraded Meshes
#   EditorScript — Run via: Script Editor → File → Run
# ============================================================
#   HOW TO USE:
#   1. Open the scene you want to remove the shader from (yenisahne.tscn)
#   2. Open this script in the Script Editor
#   3. Click File → Run (or press Ctrl+Shift+X)
#   4. Every MeshInstance3D in the scene using texture_crunch gets cleared.
# ============================================================

extends EditorScript

const CRUNCH_SHADER_PATH := "res://Materials_Shaders/texture_crunch.gdshader"

var _processed := 0
var _errors := 0

func _run() -> void:
	print("=" .repeat(60))
	print("[TextureCrunchRemover] Starting texture restoration pass...")
	print("=" .repeat(60))

	# Load the crunch shader to identify it
	var shader : Shader = load(CRUNCH_SHADER_PATH)
	if shader == null:
		push_error("[TextureCrunchRemover] ERROR: Cannot load shader at: " + CRUNCH_SHADER_PATH)
		return

	# Get the edited scene root
	var scene_root : Node = get_scene()
	if scene_root == null:
		push_error("[TextureCrunchRemover] ERROR: No scene is currently open in the editor.")
		return

	print("[TextureCrunchRemover] Scene root: " + scene_root.name)
	print("[TextureCrunchRemover] Scanning all MeshInstance3D nodes to strip shader...")
	print("")

	# Recursively process all nodes
	_process_node(scene_root, shader)

	# Summary
	print("")
	print("=" .repeat(60))
	print("[TextureCrunchRemover] DONE!")
	print("  Restored : " + str(_processed) + " surface(s)")
	print("  Errors    : " + str(_errors))
	print("=" .repeat(60))
	print("Remember to save the scene to persist the changes!")

func _process_node(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D:
		_remove_crunch_from_mesh(node as MeshInstance3D, shader)

	for child in node.get_children():
		_process_node(child, shader)

func _remove_crunch_from_mesh(mesh_instance: MeshInstance3D, shader: Shader) -> void:
	if mesh_instance.mesh == null:
		return

	var surface_count := mesh_instance.mesh.get_surface_count()
	var modified = false

	for surface_idx in range(surface_count):
		# Get the current material override for this surface
		var current_mat := mesh_instance.get_surface_override_material(surface_idx)

		if current_mat is ShaderMaterial:
			var sm := current_mat as ShaderMaterial
			if sm.shader != null and sm.shader == shader:
				# It is the crunch shader! We will restore a basic standard material
				# if we can find an albedo texture, else just remove the override entirely.
				
				var original_texture = sm.get_shader_parameter("albedo_texture")
				if original_texture and original_texture is Texture2D:
					var std_mat := StandardMaterial3D.new()
					std_mat.albedo_texture = original_texture
					mesh_instance.set_surface_override_material(surface_idx, std_mat)
					print("    Restored albedo texture on " + mesh_instance.name + " (" + str(surface_idx) + ")")
				else:
					# Just remove the override
					mesh_instance.set_surface_override_material(surface_idx, null)
					print("    Cleared override material on " + mesh_instance.name + " (" + str(surface_idx) + ")")
				_processed += 1
