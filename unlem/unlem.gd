extends Node3D

@export var outline_color: Color = Color.WHITE
@export var outline_thickness: float = 0.03

var outline_shader_code: String = """
shader_type spatial;
render_mode unshaded, cull_front;

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
	# Shader'ı oluştur
	var shader = Shader.new()
	shader.code = outline_shader_code
	
	# Shader materyalini oluştur ve parametreleri ata
	var outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	outline_material.set_shader_parameter("outline_color", outline_color)
	outline_material.set_shader_parameter("outline_thickness", outline_thickness)
	
	# Bu düğümün altındaki tüm MeshInstance3D'leri bul ve materyali Overlay olarak ekle
	_apply_outline_to_children(self, outline_material)

func _apply_outline_to_children(node: Node, material: Material):
	# Eğer düğüm bir 3D model ise kenarlığı dış kaplama (overlay) olarak ekle
	if node is MeshInstance3D:
		node.material_overlay = material
		
	# Tüm alt düğümleri (children) taramaya devam et
	for child in node.get_children():
		_apply_outline_to_children(child, material)
