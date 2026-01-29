extends Node3D

# --- AYARLAR ---
@export var grid: GridYonetici
@export var spawn_noktalari: Array[Marker3D] 
@export var blok_sahneleri: Array[PackedScene] 

# --- BÖLÜM AYARLARI ---
@export var bolum_blok_limiti: int = 12 
@export var elde_tutulan_max: int = 3   

# --- SİNEMATİK AYARLARI (Hata veren kısım burasıydı) ---
@export var boss_objesi: Node3D  # <-- BU SATIR EKSİKTİ!

# --- DEĞİŞKENLER ---
var kalan_stok: int = 0
var masadaki_aktif_bloklar: int = 0

signal stok_bitti 
signal stok_guncellendi(kalan: int)

func _ready() -> void:
	kalan_stok = bolum_blok_limiti
	emit_signal("stok_guncellendi", kalan_stok)
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()

func _stoktan_yeni_parti_ver() -> void:
	# Stok bitti ve masada blok kalmadı -> OYUN SONU KONTROLÜ
	if kalan_stok <= 0 and masadaki_aktif_bloklar <= 0:
		emit_signal("stok_bitti")
		_oyun_sonu_kontrolu()
		return

	var eksik_sayisi = elde_tutulan_max - masadaki_aktif_bloklar
	var dagitilacak_adet = min(eksik_sayisi, kalan_stok)
	
	if dagitilacak_adet > 0:
		spawn_bloklar(dagitilacak_adet)

# --- OYUN SONU (WIN/LOSE) MANTIĞI ---
func _oyun_sonu_kontrolu() -> void:
	print("--- OYUN SONU KONTROLU BAŞLADI ---")
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	
	if arayuz:
		var skor = 0
		if "toplam_puan" in arayuz:
			skor = arayuz.toplam_puan
		elif "puan" in arayuz:
			skor = arayuz.puan
		
		print("Skor: ", skor, " | Hedef: ", arayuz.hedef_puan)
		
		if skor >= arayuz.hedef_puan:
			_bolumu_kazan()
		else:
			_bolumu_kaybet(arayuz)
	else:
		print("HATA: Arayüz bulunamadı!")

func _bolumu_kazan() -> void:
	print(">>> KAZANDINIZ! SİNEMATİK BAŞLIYOR <<<")
	
	# 1. Kontrolleri kilitle
	set_process_input(false)
	
	# 2. Boss Animasyonu
	if boss_objesi:
		var tween = create_tween()
		
		# Titreme (Sağa Sola)
		for i in range(5):
			tween.tween_property(boss_objesi, "position:x", 0.2, 0.05).as_relative()
			tween.tween_property(boss_objesi, "position:x", -0.2, 0.05).as_relative()
		
		# Yerin Dibine Girme + Küçülme
		tween.parallel().tween_property(boss_objesi, "position:y", -10.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(boss_objesi, "scale", Vector3.ZERO, 2.0)
		
		tween.tween_callback(func(): print("BOSS YOK OLDU! Level Geçişi Yapılacak..."))
	else:
		print("HATA: Boss Objesi atanmamış!")

func _bolumu_kaybet(arayuz_ref) -> void:
	print(">>> OYUN BİTTİ - KAYBETTİNİZ <<<")
	if arayuz_ref.has_method("puan_ekle"):
		arayuz_ref.puan_ekle(0, "YETERSİZ PUAN - OYUN BİTTİ")

# --- SPAWN İŞLEMLERİ ---
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
		var blok_var = false
		for child in nokta.get_children():
			if not (child is MeshInstance3D or child is CSGShape3D or child is CSGCombiner3D):
				if child is Node3D: 
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
	
	var hedef_scale = yeni_blok.scale 
	yeni_blok.set_meta("orjinal_scale", hedef_scale)
	yeni_blok.scale = Vector3(0.01, 0.01, 0.01) 
	yeni_blok.position = Vector3(0, -2, 0) 
	yeni_blok.rotation_degrees = Vector3(0, 180, 0)
	_animasyon_oynat(yeni_blok, Vector3.ZERO, hedef_scale, Vector3.ZERO)

func _on_blok_yerlesti() -> void:
	masadaki_aktif_bloklar -= 1
	await get_tree().create_timer(0.8).timeout
	_stoktan_yeni_parti_ver()

func _animasyon_oynat(target, pos, scl, rot):
	var tween = create_tween()
	target.set_meta("tween", tween)
	tween.set_parallel(true)
	tween.tween_property(target, "position", pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", scl, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "rotation", rot, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
