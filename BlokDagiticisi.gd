extends Node3D

# --- AYARLAR ---
@export var grid: GridYonetici
@export var spawn_noktalari: Array[Marker3D] 
@export var blok_sahneleri: Array[PackedScene] 

# --- SAHNE OBJELERİ ---
@export var boss_objesi: Node3D 
@export var masa_objesi: Node3D 
@export var kapi_sistemi: Node3D 

# --- BÖLÜM AYARLARI ---
var bolum_blok_limiti: int = 12 
var elde_tutulan_max: int = 3    
var baslangic_kotasi: int = 300 

# --- DEĞİŞKENLER ---
var kalan_stok: int = 0
var masadaki_aktif_bloklar: int = 0
var tur_bitti_mi: bool = false
var boss_oldu_mu: bool = false 

signal stok_bitti 
signal stok_guncellendi(kalan: int)
signal bolum_temizlendi 

func _ready() -> void:
	# Başlangıçta biraz bekle ki sahne yüklensin
	await get_tree().create_timer(0.1).timeout
	yeni_bolumu_baslat()

func yeni_bolumu_baslat():
	var veri = LevelManager.bolum_verilerini_getir()
	bolum_blok_limiti = veri["blok_limiti"]
	baslangic_kotasi = veri["hedef_puan"]
	var suanki_katman = veri["katman"]
	var boss_yolu = veri.get("boss_resmi", "")
	
	print("--- BÖLÜM BAŞLIYOR: KATMAN ", suanki_katman, " ---")

	# 1. UI Güncelle
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz:
		arayuz.bolum_kurulumu(baslangic_kotasi)
		if arayuz.has_method("katman_yazisi_goster"):
			arayuz.katman_yazisi_goster(suanki_katman)

	# 2. Değişkenleri Sıfırla
	kalan_stok = bolum_blok_limiti
	tur_bitti_mi = false
	boss_oldu_mu = false
	masadaki_aktif_bloklar = 0
	
	# 3. BOSS GÜNCELLEME (Görünürlük Fix)
	if boss_objesi:
		boss_objesi.visible = true # Zorla görünür yap
		boss_objesi.scale = Vector3.ONE # Boyutu düzelt
		boss_objesi.modulate = Color.WHITE # Rengi düzelt (Kırmızı kaldıysa)
		
		# Resmi Yükle
		if boss_yolu != "":
			var doku = load(boss_yolu)
			if doku:
				if boss_objesi is Sprite3D:
					boss_objesi.texture = doku
				elif boss_objesi is MeshInstance3D:
					var mat = boss_objesi.get_active_material(0)
					if mat:
						mat.albedo_texture = doku
					else:
						# Materyal yoksa yeni oluştur
						var yeni_mat = StandardMaterial3D.new()
						yeni_mat.albedo_texture = doku
						yeni_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						boss_objesi.material_override = yeni_mat
			else:
				print("HATA: Boss resmi yüklenemedi! Yol: ", boss_yolu)
	else:
		print("HATA: Boss Objesi atanmamış!")

	# 4. Grid Temizle
	if grid: grid._gridi_yenile()
	
	# SPAWN NOKTALARINI GIZLE (Silindirleri kapat)
	_spawn_noktalarini_guncelle(false)

	emit_signal("stok_guncellendi", kalan_stok)
	# OTO SPAWN İPTAL (Kullanıcı İsteği)
	# await get_tree().create_timer(1.0).timeout
	# _stoktan_yeni_parti_ver()

func baslat_spawn_dongusu() -> void:
	# Oyun başladığında (Tabureye oturunca) çağrılacak
	_spawn_noktalarini_guncelle(true)
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()

func _spawn_noktalarini_guncelle(aktif: bool) -> void:
	for nokta in spawn_noktalari:
		# Noktanın altındaki görsel objeleri (CSGCylinder vb.) bul ve gizle/aç
		for child in nokta.get_children():
			if child is CSGShape3D or child is MeshInstance3D:
				child.visible = aktif

# ... (Geri kalan fonksiyonlar _stoktan_yeni_parti_ver, _on_blok_yerlesti vb. AYNEN KALSIN) ...
# Sadece bu üst kısmı (yeni_bolumu_baslat) güncellemen yeterli.
# Yine de tam halini istiyorsan aşağıya devamını ekliyorum:

func _stoktan_yeni_parti_ver() -> void:
	if tur_bitti_mi: return
	if blok_sahneleri.is_empty(): return

	if kalan_stok <= 0 and masadaki_aktif_bloklar <= 0:
		emit_signal("stok_bitti")
		_tur_sonu_hesaplamasi()
		return

	var eksik_sayisi = elde_tutulan_max - masadaki_aktif_bloklar
	var dagitilacak_adet = min(eksik_sayisi, kalan_stok)
	
	if dagitilacak_adet > 0:
		spawn_bloklar(dagitilacak_adet)

func _on_blok_yerlesti() -> void:
	masadaki_aktif_bloklar -= 1
	_anlik_boss_kontrolu()
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()

func _anlik_boss_kontrolu() -> void:
	if boss_oldu_mu: return
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz:
		var skor = 0
		if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
		elif "puan" in arayuz: skor = arayuz.puan
		
		if skor >= arayuz.hedef_puan:
			_boss_olum_animasyonu()

