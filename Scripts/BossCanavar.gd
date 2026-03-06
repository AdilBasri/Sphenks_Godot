extends Node3D

signal saldiri_tamamlandi

# --- DÜĞÜM REFERANSLARI ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var kamera_boss: Camera3D = $Camera3D

# --- SKELETON/BONE REFERANSLARI (drift fix) ---
var _skeleton: Skeleton3D = null
var _hips_bone_idx: int = -1
var _hips_oturma_sonu_poz: Vector3 = Vector3.ZERO  # Oturma animasyonu bittiğindeki Hips pozisyonu
var _hips_poz_kilitli: bool = false

# --- DIŞ REFERANSLAR (Sahne yüklendiğinde bulunur) ---
var grid: Node = null       # GridYoneticisi
var arayuz: CanvasLayer = null # Arayüz (bilgi_goster)

# --- AYARLAR ---
@export var boss_adi: String = "Canavar"
@export var mermi_zemini_y: float = -1.0

# --- 👁️ GLITCH PARRY (REALITY DENIAL) ASSETS ---
@export var glitch_yuzu_dokusu: Texture2D
@export var kirik_cam_sesi: AudioStream
var glitch_ui_rect: TextureRect = null

# --- DURUM MAKİNESİ ---
# Durumlar: "BASLANGIC", "UYUKLAMA", "AYAKTA", "SALDIRI"
const DURUM_OLDU = 99
var suanki_durum: String = "BASLANGIC"
var oldu_mu: bool = false
var sonraki_saldiri_tipi: String = ""   # Kahin Gözü için bir tur önceden belirlenir

# --- ANİMASYON İSİMLERİ (Otomatik keşfedilecek) ---
var oturma_anim_adi: String = ""
var uyuklama_anim_adi: String = ""
var ayakta_durma_anim_adi: String = ""
var ilk_uyanisi_yapti_mi: bool = false

# --- TABURE POZİSYONU (Issue 2: eski global_position clamp - artık bone fix kullanılıyor) ---
var tabure_pozisyonu: Vector3 = Vector3.ZERO
var tabure_pozisyonu_kaydedildi: bool = false
var _saldiri_resume_ediliyor: bool = false

# --- HARİCİ ANİMASYON YÜKLEYİCİ ---
@export var harici_ayakta_anim_fbx: PackedScene = preload("res://AyaktaAnimasyon/Meshy_AI_Animation_Idle_11_withSkin.fbx")

# ==========================================
# HAZIRLIK
# ==========================================

var sfx_snore: AudioStreamPlayer3D

func _ready():
	add_to_group("Dusman")
	
	sfx_snore = AudioStreamPlayer3D.new()
	var s_stream = load("res://Sesler/snoring.mp3")
	if s_stream and s_stream is AudioStream:
		if s_stream.has_method("set_loop"): s_stream.set_loop(true)
		elif "loop" in s_stream: s_stream.loop = true
	sfx_snore.stream = s_stream
	sfx_snore.bus = "Master"
	add_child(sfx_snore)

	# Dış referansları bul
	grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	arayuz = get_tree().get_first_node_in_group("Arayuz")

	# Tabure pozisyonunu kaydet (yedek global_position clamp)
	tabure_pozisyonu = global_position
	tabure_pozisyonu_kaydedildi = true

	# Skeleton3D ve Hips kemiğini bul — direkt path ile (find_child başarısız oluyordu)
	_skeleton = get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if not _skeleton:
		# Yedek: recursive arama
		_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_hips_bone_idx = _skeleton.find_bone("Hips")
		if _hips_bone_idx >= 0:
			print("📌 Hips kemiği bulundu (idx=%d)" % _hips_bone_idx)
		else:
			print("⚠️ Hips kemiği bulunamadı! Mevcut kemikler:")
			for i in range(_skeleton.get_bone_count()):
				print("  Bone %d: %s" % [i, _skeleton.get_bone_name(i)])
	else:
		print("⚠️ Skeleton3D bulunamadı! Alt düğümler:")
		for child in get_children():
			print("  ", child.name, " -> ", child.get_class())
			for sub in child.get_children():
				print("    ", sub.name, " -> ", sub.get_class())

	# Harici FBX'ten ayakta durma animasyonunu otomatik yükle (Manuel kopyalamaya gerek kalmaz)
	_harici_animleri_yukle()

	# Animasyon isimlerini FBX import isimlerinden otomatik bul
	_animasyonlari_kesfet()

	# Uyuklama animasyonundan position_3d tracklerini kaldır
	# (Bu trackler Hips kemiğini yanlış konuma snaplayıyor)
	_uyuklama_pozisyon_tracklarini_kaldir()
	
	# Ayakta animasyonundan position_3d tracklerini kaldır (0.0 frame yani ayakta pozuyla hizala)
	# (Böylece Boss grid içine girmek yerine sandalyenin önünde dikilir)
	_ayakta_pozisyon_tracklarini_kaldir()

	# Ölüm sinyalini dinle
	if GameManager and GameManager.has_signal("boss_oldu"):
		if not GameManager.boss_oldu.is_connected(_on_boss_oldu_sinyali):
			GameManager.boss_oldu.connect(_on_boss_oldu_sinyali)

	# 1 saniye sonra oturma sekansını başlat
	await get_tree().create_timer(1.0).timeout
	if _oldu_mu_kontrol(): return
	otura_gec()


