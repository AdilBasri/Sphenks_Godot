extends Node3D

# --- AYARLAR ---
@export var grid: GridYonetici
@export var spawn_noktalari: Array[Marker3D] 
@export var blok_sahneleri: Array[PackedScene] 

# --- SAHNE OBJELERİ (KAYBOLACAKLAR) ---
@export var boss_objesi: Node3D 
@export var masa_objesi: Node3D # Masanın tamamını (Grid dahil) kapsayan ana düğüm

# --- BÖLÜM AYARLARI ---
@export var bolum_blok_limiti: int = 12 
@export var elde_tutulan_max: int = 3
@export var baslangic_kotasi: int = 1000 # Inspector'dan ayarlanabilir hedef puan!

# --- DEĞİŞKENLER ---
var kalan_stok: int = 0
var masadaki_aktif_bloklar: int = 0
var tur_bitti_mi: bool = false

signal stok_bitti 
signal stok_guncellendi(kalan: int)
signal bolum_temizlendi # Koridor kapısının açılmasını tetikleyecek sinyal

func _ready() -> void:
	# 1. ÖNCE ARAYÜZÜ KUR (Hedefi Bildir)
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bolum_kurulumu"):
		arayuz.bolum_kurulumu(baslangic_kotasi)
	else:
		print("UYARI: Arayüz bulunamadı veya 'bolum_kurulumu' fonksiyonu eksik!")

	# 2. Stokları ve oyunu başlat
	kalan_stok = bolum_blok_limiti
	tur_bitti_mi = false
	emit_signal("stok_guncellendi", kalan_stok)
	
	# Sahnenin yüklenmesi için kısa bekleme
	await get_tree().create_timer(1.0).timeout
	_stoktan_yeni_parti_ver()

func _stoktan_yeni_parti_ver() -> void:
	if tur_bitti_mi: return

	if blok_sahneleri.is_empty():
		print("!!! HATA: Blok Sahneleri Inspector'da boş! Blok gelmez.")
		return

	# Stok bitti kontrolü
	if kalan_stok <= 0 and masadaki_aktif_bloklar <= 0:
		emit_signal("stok_bitti")
		_tur_sonu_hesaplamasi()
		return

	var eksik_sayisi = elde_tutulan_max - masadaki_aktif_bloklar
	var dagitilacak_adet = min(eksik_sayisi, kalan_stok)
	
	if dagitilacak_adet > 0:
		spawn_bloklar(dagitilacak_adet)

func _tur_sonu_hesaplamasi() -> void:
	tur_bitti_mi = true
	print("--- TUR BİTTİ: HESAPLAMA YAPILIYOR ---")
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if not arayuz:
		print("HATA: Arayüz grubu bulunamadı!")
		return
		
	var skor = 0
	if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
	elif "puan" in arayuz: skor = arayuz.puan
	
	# KAZANMA KONTROLÜ (Hedef artık sabit olduğu için burası doğru çalışacak)
	print("Skor: ", skor, " / Hedef: ", arayuz.hedef_puan)
	
	if skor >= arayuz.hedef_puan:
		_sahneyi_temizle_ve_ilerle()
	else:
		_oyun_kaybedildi(arayuz)

func _sahneyi_temizle_ve_ilerle() -> void:
	print(">>> ZAFER! ODA BOŞALTILIYOR... <<<")
	
	# Oyuncuyu kilitle
	set_process_input(false)
	
	var tween = create_tween()
	tween.set_parallel(true) # Tüm animasyonlar aynı anda
	
	# 1. BOSS ANİMASYONU (Titreyip Çökme)
	if boss_objesi:
		var boss_tween = create_tween()
		for i in range(6): # Önce titret
			boss_tween.tween_property(boss_objesi, "position:x", 0.15, 0.04).as_relative()
			boss_tween.tween_property(boss_objesi, "position:x", -0.15, 0.04).as_relative()
		# Sonra göm
		tween.tween_property(boss_objesi, "position:y", -10.0, 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_property(boss_objesi, "scale", Vector3.ZERO, 3.0)
	
	# 2. MASA ANİMASYONU (Aşağı İnecek)
	if masa_objesi:
		tween.tween_property(masa_objesi, "position:y", -10.0, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 3. BİTİŞ SİNYALİ
	tween.chain().tween_callback(func(): 
		print("--- ODA TEMİZLENDİ. KAPI AÇILMA SİNYALİ GÖNDERİLİYOR ---")
		emit_signal("bolum_temizlendi") 
	)

func _oyun_kaybedildi(arayuz_ref) -> void:
	print(">>> KAYBETTİNİZ <<<")
	if arayuz_ref.has_method("puan_ekle"):
		arayuz_ref.puan_ekle(0, "YETERSİZ PUAN - KAYBETTİN")

# --- SPAWN FONKSİYONLARI ---
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
		if nokta.get_child_count() == 0: 
			return nokta
		
		# Yedek kontrol: İçinde 'Blok' grubuna dahil bir şey var mı?
		var blok_var = false
		for child in nokta.get_children():
			if child.is_in_group("Blok") or "Blok" in child.name or "block" in child.name:
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

func _on_blok_yerlesti() -> void:
	masadaki_aktif_bloklar -= 1
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()
