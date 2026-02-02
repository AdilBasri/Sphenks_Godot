extends Node3D

# --- REFERANSLAR ---
@onready var oyuncu_kolu = $OyuncuEli 
@onready var giris_sensoru = $GirisSensoru
@onready var altin_sahnesi = preload("res://Altin.tscn")
@export var market_kapisi: Node3D 

# EDİTÖRDEN ATANACAKLAR
@export var hedef_marketci: Node3D # Altınların gideceği yer (Marketçi/Kasa)
@export var kese_sprite: Sprite3D   # Altınların çıkacağı yer (Kese Resmi)

# --- KONUM AYARLARI ---
# Kolun ekrandaki duruşu (Senin -2.5 ayarın)
var kol_hedef_pos = Vector3(0.35, -0.8, -2.5) 
var kol_baslangic_pos = Vector3(0.35, -3.0, -2.5) 

var iceride_mi: bool = false

func _ready():
	if oyuncu_kolu: 
		oyuncu_kolu.visible = false
	
	if giris_sensoru:
		giris_sensoru.body_entered.connect(_on_giris_sensoru_body_entered)

func _process(delta):
	# Titreme önleyici (Opsiyonel)
	pass

func _on_giris_sensoru_body_entered(body):
	if iceride_mi: return
	if body.name == "Oyuncu" or body is CharacterBody3D:
		var kamera = body.find_child("Camera3D", true, false)
		if not kamera: kamera = body 
		
		if kamera:
			iceride_mi = true
			call_deferred("kolu_kaldir", kamera)

func kolu_kaldir(kamera):
	# 1. Kolu Kameraya Tak
	if oyuncu_kolu.get_parent():
		oyuncu_kolu.get_parent().remove_child(oyuncu_kolu)
	kamera.add_child(oyuncu_kolu)
	
	# 2. Sıfırla
	oyuncu_kolu.transform = Transform3D.IDENTITY
	oyuncu_kolu.visible = true
	oyuncu_kolu.position = kol_baslangic_pos
	oyuncu_kolu.rotation_degrees = Vector3(0, 0, 0) 
	
	# 3. Çıkarma Animasyonu (El + Kese yukarı çıkar)
	var tween = create_tween()
	tween.tween_property(oyuncu_kolu, "position", kol_hedef_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Test: Otomatik ödeme (Bunu sonra silersin)
	tween.tween_callback(odeme_yap.bind(3))
	
	# Kapı Kapatma
	if market_kapisi:
		if market_kapisi.has_method("kilitle"): market_kapisi.kilitle()
		var kapi_tween = create_tween()
		kapi_tween.tween_property(market_kapisi, "rotation_degrees:y", 0.0, 1.0)

func odeme_yap(adet):
	print(str(adet) + " Altın ödeniyor...")
	
	# Hedef Nokta Belirleme
	var hedef_nokta_global = Vector3.ZERO
	if hedef_marketci:
		hedef_nokta_global = hedef_marketci.global_position
	else:
		# Hedef yoksa ileriye salla
		if oyuncu_kolu.get_parent():
			hedef_nokta_global = oyuncu_kolu.get_parent().to_global(Vector3(0, 0, -3.0))
	
	for i in range(adet):
		var yeni_altin = altin_sahnesi.instantiate()
		
		# Altını DÜNYAYA ekle (Bağımsız uçsun diye)
		get_tree().current_scene.add_child(yeni_altin)
		
		# BAŞLANGIÇ: Kese Resminin Tam Üzeri
		if kese_sprite:
			# Kesenin ağzı (Y ekseninde biraz yukarısı: +0.15)
			yeni_altin.global_position = kese_sprite.global_position + (kese_sprite.global_transform.basis.y * 0.15)
		else:
			# Kese atanmadıysa kolun ortasından çıksın
			yeni_altin.global_position = oyuncu_kolu.global_position
		
		yeni_altin.scale = Vector3(0.5, 0.5, 0.5) 
		
		# HEDEF SAPMA (Doğal dağılım)
		var sapma = Vector3(randf_range(-0.1, 0.1), randf_range(0.0, 0.3), randf_range(-0.1, 0.1))
		var final_hedef = hedef_nokta_global + sapma
		
		# UÇUŞ ANİMASYONU
		var tween = create_tween()
		# 1. Kesenin ağzından fırlama (Hafif yukarı)
		tween.tween_property(yeni_altin, "global_position", yeni_altin.global_position + Vector3(0, 0.2, 0), 0.1).set_ease(Tween.EASE_OUT)
		# 2. Hedefe uçuş
		tween.tween_property(yeni_altin, "global_position", final_hedef, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		# 3. Yok oluş
		tween.tween_callback(yeni_altin.queue_free)
		
		await get_tree().create_timer(0.2).timeout
