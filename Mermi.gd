extends Area3D

var hiz = 80.0 
var yon = Vector3.ZERO
var omur = 3.0 

func baslat(yeni_yon: Vector3):
	yon = yeni_yon.normalized()
	look_at(global_position + yon) 

func _physics_process(delta):
	# Fizik döngüsünde hareket (Jitter'ı önler)
	global_position += yon * hiz * delta
	
	omur -= delta
	if omur <= 0: queue_free()

func _on_body_entered(body):
	# 1. Duvar veya Zemin
	if body is StaticBody3D or body is CSGShape3D:
		# İstersen buraya kıvılcım efekti instance edebilirsin
		queue_free()
	
	# 2. Düşman (Boss veya Yarasa)
	if body.is_in_group("Dusman"):
		# Boss için (Sadece Efekt, Ölmez)
		if body.has_method("hasar_al"):
			body.hasar_al(0) # 0 hasar gönderiyoruz ki sadece kızarsın
			# Buraya istersen puan ekleme kodu koyabilirsin:
			# if GameManager: GameManager.altin_ekle(1)
		
		# Yarasa/Pyro Düşmanı için (Ölür)
		if body.has_method("hasar_al_efekt"):
			body.hasar_al_efekt()
			
		queue_free()
