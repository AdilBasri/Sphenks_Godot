extends Node3D

# --- BÖLÜM 1: REFERANSLAR (El ve Giriş) ---
@onready var oyuncu_kolu = $OyuncuEli 
@onready var giris_sensoru = $GirisSensoru
@onready var altin_sahnesi = preload("res://Altin.tscn")
@export var market_kapisi: Node3D 

# --- BÖLÜM 2: REFERANSLAR (Eşya Spawn Sistemi) ---
# Masanın üzerine koyacağımız görünmez noktaların babası
@onready var spawn_noktalari_node = $SpawnNoktalari 
# Masada oluşacak nesnenin sahnesi
@onready var market_item_sahnesi = preload("res://Items/market_item.tscn") 

# --- BÖLÜM 3: EDİTÖRDEN ATANACAKLAR ---
@export var hedef_marketci: Node3D # Altınların uçacağı yer
@export var kese_sprite: Sprite3D   # Altınların çıkacağı kese
# Buraya Inspector'dan 12 tane .tres dosyasını sürükleyeceksin
@export var olasi_esyalari_listesi: Array[ItemData] 

# --- BÖLÜM 4: KONUM AYARLARI ---
# Kolun ekrandaki duruşu (Senin -2.5 ayarın)
var kol_hedef_pos = Vector3(0.35, -0.8, -2.5) 
var kol_baslangic_pos = Vector3(0.35, -3.0, -2.5) 

var iceride_mi: bool = false

func _ready():
	# 1. Eli Gizle
	if oyuncu_kolu: 
		oyuncu_kolu.visible = false
	
	# 2. Giriş Sensörünü Bağla
	if giris_sensoru:
		if not giris_sensoru.body_entered.is_connected(_on_giris_sensoru_body_entered):
			giris_sensoru.body_entered.connect(_on_giris_sensoru_body_entered)
	
	# 3. RASTGELE EŞYA DİZME İŞLEMİ
	randomize() # Her açılışta farklı olsun
	rastgele_esya_diz()

func rastgele_esya_diz():
	# Hata Kontrolleri
	if olasi_esyalari_listesi.is_empty():
		print("UYARI: Market eşya listesi boş!")
		return
	
	if not spawn_noktalari_node:
		print("HATA: 'SpawnNoktalari' bulunamadı!")
		return

	# Önce masayı temizle (Eğer daha önce eşya konduysa sil)
	for cocuk in spawn_noktalari_node.get_children():
		# Sadece Marker3D'ler kalsın, MarketItem'ları temizle
		# (Marker3D'lerin altına eklemediğimiz için bu adım şimdilik opsiyonel ama güvenli)
		pass

	# Listeyi karıştır
	olasi_esyalari_listesi.shuffle()
	
	var noktalar = spawn_noktalari_node.get_children()
	var masaya_konacaklar = [] # Seçilenleri burada biriktireceğiz
	
	# --- AKILLI SEÇİM DÖNGÜSÜ ---
	for aday_esya in olasi_esyalari_listesi:
		# Masadaki nokta sayısı dolduysa dur
		if masaya_konacaklar.size() >= noktalar.size():
			break
		
		# KURAL: Aynı eşyadan masada kaç tane var say
		var adet = masaya_konacaklar.count(aday_esya)
		
		# Eğer 2'den azsa (0 veya 1 ise) ekle. 2 ise ekleme, pas geç.
		if adet < 2:
			masaya_konacaklar.append(aday_esya)
	
	# --- YERLEŞTİRME ---
	for i in range(masaya_konacaklar.size()):
		var spawn_pos = noktalar[i]
		var secilen_veri = masaya_konacaklar[i]
		
		var yeni_urun = market_item_sahnesi.instantiate()
		add_child(yeni_urun)
		
		yeni_urun.global_position = spawn_pos.global_position
		yeni_urun.global_rotation = spawn_pos.global_rotation
		
		if "esya_verisi" in yeni_urun:
			yeni_urun.esya_verisi = secilen_veri
			yeni_urun.veriyi_yukle()

# --- YENİ FONKSİYON: SATIN ALMA İZNİ ---
# Oyuncu.gd bu fonksiyonu çağıracak
func satin_almaya_calis(fiyat: int, esya_data: ItemData) -> bool:
	
	# 1. KONTROL: Çanta Dolu mu? (GameManager Singleton'ı lazım)
	if GameManager.envanter.size() >= GameManager.max_totem_sayisi:
		red_efekti_oynat()
		return false # Satın alma BAŞARISIZ
	
	# 2. İŞLEM: Satın Alma BAŞARILI
	GameManager.totem_ekle(esya_data)
	odeme_yap(fiyat) # Senin yazdığın altın uçurma fonksiyonunu çalıştır
	
	return true 

func red_efekti_oynat():
	print("REDDEDİLDİ! Çanta Dolu! (Buraya ses efekti gelecek)")

# --- ESKİ FONKSİYONLAR (El Animasyonu & Ödeme) ---
func _on_giris_sensoru_body_entered(body):
	if iceride_mi: return
	if body.name == "Oyuncu" or body is CharacterBody3D:
		var kamera = body.find_child("Camera3D", true, false)
		if not kamera: kamera = body 
		
		if kamera:
			iceride_mi = true
			call_deferred("kolu_kaldir", kamera)

func kolu_kaldir(kamera):
	if oyuncu_kolu.get_parent():
		oyuncu_kolu.get_parent().remove_child(oyuncu_kolu)
	kamera.add_child(oyuncu_kolu)
	
	oyuncu_kolu.transform = Transform3D.IDENTITY
	oyuncu_kolu.visible = true
	oyuncu_kolu.position = kol_baslangic_pos
	oyuncu_kolu.rotation_degrees = Vector3(0, 0, 0) 
	
	var tween = create_tween()
	tween.tween_property(oyuncu_kolu, "position", kol_hedef_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if market_kapisi:
		if market_kapisi.has_method("kilitle"): market_kapisi.kilitle()
		var kapi_tween = create_tween()
		kapi_tween.tween_property(market_kapisi, "rotation_degrees:y", 0.0, 1.0)

func odeme_yap(adet):
	print(str(adet) + " Altın ödeniyor...")
	
	var hedef_nokta_global = Vector3.ZERO
	if hedef_marketci:
		hedef_nokta_global = hedef_marketci.global_position
	else:
		if oyuncu_kolu.get_parent():
			hedef_nokta_global = oyuncu_kolu.get_parent().to_global(Vector3(0, 0, -3.0))
	
	for i in range(adet):
		var yeni_altin = altin_sahnesi.instantiate()
		get_tree().current_scene.add_child(yeni_altin)
		
		if kese_sprite:
			yeni_altin.global_position = kese_sprite.global_position + (kese_sprite.global_transform.basis.y * 0.15)
		else:
			yeni_altin.global_position = oyuncu_kolu.global_position
		
		yeni_altin.scale = Vector3(0.5, 0.5, 0.5) 
		
		var sapma = Vector3(randf_range(-0.1, 0.1), randf_range(0.0, 0.3), randf_range(-0.1, 0.1))
		var final_hedef = hedef_nokta_global + sapma
		
		var tween = create_tween()
		tween.tween_property(yeni_altin, "global_position", yeni_altin.global_position + Vector3(0, 0.2, 0), 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(yeni_altin, "global_position", final_hedef, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(yeni_altin.queue_free)
		
		await get_tree().create_timer(0.2).timeout
