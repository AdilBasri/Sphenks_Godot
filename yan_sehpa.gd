extends Node3D

@onready var slotlar_node = $Slotlar

func _ready():
	# GameManager'ı dinle
	if not GameManager.envanter_guncellendi.is_connected(tazele):
		GameManager.envanter_guncellendi.connect(tazele)
	
	# Başlangıçta yükle
	tazele()

func tazele():
	# Önce masayı temizle
	temizle()
	
	if not slotlar_node: return
	
	var slotlar = slotlar_node.get_children()
	var envanter = GameManager.envanter
	
	# Envanterdeki her eşya için döngü
	for i in range(min(envanter.size(), slotlar.size())):
		var veri = envanter[i]
		var hedef_marker = slotlar[i]
		
		# RESİM YERİNE MODEL OLUŞTURUYORUZ
		esya_modelini_koy(hedef_marker, veri)

func esya_modelini_koy(marker: Marker3D, veri: ItemData):
	if not veri or not veri.model_sahnesi: 
		print("Model sahnesi yok, Sprite deneniyor...")
		# Model yoksa eski usül sprite koyabilirsin (yedek plan) ama model olmalı.
		return

	# 1. Modeli Sahneye Ekle (Instantiate)
	var yeni_esya = veri.model_sahnesi.instantiate()
	marker.add_child(yeni_esya)
	
	# 2. Pozisyon ve Boyut Ayarı
	yeni_esya.position = Vector3.ZERO
	yeni_esya.rotation = Vector3.ZERO
	yeni_esya.scale = Vector3.ONE # Ezikliği önlemek için 1,1,1 yapıyoruz
	
	# 3. Script Enjeksiyonu (Etkileşim için)
	# Eğer modelin üzerinde zaten script yoksa, SatinAlinabilirNesne.gd'yi takıyoruz.
	if not yeni_esya.get_script():
		yeni_esya.set_script(load("res://Scripts/SatinAlinabilirNesne.gd"))
	
	# 4. Verileri İşle
	# SatinAlinabilirNesne scripti bu değişkenleri arar
	yeni_esya.set("esya_verisi", veri)
	yeni_esya.set("market_modu", false) # BURASI KRİTİK: Sehpadaki eşya bedava alınır.
	
	# 5. Fizik Ayarı (Masadan düşmemesi için dondur)
	if yeni_esya is RigidBody3D:
		yeni_esya.freeze = true
		yeni_esya.collision_layer = 1 # Raycast görsün diye katman açık

func temizle():
	if slotlar_node:
		for marker in slotlar_node.get_children():
			for cocuk in marker.get_children():
				cocuk.queue_free()
