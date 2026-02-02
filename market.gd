extends Node3D

# --- REFERANSLAR ---
@onready var oyuncu_eli = $OyuncuEli 
@onready var giris_sensoru = $GirisSensoru
@onready var altin_sahnesi = preload("res://Altin.tscn")
@export var market_kapisi: Node3D 

# --- EL POZİSYONU (Senin Ayarların) ---
# Elin kameraya göre konumu
var hedef_pozisyon = Vector3(0.35, -0.8, -2.5) 
var baslangic_pozisyonu = Vector3(0.35, -3.0, -2.5) 
var hedef_rotasyon = Vector3(0.0, 0.0, 0.0) 

var iceride_mi: bool = false

func _ready():
	if oyuncu_eli: 
		oyuncu_eli.visible = false
		# Fiziği tamamen yok ediyoruz, sadece görüntü kalıyor
		oyuncu_eli.collision_layer = 0
		oyuncu_eli.collision_mask = 0
	
	if giris_sensoru:
		giris_sensoru.body_entered.connect(_on_giris_sensoru_body_entered)

func _process(delta):
	# Lag önleme: Eli her karede zorla ebeveynine (kameraya) sıfırlıyoruz
	pass

func _on_giris_sensoru_body_entered(body):
	if iceride_mi: return
	if body.name == "Oyuncu" or body is CharacterBody3D:
		var kamera = body.find_child("Camera3D", true, false)
		if not kamera: kamera = body 
		if kamera:
			iceride_mi = true
			call_deferred("eli_kameraya_tasi", kamera)

func eli_kameraya_tasi(yeni_ebeveyn):
	if oyuncu_eli.get_parent():
		oyuncu_eli.get_parent().remove_child(oyuncu_eli)
	yeni_ebeveyn.add_child(oyuncu_eli)
	
	oyuncu_eli.set_physics_process(false) 
	
	# Konum Sıfırlama
	oyuncu_eli.transform = Transform3D.IDENTITY
	oyuncu_eli.visible = true
	oyuncu_eli.position = baslangic_pozisyonu
	oyuncu_eli.rotation_degrees = hedef_rotasyon
	
	# El Çıkma Animasyonu
	var tween = create_tween()
	tween.tween_property(oyuncu_eli, "position", hedef_pozisyon, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(altin_ver.bind(5))
	
	# Kapı Kapatma
	if market_kapisi:
		if market_kapisi.has_method("kilitle"): market_kapisi.kilitle()
		var kapi_tween = create_tween()
		kapi_tween.tween_property(market_kapisi, "rotation_degrees:y", 0.0, 1.0)

func altin_ver(adet):
	print(str(adet) + " Altın veriliyor...")
	
	for i in range(adet):
		var yeni_altin = altin_sahnesi.instantiate()
		oyuncu_eli.add_child(yeni_altin)
		
		# --- KRİTİK AYARLAR ---
		# 1. Fiziği ve Çarpışmayı TAMAMEN KAPAT
		yeni_altin.freeze = true 
		yeni_altin.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		yeni_altin.collision_layer = 0 
		yeni_altin.collision_mask = 0 
		
		# 2. Top Level KAPALI olmalı (Elin çocuğu olsun)
		yeni_altin.top_level = false 
		
		# --- SABİT YEREL KONUMLAR ---
		# Artık GlobalPosition kullanmıyoruz. Sadece "Elin Merkezi"ne göre konuşuyoruz.
		# (0,0,0) noktası elin tam ortasıdır.
		
		# Başlangıç: Elin 30cm yukarısı (Y: 0.3)
		var local_baslangic = Vector3(randf_range(-0.05, 0.05), 0.3, randf_range(-0.05, 0.05))
		
		# Bitiş: Elin avuç içi (Y: -0.1)
		# Z değeriyle oynayarak ileri/geri ayarı yapabilirsin
		var local_bitis = Vector3(randf_range(-0.02, 0.02), -0.1, randf_range(-0.02, 0.02))
		
		# Pozisyonu ata
		yeni_altin.position = local_baslangic
		yeni_altin.rotation_degrees = Vector3(randf_range(0,360), randf_range(0,360), randf_range(0,360))
		yeni_altin.scale = Vector3(1, 1, 1)
		
		# Animasyon (Local Position üzerinde çalışır)
		var tween = create_tween()
		tween.tween_property(yeni_altin, "position", local_bitis, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		await get_tree().create_timer(0.15).timeout
