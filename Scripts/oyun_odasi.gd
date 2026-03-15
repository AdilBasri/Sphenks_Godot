extends Node3D

# --- BÖLÜM 1: LEVEL VE IŞINLANMA REFERANSLARI ---
@export_group("Level Sistemi")
@export var market_spawn: Marker3D
@export var campfire_spawn: Marker3D
@export var start_spawn: Marker3D

# --- BÖLÜM 2: BOSS VE ZAR SİSTEMİ REFERANSLARI ---
@export_group("Boss Zar Sistemi")
@export var zar_sahnesi: PackedScene
@export var zar_atik_noktasi: Node3D
@export var zar_kamerasi: Camera3D
@export var oyuncu_kamerasi: Camera3D
@export var oyuncu: CharacterBody3D 
@export var hasar_label: Label
@export var olum_ekrani_sahnesi: PackedScene

# --- 🔥 YENİ: PYRO DÜŞMAN REFERANSI 🔥 ---
@export var pyro_dusman_sahnesi: PackedScene # Inspector'dan PyroDusman.tscn'yi buraya at!

# --- DİĞER REFERANSLAR ---
@onready var yan_sehpa = get_node_or_null("YanSehpa") 

# --- DEĞİŞKENLER ---
var zar_firlatiliyor_mu : bool = false
var atilan_zarlar = []
var toplam_sonuc = 0
var duran_zar_sayisi = 0
var boss_uyandi_mi : bool = false 
var boss_tamamen_oldu : bool = false 
var beklenen_zar_sayisi: int = 2
var blok_sayaci: int = 0 # Zar Boss'u (Normal) için sayaç

func _ready():
	print("--- OYUN ODASI BAŞLATILIYOR ---")
	
	# 1. LEVEL MANAGER KAYDI VE ATMOSFER AYARI
	if LevelManager:
		# Konumları Kaydet
		var p1 = market_spawn.global_position if market_spawn else Vector3.ZERO
		var p2 = campfire_spawn.global_position if campfire_spawn else Vector3.ZERO
		var p3 = start_spawn.global_position if start_spawn else (oyuncu.global_position if oyuncu else Vector3.ZERO)
		LevelManager.konumlari_kaydet(p1, p2, p3, oyuncu, self)
		
		# Atmosferi Ayarla
		_atmosferi_guncelle()
		
		# --- 🔥 PYRO DÜŞMANLARI YARAT 🔥 ---
		if GameManager.pyro_aktif:
			_pyro_dusmanlarini_yarat()
	
	if yan_sehpa and yan_sehpa.has_method("sehpayi_guncelle"):
		yan_sehpa.sehpayi_guncelle()

	# --- OTOMATİK REFERANS BULMA (YENİ) ---
	# Eğer editörden atanmamışsa (null ise), sahnede ismen arayıp bulalım.
	_zar_sistemini_bagla()

	if zar_kamerasi: zar_kamerasi.current = false
	if oyuncu_kamerasi: oyuncu_kamerasi.current = true

	# --- SİNYALLER ---
	if GameManager:
		if not GameManager.blok_yerlestirildi.is_connected(_on_blok_yerlestirildi):
			GameManager.blok_yerlestirildi.connect(_on_blok_yerlestirildi)
		if not GameManager.boss_oldu.is_connected(_on_boss_oldu):
			GameManager.boss_oldu.connect(_on_boss_oldu)
		if not GameManager.satir_patladi.is_connected(_on_satir_patladi):
			GameManager.satir_patladi.connect(_on_satir_patladi)
	
	if oyuncu and not oyuncu.oyuncu_oldu.is_connected(_on_oyuncu_oldu):
		oyuncu.oyuncu_oldu.connect(_on_oyuncu_oldu)
		
	if LevelManager and LevelManager.suanki_katman == 1:
		if TutorialManager and not GameManager.tutorial_tamamlandi:
			TutorialManager.start_tutorial()