func _process(_delta):
	# Hips kemiğini oturma sonrası pozisyonuna kilitle
	# AnimationPlayer position_3d track'i kaldırıldığı için
	# sadece güvenlik olarak bone pozisyonunu yazıyoruz
	if _hips_poz_kilitli and _skeleton and _hips_bone_idx >= 0:
		if suanki_durum not in ["SALDIRI", "AYAKTA"]:
			_skeleton.set_bone_pose_position(_hips_bone_idx, _hips_oturma_sonu_poz)

func _harici_animleri_yukle():
	"""İçe aktarılan Harici FBX'teki animasyonu kalıcı AnimationPlayer'a kopyalar."""
	if not harici_ayakta_anim_fbx: return
	if not anim_player: return
	
	print("⏳ Harici ayakta durma animasyonu FBX içinden yükleniyor...")
	var gecici_fbx = harici_ayakta_anim_fbx.instantiate()
	var fbx_player: AnimationPlayer = gecici_fbx.find_child("AnimationPlayer", true, false)
	
	if fbx_player:
		var list = fbx_player.get_animation_list()
		for a_name in list:
			if not a_name.to_upper().contains("RESET") and not a_name.to_upper().contains("REST"):
				var anim_kopyasi = fbx_player.get_animation(a_name).duplicate()
				anim_kopyasi.loop_mode = Animation.LOOP_LINEAR # Otomatik döngüye al
				
				var lib: AnimationLibrary
				if anim_player.has_animation_library(""):
					lib = anim_player.get_animation_library("")
				else:
					lib = AnimationLibrary.new()
					anim_player.add_animation_library("", lib)
				
				var yeni_isim = "a_otomatik_harici_ayakta_idle"
				if not lib.has_animation(yeni_isim):
					lib.add_animation(yeni_isim, anim_kopyasi)
					print("✅ Harici animasyon başarıyla aktarıldı: ", yeni_isim)
				break
	
	gecici_fbx.queue_free()

func _animasyonlari_kesfet():
	"""AnimationPlayer kütüphanesini tarayarak gerçek animasyon isimlerini bulur."""
	if not anim_player:
		push_warning("⚠️ AnimationPlayer bulunamadı!")
		return

	var anim_listesi = anim_player.get_animation_list()
	print("📋 Mevcut animasyonlar: ", anim_listesi)

	for anim_adi in anim_listesi:
		var kucuk = anim_adi.to_lower()

		# Oturma animasyonu: "Stand_to_Sit" veya "Sit_Transition" içeriyorsa
		if oturma_anim_adi.is_empty():
			if kucuk.contains("stand_to_sit") or kucuk.contains("sit_transition"):
				oturma_anim_adi = anim_adi
				print("🔍 Oturma animasyonu bulundu: ", anim_adi)

		# Uyuklama animasyonu: "Doze_Off" veya "Sit_and_Doze" veya "Uyuklama" içeriyorsa
		if uyuklama_anim_adi.is_empty():
			if kucuk.contains("doze_off") or kucuk.contains("sit_and_doze") or kucuk.contains("uyuklama"):
				uyuklama_anim_adi = anim_adi
				print("🔍 Uyuklama animasyonu bulundu: ", anim_adi)

		# Ayakta durma animasyonu: "Idle", "Stand" veya "Ayakta" içeriyorsa
		if ayakta_durma_anim_adi.is_empty():
			if kucuk.contains("ayakta") or kucuk.contains("idle") or (kucuk.contains("stand") and not kucuk.contains("sit")):
				ayakta_durma_anim_adi = anim_adi
				print("🔍 Ayakta durma animasyonu bulundu: ", anim_adi)

	# Bulunamadıysa uyarı ver (ama çökmez)
	if oturma_anim_adi.is_empty():
		push_warning("⚠️ Oturma animasyonu bulunamadı! Mevcut: " + str(anim_listesi))
	if uyuklama_anim_adi.is_empty():
		push_warning("⚠️ Uyuklama animasyonu bulunamadı! Mevcut: " + str(anim_listesi))
	if ayakta_durma_anim_adi.is_empty():
		push_warning("⚠️ Ayakta durma animasyonu bulunamadı! Mevcut: " + str(anim_listesi))


