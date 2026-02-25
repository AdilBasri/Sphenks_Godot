extends Camera3D

var baslangic_transform: Transform3D
var kus_bakisi_mi: bool = false

func _ready() -> void:
	baslangic_transform = global_transform

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_gorunumu_degistir()

func _gorunumu_degistir() -> void:
	kus_bakisi_mi = not kus_bakisi_mi
	
	if kus_bakisi_mi:
		# --- KUŞ BAKIŞI MODU ---
		projection = PROJECTION_ORTHOGONAL
		size = 6.0 # Zoom ayarı (Daha net görmek için kıstım)
		
		# Tavanın altına in (Y: 3.5), tam aşağı bak (-90 derece)
		global_position = Vector3(0, 3.5, 0) 
		rotation_degrees = Vector3(-90, 0, 0)
		
	else:
		# --- NORMAL MOD ---
		projection = PROJECTION_PERSPECTIVE
		global_transform = baslangic_transform