func _pyro_dusmanlarini_yarat():
	if not pyro_dusman_sahnesi: return
		
	var veri = LevelManager.bolum_verilerini_getir()
	var adet = veri.get("dusman_sayisi", 5)
	
	print("🦇 PYRO: ", adet, " düşman GÜVENLİ KÖŞELERE yaratılıyor.")
	
	# --- GÜVENLİ KÖŞELER (Daraltılmış) ---
	# Odan -8 ise, biz -5 kullanıyoruz ki duvarın içine girmesin.
	var koseler = [
		Vector3(-5.0, 1.5, -5.0), # Sol Arka
		Vector3( 5.0, 1.5, -5.0), # Sağ Arka
		Vector3(-5.0, 1.5,  5.0), # Sol Ön
		Vector3( 5.0, 1.5,  5.0)  # Sağ Ön
	]
	
	for i in range(adet):
		var dusman = pyro_dusman_sahnesi.instantiate()
		add_child(dusman)
		
		var secilen_pos = Vector3.ZERO
		
		# Oyuncuya en uzak köşeyi seç
		if oyuncu:
			var en_uzak_mesafe = 0.0
			for kose in koseler:
				var mesafe = oyuncu.global_position.distance_to(kose)
				if mesafe > en_uzak_mesafe:
					en_uzak_mesafe = mesafe
					secilen_pos = kose
		else:
			secilen_pos = koseler.pick_random()
		
		# Hafif dağınıklık (Çok az)
		secilen_pos.x += randf_range(-1.0, 1.0)
		secilen_pos.z += randf_range(-1.0, 1.0)
		
		dusman.global_position = secilen_pos
		print("🦇 YARASA KONUMU: ", secilen_pos) # Konsola bak, nerede doğmuşlar?

func _atmosferi_guncelle():
	var veri = LevelManager.bolum_verilerini_getir()
	var hedef_renk = veri.get("atmosfer_rengi", Color.WHITE)
	
	var env = null
	var cam = get_viewport().get_camera_3d()
	if cam and cam.environment:
		env = cam.environment
	else:
		var world_env_node = get_parent().find_child("WorldEnvironment", true, false)
		if world_env_node: env = world_env_node.environment
	
	if env:
		if GameManager.pyro_aktif:
			print("🔴 GÖRSEL: PYRO Atmosferi (KIRMIZI)")
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.2, 0.0, 0.0) 
			env.volumetric_fog_enabled = true
			env.volumetric_fog_albedo = Color(0.8, 0.1, 0.1) 
			env.volumetric_fog_density = 0.03
			env.adjustment_enabled = true
			env.adjustment_saturation = 1.2
		else:
			print("⚪ GÖRSEL: Normal Atmosfer")
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.1, 0.1, 0.1) 
			env.volumetric_fog_enabled = false
			env.adjustment_enabled = false
	else:
		print("⚠️ UYARI: Environment bulunamadı.")

# --- TETİKLEYİCİLER ---
func _on_satir_patladi():
	if boss_tamamen_oldu: return
	if not boss_uyandi_mi and not GameManager.pyro_aktif:
		boss_uyandi_mi = true
		print("BOSS AWAKENED!")
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz: arayuz.bilgi_goster(DilYoneticisi.metin_al("boss_uyandi"), 3.0)

func _on_blok_yerlestirildi():
	if boss_tamamen_oldu: return
	if GameManager.pyro_aktif: return # Pyro'da boss saldırmaz
	
	# --- 👁️ GLITCH PARRY BYPASS (FREE BLOCK BUT BOSS STILL GETS ITS TURN) ---
	if GameManager and GameManager.ghost_move_active:
		print("🌌 BLOCK PLACED IN GHOST MODE! Boss counter-attack allowed to resume.")
		GameManager.end_ghost_move()
		# Boss, _saldiri_resume_ediliyor modunda olduğu için telegraph/yüz kısmını atlayarak direkt saldıracak
		# Yani oyuncu bedavadan 1 blok koymuş oldu, ancak oyun döngüsü devam ediyor
		var boss = get_tree().get_first_node_in_group("Dusman")
		if boss and boss.has_method("gercek_saldiri_basa_don"):
			boss.gercek_saldiri_basa_don()
		return # GameManager'in boss'u devam ettirmesi yeterli, LevelManager.boss_saldirisi_baslat()'ı pas geç.

	# Race condition fix: Boss zaten aksiyondaysa blok yerleştirmeyi yoksay
	if LevelManager and LevelManager.is_boss_acting:
		print("🔒 Boss aksiyonda, blok komutu yoksayıldı.")
		return

	if not boss_uyandi_mi:
		print("💤 Boss uyuyor, saldırı yok.")
		return

	print("🧱 Blok yerleşti. Sayaç: ", blok_sayaci)
	
	# Sayaç artırımı (Boss uyandıysa)
	blok_sayaci += 1
	
	# Pre-lock
	if LevelManager:
		LevelManager.is_boss_acting = true
	
	# Saldırı Kararı
	var boss = get_tree().get_first_node_in_group("Dusman")
	var saldiri_yapacak_mi = true
	
	# Eğer Zar Boss'u (NormalBoss) ise 2 adımda bir saldırır
	if boss and boss.name == "NormalBoss":
		if blok_sayaci % 2 != 0:
			saldiri_yapacak_mi = false
			print("🎲 Zar Boss'u (Normal) bu adımı pas geçiyor.")
	
	if saldiri_yapacak_mi:
		print("🚀 Boss saldırısı tetikleniyor...")
		await get_tree().create_timer(1.0).timeout
		if LevelManager and not boss_tamamen_oldu:
			LevelManager.boss_saldirisi_baslat()
	else:
		# Saldırı yoksa kilidi hemen aç
		print("🔓 Saldırı yok, kilit açılıyor.")
		await get_tree().create_timer(0.5).timeout
		if LevelManager:
			LevelManager.is_boss_acting = false