func _uyuklama_pozisyon_tracklarini_kaldir():
	"""Uyuklama animasyonundaki position_3d track keyframe'lerini
	oturma animasyonunun son frame değerleriyle DEĞİŞTİRİR.
	Track'i silmek yerine değerlerini değiştiriyoruz çünkü
	track silinirse Godot kemikleri rest pose'a (ayakta) resetliyor."""
	if not anim_player or uyuklama_anim_adi.is_empty() or oturma_anim_adi.is_empty():
		return

	var oturma_anim = anim_player.get_animation(oturma_anim_adi)
	var uyuklama_anim = anim_player.get_animation(uyuklama_anim_adi)
	if not oturma_anim or not uyuklama_anim:
		return

	# 1. Oturma animasyonunun son frame'indeki position değerlerini topla
	var oturma_son_pozlar = {}  # NodePath -> Vector3
	for i in range(oturma_anim.get_track_count()):
		if oturma_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var path = oturma_anim.track_get_path(i)
			var son_poz = oturma_anim.position_track_interpolate(i, oturma_anim.length)
			oturma_son_pozlar[path] = son_poz

	# 2. Uyuklama'daki position tracklerinin TÜM keyframe'lerini
	#    oturma'nın son frame değeriyle değiştir
	var duzeltilen = 0
	for i in range(uyuklama_anim.get_track_count() - 1, -1, -1):
		if uyuklama_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var path = uyuklama_anim.track_get_path(i)

			if path in oturma_son_pozlar:
				# Oturma'nın son pozisyonunu al
				var sabit_poz = oturma_son_pozlar[path]
				# Tüm keyframe değerlerini aynı pozisyona çek
				for k in range(uyuklama_anim.track_get_key_count(i)):
					uyuklama_anim.track_set_key_value(i, k, sabit_poz)
				duzeltilen += 1
				print("🔧 [Uyuklama] %s -> sabit poz: %s" % [path, sabit_poz])
			else:
				# Oturma'da karşılığı yok — bu tracki kaldırmak güvenli
				uyuklama_anim.remove_track(i)
				print("🔧 [Uyuklama] karşılıksız track kaldırıldı: ", path)

	if duzeltilen > 0:
		print("✅ Uyuklama'da %d position track sabitlendi (drift fix)" % duzeltilen)
	else:
		print("ℹ️ Uyuklama'da düzeltilecek position track bulunamadı")

func _ayakta_pozisyon_tracklarini_kaldir():
	"""Ayakta animasyonundaki position_3d track keyframe'lerini
	oturma animasyonunun ILK frame (zaman 0.0) değerleriyle DEĞİŞTİRİR.
	Böylece Boss FBX'in 0 noktasından ötürü grid içine kaymaz."""
	if not anim_player or ayakta_durma_anim_adi.is_empty() or oturma_anim_adi.is_empty():
		return

	var oturma_anim = anim_player.get_animation(oturma_anim_adi)
	var ayakta_anim = anim_player.get_animation(ayakta_durma_anim_adi)
	if not oturma_anim or not ayakta_anim:
		return

	# 1. Oturma animasyonunun 0.0 frame'indeki position değerlerini topla (Ayağa kalktığı sıfır noktası)
	var oturma_ilk_pozlar = {}  # NodePath -> Vector3
	for i in range(oturma_anim.get_track_count()):
		if oturma_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var path = oturma_anim.track_get_path(i)
			var ilk_poz = oturma_anim.position_track_interpolate(i, 0.0)
			oturma_ilk_pozlar[path] = ilk_poz

	# 2. Ayakta'daki position tracklerinin TÜM keyframe'lerini
	#    oturma'nın ilk frame değeriyle değiştir
	var duzeltilen = 0
	for i in range(ayakta_anim.get_track_count() - 1, -1, -1):
		if ayakta_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var path = ayakta_anim.track_get_path(i)

			if path in oturma_ilk_pozlar:
				var sabit_poz = oturma_ilk_pozlar[path]
				for k in range(ayakta_anim.track_get_key_count(i)):
					ayakta_anim.track_set_key_value(i, k, sabit_poz)
				duzeltilen += 1
				print("🔧 [Ayakta] %s -> sabit poz: %s" % [path, sabit_poz])
			else:
				ayakta_anim.remove_track(i)
				print("🔧 [Ayakta] karşılıksız track kaldırıldı: ", path)

	if duzeltilen > 0:
		print("✅ Ayakta animasyonunda %d position track sabitlendi (grid clipping fix)" % duzeltilen)
	else:
		print("ℹ️ Ayakta animasyonunda düzeltilecek position track bulunamadı")