func _boss_olum_animasyonu() -> void:
	print(">>> KOTA AŞILDI! BOSS GİDİYOR... <<<")
	boss_oldu_mu = true 
	GameManager.boss_oldu.emit()
	
	if is_instance_valid(boss_objesi):
		var tween = create_tween()
		tween.set_parallel(true)
		for i in range(10):
			tween.tween_property(boss_objesi, "position:x", 0.1, 0.03).as_relative()
			tween.tween_property(boss_objesi, "position:x", -0.1, 0.03).as_relative()
		
		if "modulate" in boss_objesi:
			tween.tween_property(boss_objesi, "modulate", Color.RED, 0.5)
			
		tween.tween_property(boss_objesi, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN)
		
		# Boss'u silme (queue_free), sadece gizle. Çünkü sonraki turda geri gelecek!
		tween.chain().tween_callback(func():
			if is_instance_valid(boss_objesi):
				boss_objesi.visible = false # SİLME YOK!
		)

func _tur_sonu_hesaplamasi() -> void:
	tur_bitti_mi = true
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if not arayuz: return
	var skor = 0
	if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
	elif "puan" in arayuz: skor = arayuz.puan
	
	if skor >= arayuz.hedef_puan:
		_sahne_bitis_animasyonu() 
	else:
		_oyun_kaybedildi(arayuz)

func _sahne_bitis_animasyonu() -> void:
	set_process_input(false)
	var tween = create_tween()
	tween.set_parallel(true)
	
	if is_instance_valid(masa_objesi):
		tween.tween_property(masa_objesi, "position:y", -10.0, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	tween.chain().tween_callback(func(): 
		if is_instance_valid(boss_objesi): boss_objesi.visible = false
		if is_instance_valid(masa_objesi): masa_objesi.queue_free()
		if kapi_sistemi and kapi_sistemi.has_method("kapiyi_ac"):
			kapi_sistemi.kapiyi_ac()
		emit_signal("bolum_temizlendi") 
	)

func _oyun_kaybedildi(arayuz_ref) -> void:
	if arayuz_ref.has_method("puan_ekle"):
		arayuz_ref.puan_ekle(0, "YETERSİZ PUAN - KAYBETTİN")

func spawn_bloklar(adet: int) -> void:
	for i in range(adet):
		var hedef_marker = _bos_spawn_noktasi_bul()
		if hedef_marker == null: break
		kalan_stok -= 1
		emit_signal("stok_guncellendi", kalan_stok)
		masadaki_aktif_bloklar += 1
		_blok_yarat_ve_firlat(hedef_marker)
		await get_tree().create_timer(0.2).timeout

func _bos_spawn_noktasi_bul() -> Marker3D:
	for nokta in spawn_noktalari:
		if nokta.get_child_count() == 0: return nokta
		var blok_var = false
		for child in nokta.get_children():
			if child.is_in_group("Blok") or "Blok" in child.name:
				blok_var = true
				break
		if not blok_var: return nokta
	return null

func _blok_yarat_ve_firlat(target_marker: Marker3D) -> void:
	if blok_sahneleri.is_empty(): return
	var random_scene = blok_sahneleri.pick_random()
	var yeni_blok = random_scene.instantiate()
	target_marker.add_child(yeni_blok)
	if yeni_blok is BlokSurukle:
		yeni_blok.grid = grid
		yeni_blok.blok_yerlesti.connect(_on_blok_yerlesti)
		yeni_blok.add_to_group("Blok") 
	var hedef_scale = yeni_blok.scale 
	yeni_blok.scale = Vector3(0.01, 0.01, 0.01) 
	yeni_blok.position = Vector3(0, -2, 0) 
	
	# ROTASYON DÜZELTME:
	# Kullanıcı "sanki soldan bakıyormuşum gibi duruyor" dedi.
	# Şu an (0, 180, 0) veriyoruz.
	# Spawner -90 derece dönük (Sağda).
	# Bloklar Spawner'ın çocuğu (Child).
	# Spawner Z- ekseni (yani sağı) oyuncuya bakıyor.
	# Eğer Blok rotasyonu (0,0,0) olursa, Blok da Z- yönüne (oyuncuya) bakar.
	# Ama kullanıcıya "yan" duruyor olabilir.
	# Kullanıcının "Gridle aramda blok var" hissi için blokların ön yüzü oyuncuya bakmalı.
	# Deneme: (0, 90, 0) veya (0, -90, 0) ile 90 derece çevirelim.
	# Spawner'ın -90 olduğu yerde, Blok +90 olursa World Space'de 0 olur (Masa hizası).
	# Spawner'a göre hizalayalım.
	
	# Eski ayar: (0, 180, 0) -> Tam tersi (arkası dönük belki?)
	# Yeni ayar: 90 derece ofset verelim.
	var hedef_rotasyon = Vector3(0, deg_to_rad(90), 0) 
	
	yeni_blok.rotation_degrees = Vector3(0, 180, 0) # Başlangıç (Tween öncesi önemsiz ama animasyon için)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(yeni_blok, "position", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(yeni_blok, "scale", hedef_scale, 0.5)
	
	# Rotasyonu Tweenle
	tween.tween_property(yeni_blok, "rotation", hedef_rotasyon, 0.5)
