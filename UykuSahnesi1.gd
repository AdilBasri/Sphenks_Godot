extends Node3D

@onready var chest = $Chest
@onready var oyuncu = $Oyuncu

var sandik_hedef_z = -26.5
var mesafe_kapanacak = false
var kapanis_basladi = false

class ChestInteract extends StaticBody3D:
	var ana_sahne: Node = null
	
	func get_etkilesim_yazisi() -> String:
		if ana_sahne and ana_sahne.mesafe_kapanacak and not ana_sahne.kapanis_basladi:
			return "[E] Sandığı Aç"
		return ""

	func interact(oyuncu_node):
		if ana_sahne and ana_sahne.mesafe_kapanacak and not ana_sahne.kapanis_basladi:
			ana_sahne.sandik_acildi()

func _ready():
	# Çarpışma ve Etkileşim için gövde ekle
	var static_body = ChestInteract.new()
	static_body.ana_sahne = self
	static_body.set_collision_layer(1)
	static_body.set_collision_mask(1)
	chest.add_child(static_body)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5) # Sandık boyutuna uygun
	collision.shape = shape
	collision.position = Vector3(0, 0.75, 0)
	static_body.add_child(collision)

func _process(delta):
	if kapanis_basladi: return
	
	var dist = oyuncu.global_position.distance_to(chest.global_position)
	
	if not mesafe_kapanacak:
		if dist < 6.0 and chest.position.z > sandik_hedef_z:
			var speed = 4.5
			if Input.is_action_pressed("kosma"):
				speed = 7.5
				
			chest.position.z -= speed * delta
			if chest.position.z <= sandik_hedef_z:
				chest.position.z = sandik_hedef_z
				mesafe_kapanacak = true
		elif dist <= 3.5 and chest.position.z <= sandik_hedef_z:
			mesafe_kapanacak = true

func sandik_acildi():
	if kapanis_basladi: return
	kapanis_basladi = true
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var cr = ColorRect.new()
	cr.color = Color(1, 1, 1, 0)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(cr)
	
	var t = create_tween()
	t.tween_property(cr, "color", Color(1, 1, 1, 1), 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(self._sahneyi_bitir)

func _sahneyi_bitir():
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("odaya_don_ve_level_atla"):
		level_manager.odaya_don_ve_level_atla()
	else:
		print("Hata: LevelManager bulunamadı!")