# ==========================================
# GÜVENLİ ANİMASYON YARDIMCISI
# ==========================================

func _guvenli_anim_oynat(anim_adi: String, hiz: float = 1.0, tersten: bool = false) -> bool:
	"""Animasyonu güvenli bir şekilde oynatır. Bulunamazsa false döner, await deadlock olmaz."""
	if not is_instance_valid(anim_player) or anim_adi.is_empty():
		push_warning("⚠️ Animasyon oynatılamıyor: player yok veya isim boş.")
		return false

	if not anim_player.has_animation(anim_adi):
		push_warning("⚠️ Animasyon bulunamadı: " + anim_adi)
		return false

	# Looping animasyonlarda await yapma — deadlock olur
	var anim = anim_player.get_animation(anim_adi)
	var is_looping = anim and anim.loop_mode != Animation.LOOP_NONE

	if tersten:
		anim_player.play(anim_adi, -1, hiz, true)
	else:
		anim_player.play(anim_adi, -1, hiz)

	if is_looping:
		# Looping animasyonlarda bekleme yapma, hemen dön
		return true

	await anim_player.animation_finished
	return true


func _animasyonu_durdur():
	"""AnimationPlayer'ı güvenli durdurur."""
	if is_instance_valid(anim_player) and anim_player.is_playing():
		anim_player.stop()


# ==========================================
# GÜVENLİ LOOK_AT (Issue 1: det == 0 fix)
# ==========================================

func _guvenli_look_at(hedef: Vector3):
	"""look_at() çağrısı öncesi scale ve mesafe kontrolü yapar."""
	if scale.is_zero_approx():
		return
	var fark = hedef - global_position
	fark.y = 0
	if fark.length_squared() < 0.001:
		return
	look_at(hedef, Vector3.UP)


# ==========================================
# TABURE POZİSYONU SABITLEME (Issue 2: Drift fix)
# ==========================================

func _pozisyonu_tabureye_sabitle():
	"""Boss'u kayıtlı tabure pozisyonuna geri sabitler."""
	if tabure_pozisyonu_kaydedildi:
		global_position = tabure_pozisyonu


# ==========================================
# ÖLÜM KONTROLÜ
# ==========================================

func _oldu_mu_kontrol() -> bool:
	"""Her await sonrasında çağrılır. Ölmüşse true döner."""
	return oldu_mu or suanki_durum == str(DURUM_OLDU)


func _on_boss_oldu_sinyali():
	"""GameManager'dan gelen ölüm sinyali."""
	oldu_mu = true
	suanki_durum = str(DURUM_OLDU)

	# Animasyonu durdur
	_animasyonu_durdur()

	# Kamerayı oyuncuya iade et
	_kamerayi_oyuncuya_ver()

	# Kilit varsa aç
	if LevelManager:
		LevelManager.is_boss_acting = false

	# Scale'ı sıfıra yakın yap (det == 0 hatasından kaçın, TAM sıfır yasak)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 1.0)
	tween.tween_callback(queue_free)


# ==========================================
# KAMERA YÖNETİMİ
# ==========================================

func _kamerayi_oyuncuya_ver():
	"""Kamerayı Oyuncu grubundaki Camera3D'ye döndürür."""
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and is_instance_valid(oyuncu):
		var cam = oyuncu.find_child("Camera3D", true, false)
		if cam and cam is Camera3D:
			cam.make_current()
			print("🎥 Kamera oyuncuya iade edildi.")
	else:
		push_warning("⚠️ Oyuncu bulunamadı, kamera iade edilemedi!")


