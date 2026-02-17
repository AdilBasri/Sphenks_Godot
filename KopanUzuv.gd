extends RigidBody3D

var kan_havuzu_sahnesi = preload("res://KanHavuzu.tscn")
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

# --- YEME SİSTEMİ ---
var yenme_tween: Tween = null
var orijinal_scale: Vector3 = Vector3.ONE

func yenmeye_basla(sure: float):
	"""Oyuncu tarafından yenmeye başlandığında çağrılır.
	Mesh non-uniform küçülür (ısırık simülasyonu)."""
	orijinal_scale = scale
	if yenme_tween and yenme_tween.is_valid():
		yenme_tween.kill()
	
	yenme_tween = create_tween()
	var adim_suresi = sure / 4.0
	
	# 1. Isırık — hafif squish
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * Vector3(0.9, 0.7, 0.85), adim_suresi * 0.5).set_trans(Tween.TRANS_BACK)
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * 0.8, adim_suresi * 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# 2. Isırık — daha belirgin
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * Vector3(0.5, 0.7, 0.55), adim_suresi * 0.5).set_trans(Tween.TRANS_BACK)
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * 0.6, adim_suresi * 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# 3. Isırık — çok küçülüyor
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * Vector3(0.25, 0.4, 0.3), adim_suresi * 0.5).set_trans(Tween.TRANS_BACK)
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * 0.35, adim_suresi * 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# 4. Son lokma — neredeyse yok
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * Vector3(0.05, 0.15, 0.08), adim_suresi * 0.5).set_trans(Tween.TRANS_BACK)
	yenme_tween.tween_property(self, "scale",
		orijinal_scale * 0.1, adim_suresi * 0.5).set_trans(Tween.TRANS_CUBIC)

func yenme_iptal():
	"""Yeme iptal edilirse orijinal boyuta geri dön."""
	if yenme_tween and yenme_tween.is_valid():
		yenme_tween.kill()
	
	var geri_tween = create_tween()
	geri_tween.tween_property(self, "scale", orijinal_scale, 0.3).set_trans(Tween.TRANS_CUBIC)
