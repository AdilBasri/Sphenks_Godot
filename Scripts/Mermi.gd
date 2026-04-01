extends Area3D

var hiz = 50.0 # Hızı çok artırma ki fizik motoru çarpışmayı kaçırmasın
var yon = Vector3.ZERO
var omur = 3.0 
var carpti_mi = false 

func baslat(yeni_yon: Vector3):
	yon = yeni_yon.normalized()
	look_at(global_position + yon) 

func _ready():
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	await get_tree().create_timer(omur).timeout
	queue_free()

func _physics_process(delta):
	global_position += yon * hiz * delta

func _on_body_entered(body):
	# Düşman veya boss gövdesine çarptığında mermiyi yok etme (Hitbox halletsin)
	if body.is_in_group("Dusman") or body.is_in_group("boss"):
		return
	
	# Eğer ebeveynlerinden biri düşmansa yine yok etme
	var p = body.get_parent()
	while p:
		if p.is_in_group("Dusman") or p.is_in_group("boss"):
			return
		p = p.get_parent()

	if body is StaticBody3D or body is CSGShape3D:
		queue_free()

func _on_area_entered(area):
	if carpti_mi: return 
	
	# --- BOSS HITBOX KONTROLÜ ---
	if area.is_in_group("BossHitbox"):
		var boss = _boss_scriptini_bul(area)
		if boss and boss.has_method("mermi_hasari_al"):
			var boss_oldu = boss.get("oldu_mu")
			if boss_oldu == true: return
			carpti_mi = true
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
			boss.mermi_hasari_al(global_position, yon)
			queue_free()
			return
	
	if area.has_meta("Bolge"): 
		var dusman = _dusman_scriptini_bul(area)
		if dusman and dusman.suanki_durum != 99: # Sadece hayattaki düşmana çarp
			carpti_mi = true
			set_deferred("monitoring", false)
			set_deferred("monitorable", false) # Mermiyi tamamen etkisizleştir
			dusman.hasar_al_bolgesel(area.get_meta("Bolge"))
			queue_free()

func _dusman_scriptini_bul(baslangic_node):
	var aday = baslangic_node
	var deneme_sayisi = 0
	while aday and deneme_sayisi < 15:
		if aday.has_method("hasar_al_bolgesel"): return aday
		aday = aday.get_parent()
		deneme_sayisi += 1
	return null

func _boss_scriptini_bul(baslangic_node):
	var aday = baslangic_node
	var deneme_sayisi = 0
	while aday and deneme_sayisi < 15:
		if aday.has_method("mermi_hasari_al"): return aday
		aday = aday.get_parent()
		deneme_sayisi += 1
	return null