func _kamerayi_bossa_ver():
	"""Kamerayı Boss'un Camera3D'sine verir."""
	if kamera_boss and kamera_boss is Camera3D:
		kamera_boss.make_current()
		print("🎥 Kamera Boss'a odaklandı.")
	else:
		push_warning("⚠️ Boss kamerası bulunamadı!")


# ==========================================
# OTURMA & UYUKLAMA
# ==========================================

func otura_gec():
	"""Boss'u tabureye oturtur, sonra uyuklamaya geçirir."""
	if _oldu_mu_kontrol(): return

	var basarili = await _guvenli_anim_oynat(oturma_anim_adi)
	if basarili:
		print("🛋️ Canavar tabureye oturdu.")
	else:
		print("⚠️ Oturma animasyonu atlandı.")

	# Oturma sonrası Hips kemiğinin pozisyonunu kaydet ve kilitle
	# Bu pozisyondayken uyuklamalı — Uyuklama animasyonu bunu bozmasın
	if _skeleton and _hips_bone_idx >= 0:
		_hips_oturma_sonu_poz = _skeleton.get_bone_pose_position(_hips_bone_idx)
		_hips_poz_kilitli = true
		print("🔒 Hips oturma sonu pozisyonu kilitlendi: ", _hips_oturma_sonu_poz)

	# Global pozisyonu da sabitle
	_pozisyonu_tabureye_sabitle()

	if _oldu_mu_kontrol(): return
	uyuklamaya_basla()


func uyuklamaya_basla():
	"""Uyuklama döngüsünü başlatır."""
	if _oldu_mu_kontrol(): return

	suanki_durum = "UYUKLAMA"

	# Pozisyonu tekrar sabitle (güvenlik)
	_pozisyonu_tabureye_sabitle()

	if not uyuklama_anim_adi.is_empty() and is_instance_valid(anim_player) and anim_player.has_animation(uyuklama_anim_adi):
		anim_player.play(uyuklama_anim_adi)
		if sfx_snore and not sfx_snore.playing:
			sfx_snore.play()
		print("💤 Canavar uyuklamaya başladı.")
	else:
		print("⚠️ Uyuklama animasyonu bulunamadı veya boş!")


# ==========================================
# RECOVERY STATE RESET (Issue 4)
# ==========================================

func ayakta_beklemeye_gec():
	"""Canavarı ayakta (idle) bekleme animasyonuna geçirir."""
	if _oldu_mu_kontrol(): return
	suanki_durum = "AYAKTA"

	# Pozisyonu tekrar sabitle
	_pozisyonu_tabureye_sabitle()

	if not ayakta_durma_anim_adi.is_empty() and is_instance_valid(anim_player) and anim_player.has_animation(ayakta_durma_anim_adi):
		anim_player.play(ayakta_durma_anim_adi)
		print("🧍 Canavar ayakta beklemeye başladı.")
	else:
		print("⚠️ Ayakta durma animasyonu bulunamadı veya boş!")

func boss_durumu_sifirla():
	"""Oyuncu iyileştiğinde veya tur arası boss'u UYUKLAMA veya AYAKTA durumuna döndürür."""
	if _oldu_mu_kontrol(): return

	print("🔄 Boss durumu sıfırlanıyor...")

	# Devam eden her şeyi durdur
	_animasyonu_durdur()

	# Kamerayı oyuncuya iade et (takılmış olabilir)
	_kamerayi_oyuncuya_ver()

	# Pozisyonu sabitle
	_pozisyonu_tabureye_sabitle()

	# LevelManager kilidini aç
	if LevelManager:
		LevelManager.is_boss_acting = false

	if ilk_uyanisi_yapti_mi:
		ayakta_beklemeye_gec()
	else:
		# UYUKLAMA durumuna geç
		suanki_durum = "UYUKLAMA"
		if not uyuklama_anim_adi.is_empty() and is_instance_valid(anim_player) and anim_player.has_animation(uyuklama_anim_adi):
			anim_player.play(uyuklama_anim_adi)
			print("💤 Boss temiz UYUKLAMA durumuna döndü.")


# ==========================================
# SALDIRI SÜRECİ (ANA GİRİŞ NOKTASI)
# ==========================================

