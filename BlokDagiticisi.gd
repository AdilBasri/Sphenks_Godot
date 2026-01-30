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
@export var bolum_blok_limiti: int = 12 
@export var elde_tutulan_max: int = 3   
@export var baslangic_kotasi: int = 300 

# --- DEĞİŞKENLER ---
var kalan_stok: int = 0
var masadaki_aktif_bloklar: int = 0
var tur_bitti_mi: bool = false
var boss_oldu_mu: bool = false # Boss'un ölüp ölmediğini takip eder

signal stok_bitti 
signal stok_guncellendi(kalan: int)
signal bolum_temizlendi 

func _ready() -> void:
	# 1. ARAYÜZ KURULUMU
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bolum_kurulumu"):
		arayuz.bolum_kurulumu(baslangic_kotasi)

	# 2. DEĞİŞKENLERİ SIFIRLA
	kalan_stok = bolum_blok_limiti
	tur_bitti_mi = false
	boss_oldu_mu = false
	emit_signal("stok_guncellendi", kalan_stok)
	
	# 3. BAŞLANGIÇ
	await get_tree().create_timer(1.0).timeout
	_stoktan_yeni_parti_ver()

func _stoktan_yeni_parti_ver() -> void:
	if tur_bitti_mi: return

	if blok_sahneleri.is_empty():
		print("!!! HATA: Blok Sahneleri boş!")
		return

	# OYUN SONU KONTROLÜ (Sadece bloklar bitince çağrılır)
	if kalan_stok <= 0 and masadaki_aktif_bloklar <= 0:
		emit_signal("stok_bitti")
		_tur_sonu_hesaplamasi()
		return

	var eksik_sayisi = elde_tutulan_max - masadaki_aktif_bloklar
	var dagitilacak_adet = min(eksik_sayisi, kalan_stok)
	
	if dagitilacak_adet > 0:
		spawn_bloklar(dagitilacak_adet)

# --- BLOK YERLEŞİNCE ÇAĞRILIR ---
func _on_blok_yerlesti() -> void:
	masadaki_aktif_bloklar -= 1
	
	# YENİ: Her hamlede Boss'un durumunu kontrol et
	_anlik_boss_kontrolu()
	
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()

# --- YENİ FONKSİYON: BOSS ÖLÜMÜNÜ ANLIK KONTROL ET ---
func _anlik_boss_kontrolu() -> void:
	# Eğer Boss zaten öldüyse tekrar kontrol etme
	if boss_oldu_mu: return
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz:
		var skor = 0
		if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
		elif "puan" in arayuz: skor = arayuz.puan
		
		# KOTA AŞILDI MI?
		if skor >= arayuz.hedef_puan:
			_boss_olum_animasyonu()

func _boss_olum_animasyonu() -> void:
	print(">>> KOTA AŞILDI! BOSS YOK OLUYOR... <<<")
	boss_oldu_mu = true # Artık tekrar tetiklenmez
	
	if is_instance_valid(boss_objesi):
		var tween = create_tween()
		tween.set_parallel(true)
		
		# 1. Titreme (Korku)
		for i in range(10):
			tween.tween_property(boss_objesi, "position:x", 0.1, 0.03).as_relative()
			tween.tween_property(boss_objesi, "position:x", -0.1, 0.03).as_relative()
		
		# 2. Kırmızılaşma (Eğer Sprite3D veya Modulate özelliği varsa)
		if "modulate" in boss_objesi:
			tween.tween_property(boss_objesi, "modulate", Color.RED, 0.5)
			
		# 3. İçe Çökme (Scale 0'a gider) - "POP" etkisi için hızlı ve Elastic
		tween.tween_property(boss_objesi, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN)
		
		# 4. Tamamen Silinme
		tween.chain().tween_callback(func():
			if is_instance_valid(boss_objesi):
				boss_objesi.queue_free()
		)

# --- TUR SONU (BLOKLAR BİTİNCE) ---
func _tur_sonu_hesaplamasi() -> void:
	tur_bitti_mi = true
	print("--- TUR BİTTİ: HESAPLAMA ---")
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if not arayuz: return
		
	var skor = 0
	if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
	elif "puan" in arayuz: skor = arayuz.puan
	
	# Eğer Boss zaten öldüyse (ki kota geçildiyse ölmüştür), sahneyi bitir
	if skor >= arayuz.hedef_puan:
		_sahne_bitis_animasyonu() # Sadece Masa ve Kapı kalır
	else:
		_oyun_kaybedildi(arayuz)

func _sahne_bitis_animasyonu() -> void:
	print(">>> TUR TAMAMLANDI! MASA İNİYOR, KAPI AÇILIYOR... <<<")
	set_process_input(false)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Not: Boss burada yok, çünkü oyun esnasında öldü.
	# Sadece Masa aşağı iniyor.
	if is_instance_valid(masa_objesi):
		tween.tween_property(masa_objesi, "position:y", -10.0, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Bitiş Callback
	tween.chain().tween_callback(func(): 
		# Güvenlik temizliği (Kalan parça varsa)
		if is_instance_valid(boss_objesi): boss_objesi.queue_free()
		if is_instance_valid(masa_objesi): masa_objesi.queue_free()
		
		# Kapıyı Aç
		if kapi_sistemi and kapi_sistemi.has_method("kapiyi_ac"):
			kapi_sistemi.kapiyi_ac()
			
		emit_signal("bolum_temizlendi") 
	)

func _oyun_kaybedildi(arayuz_ref) -> void:
	print(">>> KAYBETTİNİZ <<<")
	if arayuz_ref.has_method("puan_ekle"):
		arayuz_ref.puan_ekle(0, "YETERSİZ PUAN - KAYBETTİN")

# --- SPAWN VE BLOK İŞLEMLERİ (Standart) ---
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
	yeni_blok.rotation_degrees = Vector3(0, 180, 0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(yeni_blok, "position", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(yeni_blok, "scale", hedef_scale, 0.5)
	tween.tween_property(yeni_blok, "rotation", Vector3.ZERO, 0.5)
