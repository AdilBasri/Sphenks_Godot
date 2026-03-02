extends RigidBody3D

var kan_havuzu_sahnesi = preload("res://Scenes/KanHavuzu.tscn")
var yere_degdi = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 2
	add_to_group("KopanUzuv")
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if yere_degdi: return
	
	if body is StaticBody3D or body is CSGShape3D:
		yere_degdi = true
		freeze = true
		
		if kan_havuzu_sahnesi:
			var kan = kan_havuzu_sahnesi.instantiate()
			get_tree().current_scene.add_child(kan)
			kan.global_position = global_position
			kan.position.y += 0.05
			kan.rotation.y = randf() * PI 

func get_etkilesim_yazisi() -> String:
	if gravity_scale == 0.0: # Held by player
		return ""
	return "[E] Uzuvu Al"

# --- TUTMA SİSTEMİ ---
func tutuldu():
	"""Oyuncu tarafından tutulduğunda çağrılır."""
	freeze = false
	yere_degdi = false
	gravity_scale = 0.0

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