func saldiri_baslat():
	"""Ana saldırı giriş noktası. LevelManager tarafından çağrılır."""
	# Pyro koridor katmanlarında çalışma
	if GameManager and GameManager.pyro_aktif:
		saldiri_tamamlandi.emit()
		return

	if _oldu_mu_kontrol():
		saldiri_tamamlandi.emit()
		return

	# 1. Boss kamerasını aktif et
	_kamerayi_bossa_ver()

	# 2. Eğer uyukluyorsa → ayağa kalk (oturma animasyonu TERSTEN)
	if suanki_durum == "UYUKLAMA":
		if sfx_snore and sfx_snore.playing:
			sfx_snore.stop()
		
		_animasyonu_durdur()

		var uyanma_basarili = await _guvenli_anim_oynat(oturma_anim_adi, -1.0, true)
		ilk_uyanisi_yapti_mi = true

		if _oldu_mu_kontrol():
			_kamerayi_oyuncuya_ver()
			saldiri_tamamlandi.emit()
			return

		# Uyanma sonrası pozisyonu sabitle
		_pozisyonu_tabureye_sabitle()

		if uyanma_basarili:
			print("🗯️ Canavar uyandı ve ayağa kalktı!")
		else:
			print("⚠️ Uyanma animasyonu atlandı.")

	# 3. AYAKTA durumuna geç
	if ilk_uyanisi_yapti_mi:
		ayakta_beklemeye_gec()
	else:
		suanki_durum = "AYAKTA"

	# "BOSS KARAR VERİYOR..." UI mesajı
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster("BOSS KARAR VERİYOR...", 1.5)

	await get_tree().create_timer(1.0).timeout

	if _oldu_mu_kontrol():
		_kamerayi_oyuncuya_ver()
		saldiri_tamamlandi.emit()
		return

	# --- 👁️ GLITCH PARRY WINDOW (PRE-ATTACK) ---
	if not _saldiri_resume_ediliyor:
		var parry_basarili = await pre_attack()
		if parry_basarili:
			# PARRY EDİLDİ! Saldırı sekansını tamamen durdur.
			# Boss, Ghost Move periyodu bitene veya oyuncu blok koyana kadar donar.
			# (OyunOdasi / GameManager üzerinden tekrar tetiklenebilir)
			return
	_saldiri_resume_ediliyor = false
	# -------------------------------------------

	# 4. Saldırı tipi seç
	suanki_durum = "SALDIRI"
	var saldiri_tipi: String

	# Önceki turda Kahin Gözü için belirlendiyse onu kullan
	if sonraki_saldiri_tipi != "":
		saldiri_tipi = sonraki_saldiri_tipi
		sonraki_saldiri_tipi = ""
	else:
		var sans = randf()
		if sans < 0.35:
			saldiri_tipi = "TAS"
		elif sans < 0.70:
			saldiri_tipi = "ASIT"
		else:
			saldiri_tipi = "ZAR"

	# Bir sonraki tur için sıradaki saldırı tipini şimdi belirle ve GameManager'a yaz
	_bir_sonraki_saldiriyi_belirle()

	# 5. Telegraph efekti + UI bildirimi
	await _telegraph_baslat(saldiri_tipi)

	if _oldu_mu_kontrol():
		_kamerayi_oyuncuya_ver()
		saldiri_tamamlandi.emit()
		return

	# Attack release sound with 450ms delay
	var a_sfx = AudioStreamPlayer3D.new()
	a_sfx.stream = load("res://Sesler/attack_release.mp3")
	a_sfx.bus = "Master"
	a_sfx.max_distance = 20.0
	add_child(a_sfx)
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(a_sfx):
			a_sfx.play()
			a_sfx.finished.connect(a_sfx.queue_free)
	)

	# 6. Saldırıyı uygula
	match saldiri_tipi:
		"TAS", "ASIT":
			await _mermi_firlat(saldiri_tipi)
		"ZAR":
			await _zar_sekansi()

# ==========================================
# 🌌 GLITCH PARRY (REALITY DENIAL)
# ==========================================

