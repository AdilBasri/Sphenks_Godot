@tool
# ============================================================
#   TEXTURE CRUNCH APPLIER — Batch Material Degrader
#   EditorScript — Run via: Script Editor → File → Run
# ============================================================
#   HOW TO USE:
#   1. Open the scene you want to degrade (e.g. Sphenks.tscn)
#   2. Open this script in the Script Editor
#   3. Click File → Run (or press Ctrl+Shift+X)
#   4. Every MeshInstance3D in the scene gets the crunch shader
#   5. The original albedo texture is preserved inside the shader
#
#   The script skips nodes that already have texture_crunch.gdshader
#   applied, so it's safe to run multiple times.
# ============================================================

extends EditorScript

const CRUNCH_SHADER_PATH := "res://Materials_Shaders/texture_crunch.gdshader"

var _processed := 0
var _skipped := 0
var _errors := 0

func _run() -> void:
	print("=" .repeat(60))
	print("[TextureCrunchApplier] Starting texture degradation pass...")
	print("=" .repeat(60))

	# Load the crunch shader
	var shader : Shader = load(CRUNCH_SHADER_PATH)
	if shader == null:
		push_error("[TextureCrunchApplier] ERROR: Cannot load shader at: " + CRUNCH_SHADER_PATH)
		push_error("Make sure texture_crunch.gdshader is in the project root.")
		return

	# Get the edited scene root
	var scene_root : Node = get_scene()
	if scene_root == null:
		push_error("[TextureCrunchApplier] ERROR: No scene is currently open in the editor.")
		return

	print("[TextureCrunchApplier] Scene root: " + scene_root.name)
	print("[TextureCrunchApplier] Scanning all MeshInstance3D nodes...")
	print("")

	# Recursively process all nodes
	_process_node(scene_root, shader)

	# Summary
	print("")
	print("=" .repeat(60))
	print("[TextureCrunchApplier] DONE!")
	print("  Processed : " + str(_processed) + " surface(s)")
	print("  Skipped   : " + str(_skipped) + " (already crunched)")
	print("  Errors    : " + str(_errors))
	print("=" .repeat(60))
	print("Remember to save the scene to persist the changes!")


func _process_node(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D:
		_apply_crunch_to_mesh(node as MeshInstance3D, shader)

	for child in node.get_children():
		_process_node(child, shader)


func _apply_crunch_to_mesh(mesh_instance: MeshInstance3D, shader: Shader) -> void:
	if mesh_instance.mesh == null:
		print("  [SKIP] " + mesh_instance.name + " — no mesh data")
		_skipped += 1
		return

	var surface_count := mesh_instance.mesh.get_surface_count()
	if surface_count == 0:
		print("  [SKIP] " + mesh_instance.name + " — zero surfaces")
		_skipped += 1
		return

	print("  [MESH] " + mesh_instance.name + " (" + str(surface_count) + " surface(s))")

	for surface_idx in range(surface_count):
		# Get the current material for this surface
		var current_mat : Material = _get_surface_material(mesh_instance, surface_idx)

		# Skip if already crunched
		if current_mat is ShaderMaterial:
			var sm := current_mat as ShaderMaterial
			if sm.shader != null and sm.shader == shader:
				print("    Surface " + str(surface_idx) + ": Already crunched — skip")
				_skipped += 1
				continue

		# Create a fresh ShaderMaterial with the crunch shader
		var crunch_mat := ShaderMaterial.new()
		crunch_mat.shader = shader

		# Try to preserve the original albedo texture
		var original_texture : Texture2D = _extract_albedo_texture(current_mat)
		if original_texture != null:
			crunch_mat.set_shader_parameter("albedo_texture", original_texture)
			print("    Surface " + str(surface_idx) + ": OK — preserved albedo texture: " + original_texture.resource_path)
		else:
			# No texture — set a subtle tint based on original material color
			var original_color := _extract_albedo_color(current_mat)
			crunch_mat.set_shader_parameter("albedo_tint", original_color)
			print("    Surface " + str(surface_idx) + ": OK — no texture, using color tint")

		# Apply shader material to the surface override slot
		mesh_instance.set_surface_override_material(surface_idx, crunch_mat)
		_processed += 1


func _get_surface_material(mesh_instance: MeshInstance3D, surface_idx: int) -> Material:
	# Check surface override first, then fall back to mesh's built-in material
	var override_mat := mesh_instance.get_surface_override_material(surface_idx)
	if override_mat != null:
		return override_mat

	if mesh_instance.mesh != null:
		return mesh_instance.mesh.surface_get_material(surface_idx)

	return null


func _extract_albedo_texture(mat: Material) -> Texture2D:
	if mat == null:
		return null

	# Standard BaseMaterial3D / StandardMaterial3D
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		return bm.albedo_texture

	# ShaderMaterial — look for common uniform names
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		# Try common texture uniform names
		for uniform_name in ["albedo_texture", "texture_albedo", "albedo", "diffuse_texture", "base_color_texture"]:
			var val = sm.get_shader_parameter(uniform_name)
			if val is Texture2D:
				return val as Texture2D

	return null


func _extract_albedo_color(mat: Material) -> Color:
	if mat == null:
		return Color.WHITE

	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_color

	return Color.WHITE
