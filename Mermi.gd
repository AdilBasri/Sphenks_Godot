extends Area3D

var hiz = 80.0 
var yon = Vector3.ZERO
var omur = 3.0 

func baslat(yeni_yon: Vector3):
	yon = yeni_yon.normalized()
	look_at(global_position + yon) 

func _physics_process(delta):
	# Fizik döngüsünde hareket
	global_position += yon * hiz * delta
	
	omur -= delta
	if omur <= 0: queue_free()

func _on_body_entered(body):
	# Konsola neye çarptığını yazdır
	print("💥 MERMI ÇARPTI: ", body.name, " | Gruplar: ", body.get_groups())
	
	# 1. Duvar
	if body is StaticBody3D or body is CSGShape3D:
		queue_free()
	
	# 2. Düşman
	if body.is_in_group("Dusman"):
		print("   -> DÜŞMAN TESPİT EDİLDİ!")
		
		if body.has_method("hasar_al_efekt"):
			print("   -> Hasar fonksiyonu çağrılıyor...")
			body.hasar_al_efekt()
		else:
			print("   -> HATA: Düşmanda 'hasar_al_efekt' fonksiyonu yok!")
			
		queue_free()


# --- MERMİ AREA (HITBOX) TESPİTİ ---
func _on_area_entered(area):
	# Çarptığımız şey yarasanın "Hitbox"ı mı?
	# Hitbox'ın babası (parent) Yarasa scriptine sahip mi?
	var dusman = area.get_parent()
	
	if dusman and dusman.has_method("hasar_al_efekt"):
		print("🎯 MERMİ YARASA HITBOX'INA VURDU!")
		dusman.hasar_al_efekt()
		queue_free()