func pre_attack() -> bool:
	"""
	Saldırı öncesi kısa (0.3s) pencere açar. 
	Oyuncu bu pencerede sağ tıklarsa gerçekliği inkar eder (Glitch Parry).
	"""
	if not glitch_yuzu_dokusu: return false # Asset yoksa sistemi atla
	
	# Pencereyi Aç
	if GameManager: GameManager.is_parry_window_open = true
	
	# Ekranda Korkunç Yüz Göster
	glitch_ui_rect = TextureRect.new()
	glitch_ui_rect.texture = glitch_yuzu_dokusu
	glitch_ui_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glitch_ui_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	glitch_ui_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_ui_rect.modulate = Color(1, 1, 1, 0.8) # Yarım transparan
	
	# GLITCH SHADER EKLE
	var mat = ShaderMaterial.new()
	var shader = load("res://Materials_Shaders/glitch_yuz.gdshader")
	if shader: mat.shader = shader
	glitch_ui_rect.material = mat
	
	# En üste çizilmesi için CanvasLayer
	var canvas = CanvasLayer.new()
	canvas.layer = 99 
	canvas.add_child(glitch_ui_rect)
	add_child(canvas)
	
	# process_always=false parametresi ile, TutorialManager oyunu dondurduğunda (pause) bu zamanlayıcı da donacak, böylece arka planda bitmeyecek!
	await get_tree().create_timer(0.5, false).timeout
	
	# Süre Bitti. Pencere hala açık mı? (Oyuncu tıklamadıysa true kalır)
	if GameManager and GameManager.is_parry_window_open:
		# TIKLAYAMADI! Normal saldırıya devam.
		GameManager.is_parry_window_open = false
		if is_instance_valid(canvas): canvas.queue_free()
		return false
	else:
		# TIKLADI! (oyuncu.gd is_parry_window_open'ı false yaptı)
		# Ses Çalar
		if kirik_cam_sesi:
			var as_player = AudioStreamPlayer3D.new()
			as_player.stream = kirik_cam_sesi
			as_player.max_distance = 15.0
			add_child(as_player)
			as_player.play()
			as_player.finished.connect(as_player.queue_free)
			
		print("❌ BOSS ATTACK CANCELLED! (GLITCH PARRY)")
		return true

func glitch_yuzu_kapat():
	if is_instance_valid(glitch_ui_rect) and glitch_ui_rect.get_parent():
		glitch_ui_rect.get_parent().queue_free()

func gercek_saldiri_basa_don():
	"""
	Ghost Move sırasında oyuncu 5 saniye boyunca HİÇBİR ŞEY yapmazsa,
	GameManager bu fonksiyonu çağırarak Boss'u kaldığı yerden devam ettirir.
	"""
	if _oldu_mu_kontrol(): return
	print("⏳ Ghost Move bitti, hamle yapılmadı. Boss saldırıya geçiyor!")
	await get_tree().create_timer(0.5).timeout
	_saldiri_resume_ediliyor = true
	saldiri_baslat()

# ==========================================
# TELEGRAPH (UYARI EFEKTİ)
# ==========================================

func _telegraph_baslat(tip: String):
	"""Saldırı öncesi UI bildirimi."""
	if _oldu_mu_kontrol(): return

	# UI mesajı — saldırı tipi
	var mesaj = ""
	match tip:
		"TAS": mesaj = "KAYA FIRLATIYOR!"
		"ASIT": mesaj = "ASİT TÜKÜRÜYOR!"
		"ZAR": mesaj = "ZAR ATIYOR!"

	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster(boss_adi + ": " + mesaj, 2.0)

	var w_sfx = AudioStreamPlayer3D.new()
	w_sfx.stream = load("res://Sesler/while_attack.mp3")
	w_sfx.bus = "Master"
	w_sfx.max_distance = 25.0
	add_child(w_sfx)
	w_sfx.play()
	w_sfx.finished.connect(w_sfx.queue_free)

	print("⚔️ Boss saldırısı: ", tip, " — ", mesaj)

	# Kısa bekleme süresi (telegraph)
	await get_tree().create_timer(1.5).timeout


# ─── KAHİN GÖZÜ: BİR SONRAKİ SALDIRIYI BELİRLE ─────────────────────────────
func _bir_sonraki_saldiriyi_belirle():
	"""Bir sonraki turun saldırı tipini önceden belirler (Kahin Gözü için)."""
	var sans = randf()
	if sans < 0.35:
		sonraki_saldiri_tipi = "TAS"
	elif sans < 0.70:
		sonraki_saldiri_tipi = "ASIT"
	else:
		sonraki_saldiri_tipi = "ZAR"

	if GameManager:
		GameManager.sonraki_boss_saldirisi = sonraki_saldiri_tipi

	print("👁️ Kahin Gözü: Sıradaki saldırı = ", sonraki_saldiri_tipi)


# ==========================================
# MERMİ FIRLATMA (TAS / ASIT)
# ==========================================

