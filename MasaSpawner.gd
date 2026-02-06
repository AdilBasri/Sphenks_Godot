extends Node3D

@export var satilacak_esya_listesi: Array[ItemData] # Asit.tres vb. buraya
@export var spawn_noktalari: Array[Marker3D] # Masadaki noktalar

func _ready():
	await get_tree().create_timer(0.5).timeout 
	esyalari_diz()

func esyalari_diz():
	if satilacak_esya_listesi.is_empty(): return
	if spawn_noktalari.is_empty(): return
	
	# Her spawn noktasına rastgele bir eşya koy
	for nokta in spawn_noktalari:
		var rastgele_veri = satilacak_esya_listesi.pick_random()
		esya_olustur(rastgele_veri, nokta)

func esya_olustur(veri: ItemData, nokta: Marker3D):
	if not veri or not veri.model_sahnesi: return
	
	# Modeli oluştur
	var yeni_esya = veri.model_sahnesi.instantiate()
	add_child(yeni_esya)
	
	# Pozisyonu ayarla
	yeni_esya.global_position = nokta.global_position
	yeni_esya.global_rotation = nokta.global_rotation
	
	# --- KRİTİK DÜZELTMELER ---
	
	# 1. Boyut Sıfırlama (Zik büzük olmasın)
	yeni_esya.scale = Vector3.ONE 
	
	# 2. Script Enjekte Etme
	# Eğer modelde script yoksa veya farklıysa bizimkini takıyoruz
	yeni_esya.set_script(load("res://Scripts/SatinAlinabilirNesne.gd"))
	
	# 3. Verileri Doldurma
	yeni_esya.esya_verisi = veri
	yeni_esya.market_modu = true # BURASI ÖNEMLİ: Marketteyiz, paralı olsun.
	
	# 4. Fizik Sabitleme
	if yeni_esya is RigidBody3D:
		yeni_esya.freeze = true