func _on_boss_oldu():
	print("☠️ OYUN ODASI: Boss öldü.")
	boss_uyandi_mi = false
	boss_tamamen_oldu = true
	
	# Arayüze mesaj gönder
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz: 
		if arayuz.has_method("kalici_bilgi_gizle"):
			arayuz.kalici_bilgi_gizle()
		arayuz.bilgi_goster(DilYoneticisi.metin_al("tebrikler_boss"), 5.0)
	
	# Kapı otomatik açılacak (boss scriptleri tarafından)
	print("🚪 Boss öldü — Kapı açılıyor.")

func _kapiyi_ac():
	# KapiSistemi arayalım (MezarOdasi'nin komşusu)
	var kapi = get_parent().find_child("KapiSistemi", true, false)
	if kapi and kapi.has_method("kapiyi_ac"):
		kapi.kapiyi_ac()
		print("🚪 OYUN SONU: Kapı açıldı.")
	else:
		print("⚠️ UYARI: KapıSistemi bulunamadı veya açma metodu yok!")

func _on_oyuncu_oldu():
	print("💀 Oyun Odası: Oyuncu öldü.")
	await get_tree().create_timer(2.0).timeout
	if olum_ekrani_sahnesi:
		var ekran = olum_ekrani_sahnesi.instantiate()
		add_child(ekran)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- ZAR SİSTEMİ ---
func zar_at():
	if zar_firlatiliyor_mu: return
	zar_firlatiliyor_mu = true
	print("🎲 OYUN ODASI: Zar Atma Sekansı Başladı...")
	
	# Kamera Geçişi
	if zar_kamerasi and oyuncu_kamerasi:
		oyuncu_kamerasi.current = false 
		zar_kamerasi.current = true       
	
	toplam_sonuc = 0
	duran_zar_sayisi = 0
	
	# Eski zarları temizle
	for z in atilan_zarlar:
		if is_instance_valid(z): z.queue_free()
	atilan_zarlar.clear()
	
	# --- KRİTİK KONTROL ---
	# GameManager'daki değişkeni kontrol ediyoruz
	if GameManager and GameManager.tek_zar_modu == true:
		beklenen_zar_sayisi = 1
		print("🔹 MOD AKTİF: Sadece 1 zar atılacak.")
	else:
		beklenen_zar_sayisi = 2
		print("🔸 NORMAL MOD: 2 zar atılacak.")
	
	# 1. ZAR (Her zaman atılır)
	_tek_zar_olustur()
	
	# 2. ZAR (SADECE beklenen sayı 1'den büyükse atılır)
	if beklenen_zar_sayisi > 1:
		await get_tree().create_timer(0.2).timeout
		_tek_zar_olustur()
	else:
		print("🚫 İkinci zar iptal edildi (Tek Zar Modu).")

func _tek_zar_olustur():
	if not zar_sahnesi or not zar_atik_noktasi: return
	var yeni_zar = zar_sahnesi.instantiate()
	add_child(yeni_zar)
	yeni_zar.global_position = zar_atik_noktasi.global_position
	yeni_zar.global_position.x += randf_range(-0.5, 0.5)
	var firlatma_gucu = Vector3(0, -5, 0)
	var donme = Vector3(randf()*10, randf()*10, randf()*10)
	if yeni_zar.has_method("firlat"):
		yeni_zar.firlat(firlatma_gucu, donme)
		if not yeni_zar.zar_durdu.is_connected(_on_zar_durdu):
			yeni_zar.zar_durdu.connect(_on_zar_durdu)
		atilan_zarlar.append(yeni_zar)