func _mermi_firlat(tip: String):
	"""Grid üzerinde rastgele bir hücreye mermi fırlatır."""
	if _oldu_mu_kontrol():
		await _sirayi_bitir_ve_tekrar_otur()
		return

	# Grid yoksa zar at
	if not grid or not grid.has_method("hucreyi_kilitle"):
		push_warning("⚠️ Grid bulunamadı, zar sekansına geçiliyor.")
		await _zar_sekansi()
		return

	# Rastgele hücre seç
	var grid_boyutu = grid.grid_boyutu if "grid_boyutu" in grid else Vector2i(5, 5)
	var rx = randi_range(0, grid_boyutu.x - 1)
	var ry = randi_range(0, grid_boyutu.y - 1)
	var hedef_hucre = Vector2i(rx, ry)

	# Hedef pozisyonu hesapla
	var grid_pos = Vector3.ZERO
	if grid.has_method("cell_center_world"):
		var cell_pos = grid.cell_center_world(hedef_hucre)
		grid_pos = cell_pos

	var hedef_y = mermi_zemini_y
	if "engel_yuksekligi" in grid:
		hedef_y = grid.global_position.y + grid.engel_yuksekligi

	var final_pos = Vector3(grid_pos.x, hedef_y, grid_pos.z)

	# ---- Mermi oluştur ----
	var mermi = MeshInstance3D.new()
	mermi.set_as_top_level(true)

	var renk: Color
	if tip == "TAS":
		var box = BoxMesh.new()
		box.size = Vector3(0.5, 0.5, 0.5)
		mermi.mesh = box
		renk = Color.GRAY
	else: # ASIT
		var sphere = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		mermi.mesh = sphere
		renk = Color.GREEN

	var mat = StandardMaterial3D.new()
	mat.albedo_color = renk
	mat.emission_enabled = true
	mat.emission = renk
	mermi.material_override = mat

	# Sahneye ekle ve Boss pozisyonundan fırlat
	get_tree().current_scene.add_child(mermi)
	mermi.global_position = global_position + Vector3(0, 1.5, 0)

	# Tween ile hedefe uçur
	var tween = create_tween()
	tween.tween_property(mermi, "global_position", final_pos, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished

	# Mermiyi sil
	if is_instance_valid(mermi):
		mermi.queue_free()

	# Grid hücresini kilitle
	if is_instance_valid(grid) and grid.has_method("hucreyi_kilitle"):
		grid.hucreyi_kilitle(hedef_hucre, tip)

	# Ölüm kontrolü
	if _oldu_mu_kontrol():
		_kamerayi_oyuncuya_ver()
		saldiri_tamamlandi.emit()
		return

	# Saldırı bitti → otur
	await _sirayi_bitir_ve_tekrar_otur()


# ==========================================
# ZAR SEKANSI
# ==========================================

func _zar_sekansi():
	"""Zar atma saldırısı — LevelManager'a yönlendirir."""
	if _oldu_mu_kontrol():
		await _sirayi_bitir_ve_tekrar_otur()
		return

	if LevelManager and LevelManager.has_method("zar_at_animasyonunu_baslat"):
		LevelManager.zar_at_animasyonunu_baslat()
		# LevelManager zar sekansını ve kamerayı yönetir.
		# Zar bitimini bekle
		await get_tree().create_timer(2.0).timeout

		if _oldu_mu_kontrol():
			saldiri_tamamlandi.emit()
			return

		# Geri otur veya ayakta bekle (kamera LevelManager tarafından zaten döndürülecek)
		if ilk_uyanisi_yapti_mi:
			ayakta_beklemeye_gec()
		else:
			otura_gec()
		saldiri_tamamlandi.emit()
	else:
		# Zar metodu yoksa → normal bitir
		await _sirayi_bitir_ve_tekrar_otur()


# ==========================================
# SALDIRI SONRASI — KAMERA İADE + GERİ OTUR
# ==========================================

func _sirayi_bitir_ve_tekrar_otur():
	"""Saldırı bittikten sonra kamerayı iade et ve canavarı geri oturt (veya ayakta bekleme pozuna geç)."""
	_kamerayi_oyuncuya_ver()

	if _oldu_mu_kontrol():
		saldiri_tamamlandi.emit()
		return

	# Oturma animasyonu normal yönde veya ayakta bekle
	if ilk_uyanisi_yapti_mi:
		ayakta_beklemeye_gec()
	else:
		await otura_gec()

	saldiri_tamamlandi.emit()
