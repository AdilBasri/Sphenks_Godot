extends RigidBody3D

var kan_havuzu_sahnesi = preload("res://Scenes/KanHavuzu.tscn")
var yere_degdi = false
var arabaya_kondu_mu = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 2
	add_to_group("KopanUzuv")
	
	body_entered.connect(_on_body_entered)
	
	# Doğar doğmaz kanlı (kırmızı) görünüme kavuşsun
	call_deferred("_renk_ayarla")

func _renk_ayarla():
	if has_node("MeshInstance3D"):
		var mesh_instance = $MeshInstance3D
		var mat = null
		
		if mesh_instance.material_override:
			mat = mesh_instance.material_override.duplicate()
		elif mesh_instance.mesh:
			var prim_mat = mesh_instance.mesh.get("material")
			var surf_mat = mesh_instance.mesh.surface_get_material(0) if mesh_instance.mesh.get_surface_count() > 0 else null
			
			if prim_mat:
				mat = prim_mat.duplicate()
			elif surf_mat:
				mat = surf_mat.duplicate()
		
		if mat == null:
			mat = StandardMaterial3D.new()
			
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(0.8, 0.0, 0.0)
			
		mesh_instance.material_override = mat

func _on_body_entered(body):
	if body is CollisionObject3D and body.get_collision_layer_value(8) and not arabaya_kondu_mu:
		var m = get_tree().current_scene.find_child("MezbahaManager", true, false)
		if m and m.wheelbarrow_pieces < 4:
			arabaya_kondu_mu = true
			m.piece_placed_in_wheelbarrow()
			call_deferred("_arabaya_yapistir", body)
			
	if yere_degdi: return
	
	# Sadece 1. collision layer'a (katmana) sahip olan objelere çarpınca 1 seferlik kan bırak
	if body is CollisionObject3D and body.get_collision_layer_value(1):
		yere_degdi = true
		_kan_lekesi_birak()

func _kan_lekesi_birak():
	if kan_havuzu_sahnesi:
		var kan = kan_havuzu_sahnesi.instantiate()
		get_tree().current_scene.add_child(kan)
		kan.global_position = global_position
		kan.position.y += 0.05
		kan.rotation.y = randf() * PI

func _arabaya_yapistir(hedef_body):
	freeze = true
	var old_gt = global_transform
	var p = get_parent()
	if p:
		p.remove_child(self)
	hedef_body.add_child(self)
	global_transform = old_gt

func get_etkilesim_yazisi() -> String:
	return ""

# --- TUTMA SİSTEMİ ---
func tutuldu():
	"""Oyuncu tarafından tutulduğunda çağrılır."""
	freeze = false
	yere_degdi = false
	gravity_scale = 0.0
	
	if arabaya_kondu_mu:
		arabaya_kondu_mu = false
		var m = get_tree().current_scene.find_child("MezbahaManager", true, false)
		if m:
			m.piece_removed_from_wheelbarrow()
	
	var scene = get_tree().current_scene
	if get_parent() != scene:
		var old_gt = global_transform
		get_parent().remove_child(self)
		scene.add_child(self)
		global_transform = old_gt

func birakildi():
	"""Oyuncu tarafından bırakıldığında/fırlatıldığında çağrılır."""
	yere_degdi = false
	gravity_scale = 1.0

# --- YEME SİSTEMİ (Violent Bite) ---
var orijinal_scale: Vector3 = Vector3.ONE
var orijinal_rotation: Vector3 = Vector3.ZERO
var toplam_isirma: int = 0
var max_isirma: int = 5  # Kaç ısırıkta bitecek

func yenmeye_basla(_sure: float):
	"""İlk çağrı — orijinal değerleri kaydet."""
	orijinal_scale = scale
	orijinal_rotation = rotation
	toplam_isirma = 0
	print("🦴 Uzuv yenmeye hazır. Max ısırma: ", max_isirma)

func isir() -> bool:
	"""Her ısırıkta çağrılır. Anlık küçültme + rastgele sarsma.
	Bittiyse true döner."""
	toplam_isirma += 1
	
	# --- ANLİK SCALE AZALTMA (Chunk) ---
	var azaltma = orijinal_scale * (1.0 / float(max_isirma))
	# Non-uniform squish: rastgele eksen abartma
	var squish = Vector3(
		randf_range(0.7, 1.3),
		randf_range(0.5, 1.0),
		randf_range(0.7, 1.3)
	)
	scale -= azaltma * squish
	# Negatif olmayı engelle
	scale = scale.clamp(Vector3(0.02, 0.02, 0.02), orijinal_scale)
	
	# --- RASTGELE ROTASYON JOLTU (Et koparma kuvveti) ---
	var jolt_intensity = 0.3 + (float(toplam_isirma) / float(max_isirma)) * 0.4
	rotation += Vector3(
		randf_range(-jolt_intensity, jolt_intensity),
		randf_range(-jolt_intensity, jolt_intensity),
		randf_range(-jolt_intensity, jolt_intensity)
	)
	
	# Mini geri-tepme tweeni (ısırık hissi — anlık büzülme sonra hafif geri)
	var bite_tween = create_tween()
	var gecici_scale = scale * Vector3(0.7, 1.2, 0.7)  # Anlık squish
	bite_tween.tween_property(self, "scale", gecici_scale, 0.05)
	bite_tween.tween_property(self, "scale", scale, 0.1).set_trans(Tween.TRANS_ELASTIC)
	
	print("🩸 ISIRIK #%d — Scale: %s" % [toplam_isirma, str(scale)])
	
	# Bitti mi?
	return toplam_isirma >= max_isirma

func yenme_iptal():
	"""Yeme iptal edilirse orijinal boyut ve rotasyona geri dön."""
	var geri_tween = create_tween()
	geri_tween.set_parallel(true)
	geri_tween.tween_property(self, "scale", orijinal_scale, 0.3).set_trans(Tween.TRANS_CUBIC)
	geri_tween.tween_property(self, "rotation", orijinal_rotation, 0.3).set_trans(Tween.TRANS_CUBIC)
	toplam_isirma = 0

func yenme_ilerlemesi() -> float:
	"""Ne kadar yendiğini 0.0-1.0 olarak döner (frenzy hesabı için)."""
	if max_isirma <= 0: return 0.0
	return clamp(float(toplam_isirma) / float(max_isirma), 0.0, 1.0)