func _on_zar_durdu(gelen_sayi):
	toplam_sonuc += gelen_sayi
	duran_zar_sayisi += 1
	
	print("Zar durdu. Gelen: ", gelen_sayi, " | Toplam Durdu: ", duran_zar_sayisi, "/", beklenen_zar_sayisi)
	
	# Eğer beklenen sayıya ulaştıysak (1 veya 2)
	if duran_zar_sayisi >= beklenen_zar_sayisi:
		print("✅ Tura ait tüm zarlar durdu. Toplam Sonuç: ", toplam_sonuc)
		
		# Kilit Açılıyor
		zar_firlatiliyor_mu = false 
		
		# Ekrana Hasarı Yazdır
		if hasar_label:
			hasar_label.text = DilYoneticisi.metin_al("hasar") + str(toplam_sonuc)
			hasar_label.visible = true
			var tween = create_tween()
			hasar_label.scale = Vector2(0, 0)
			tween.tween_property(hasar_label, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
		
		await get_tree().create_timer(1.5).timeout
		oyunu_devam_ettir()
		
		if LevelManager: LevelManager.oyuncuya_saldir(toplam_sonuc)
		elif oyuncu: oyuncu.hasar_al(toplam_sonuc)

		await get_tree().create_timer(1.5).timeout
		if hasar_label: hasar_label.visible = false
			
		# Zarları temizle
		for zar in atilan_zarlar:
			if is_instance_valid(zar): zar.queue_free()
		atilan_zarlar.clear()
			
		# Boss Sırasını Bitir (Bunu unutursan oyun donar)
		if LevelManager:
			LevelManager.isleme_alindi_mi = false
			if LevelManager.has_method("_on_boss_isi_bitti"):
				LevelManager._on_boss_isi_bitti()

func oyunu_devam_ettir():
	if oyuncu_kamerasi:
		if zar_kamerasi: zar_kamerasi.current = false
		oyuncu_kamerasi.current = true

# --- DOĞRUDAN BAĞLAMA FONKSİYONU ---
func _zar_sistemini_bagla():
	# 1. ZAR KAMERASI KONTROLÜ
	if not zar_kamerasi:
		print("⚠️ UYARI: Zar Kamerası editörden atanmamış! Otomatik aranıyor...")
		var bulunan = get_tree().current_scene.find_child("ZarKamerasi", true, false)
		if bulunan:
			zar_kamerasi = bulunan
			print("✅ Zar Kamerası BULUNDU: ", zar_kamerasi.get_path())
		else:
			print("❌ HATA: Zar Kamerası sahnede bulunamadı!")

	# 2. ZAR ATIŞ NOKTASI KONTROLÜ
	if not zar_atik_noktasi:
		print("⚠️ UYARI: Zar Atış Noktası editörden atanmamış! Otomatik aranıyor...")
		var bulunan = get_tree().current_scene.find_child("ZarAtisNoktasi", true, false)
		if bulunan:
			zar_atik_noktasi = bulunan
			print("✅ Zar Atış Noktası BULUNDU: ", zar_atik_noktasi.get_path())
		else:
			print("❌ HATA: Zar Atış Noktası sahnede bulunamadı!")


# ==========================================
# TUR SONRASI İŞLEMLER (LevelManager tarafından çağrılır)
# ==========================================

func tur_sonrasi_islemler():
	# Boss temizlik islemleri.
	print("Tur sonrasi islemler calisti.")
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	for b in dusmanlar:
		if is_instance_valid(b) and b.has_method("boss_durumu_sifirla"):
			var oldu = b.get("oldu_mu")
			var durum = b.get("suanki_durum")
			if not oldu and durum != "UYUKLAMA":
				print("Boss sifirlaniyor: ", b.name)
				b.boss_durumu_sifirla()

	# ─ KAHİN GÖZÜ: Bir sonraki turun saldırı ikonunu göster ───
	_kahin_gozu_ikon_goster()

	# YER YOK KONTROLÜ (Boss kayalari/asitleri koyduktan sonra)
	var dagitici = null
	if has_node("../TumMasaSistemi/MasaUstuEsyalar/BlokDagiticisi"):
		dagitici = get_node("../TumMasaSistemi/MasaUstuEsyalar/BlokDagiticisi")
	else:
		dagitici = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	
	if dagitici and dagitici.has_method("yer_yok_kontrolu_yap"):
		dagitici.yer_yok_kontrolu_yap()

func _kahin_gozu_ikon_goster():
	"""Kahin Gözü perk aktifse sıradaki boss saldırı tipini UI'da ufak ikon ile gösterir."""
	if not GameManager or not GameManager.kahin_gozu_aktif: return
	var sonraki = GameManager.sonraki_boss_saldirisi
	if sonraki.is_empty(): return

	var ikon_metni = ""
	match sonraki:
		"TAS":  ikon_metni = DilYoneticisi.metin_al("sira_kaya")
		"ASIT": ikon_metni = DilYoneticisi.metin_al("sira_asit")
		"ZAR":  ikon_metni = DilYoneticisi.metin_al("sira_zar")

	# Arayüz grubuna bilgi göster (var olan bilgi_goster mekanizması)
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster(DilYoneticisi.metin_al("kahin_gozu_baslik") + ikon_metni, 5.0)
	print("👁️ Kahin Gözü gösterdi: ", ikon_metni)
