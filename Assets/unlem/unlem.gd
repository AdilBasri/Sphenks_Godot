extends Node3D

@export var outline_color: Color = Color.WHITE
@export var outline_thickness: float = 0.03

var outline_shader_code: String = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float outline_thickness = 0.03;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"""

func _ready():
	# Dış çizgi için shader'ı oluştur
	var shader = Shader.new()
	shader.code = outline_shader_code
	
	# Shader materyalini oluştur ve renk/kalınlık ayarlarını yap
	var outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	outline_material.set_shader_parameter("outline_color", outline_color)
	outline_material.set_shader_parameter("outline_thickness", outline_thickness)
	
	# Modelleri bul ve dış çizgiyi ekle
	_apply_outline_to_children(self, outline_material)

func _apply_outline_to_children(node: Node, material: Material):
	if node is MeshInstance3D:
		# Senin orijinal materyaline dokunmaz, rengini değiştirmez.
		# Sadece dışına eklenti olarak kenarlık katmanı (overlay) atar.
		node.material_overlay = material
		
	for child in node.get_children():
		_apply_outline_to_children(child, material)
