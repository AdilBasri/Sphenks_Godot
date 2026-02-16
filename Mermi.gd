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
	if body is StaticBody3D or body is CSGShape3D:
		queue_free()

func _on_area_entered(area):
	if carpti_mi: return 
	
	if area.has_meta("Bolge"): 
		var dusman = _dusman_scriptini_bul(area)
		if dusman:
			carpti_mi = true
			# --- KRİTİK: Çift kopmayı engelleyen satır ---
			set_deferred("monitoring", false) 
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
