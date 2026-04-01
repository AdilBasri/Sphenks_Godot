extends Node3D

# --- AYARLAR ---
@export var grid: GridYonetici
@export var spawn_noktalari: Array[Marker3D] 
@export var blok_sahneleri: Array[PackedScene] 
@export var block_cubuk_sahnesi: PackedScene # Sacrifice ödülü

# --- SAHNE OBJELERİ ---
@export var boss_objesi: Node3D 
@export var masa_objesi: Node3D 
@export var kapi_sistemi: Node3D 

# --- BÖLÜM AYARLARI ---
var bolum_blok_limiti: int = 12 
var elde_tutulan_max: int = 3    
var baslangic_kotasi: int = 300 

var kalan_stok: int = 0
var masadaki_aktif_bloklar: int = 0
var tur_bitti_mi: bool = false
var boss_oldu_mu: bool = false 
var sag_tarafta_mi: bool = false # Sağa alındığında blokların yönünü düzeltmek için
var dongu_basladi_mi: bool = false # GHOST BUG FIX (Yedekte duruyor)
var _yer_kontrol_timer: Timer = null
var puzzle_tamamlandi: bool = false # Skora ulaşıldı veya kaynaklar bitti ama masa henüz durabilir

signal stok_bitti 
signal stok_guncellendi(kalan: int)
signal blok_sayisi_degisti(toplam: int)
signal bolum_temizlendi 

func _ready() -> void:
	# Başlangıçta biraz bekle ki sahne yüklensin
	await get_tree().create_timer(0.1).timeout
	puzzle_tamamlandi = false
	yeni_bolumu_baslat()
	
	if GameManager:
		if not GameManager.mermi_degisti.is_connected(_on_mermi_degisti_kontrol):
			GameManager.mermi_degisti.connect(_on_mermi_degisti_kontrol)
		
	# NOT: _sahne_bitis_animasyonu artik sadece 1.5x puanda veya kaynak bitince 
	# KatmanBitisYoneticisi/oyun_odasi tarafindan cagrilacak.
	# Buradaki baglantiyi kaldiriyoruz ki 100% puanda masa gitmesin.
	# if not GameManager.seviye_tamamlandi.is_connected(_sahne_bitis_animasyonu):
	# 	GameManager.seviye_tamamlandi.connect(_sahne_bitis_animasyonu)

func _on_mermi_degisti_kontrol(yeni_sayi: int) -> void:
	# Eğer mermi 0 olduysa 1.2 saniye bekle (merminin hedefe ulaşması için)
	# AMA: Eğer boss zaten öldüyse beklemeye gerek yok
	var yasayan_var_mi = false
	var bosslar = get_tree().get_nodes_in_group("Dusman")
	for b in bosslar:
		if is_instance_valid(b) and not b.get("oldu_mu"):
			yasayan_var_mi = true; break

	if yeni_sayi == 0 and yasayan_var_mi:
		await get_tree().create_timer(1.2).timeout
		
	# Eğer mermi değiştiyse ve boss yaşıyorsa
	# (Yukarıda tekrar kontrol etmeliyiz çünkü timer süresince ölmüş olabilir)
	yasayan_var_mi = false
	for b in bosslar:
		if is_instance_valid(b) and not b.get("oldu_mu"):
			yasayan_var_mi = true; break
			
	if yasayan_var_mi and not GameManager.boss_kacti:
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		var skor_yeterli = false
		if arayuz:
			var skor = arayuz.toplam_puan if "toplam_puan" in arayuz else 0
			var goal = arayuz.hedef_puan if "hedef_puan" in arayuz else 1
			skor_yeterli = skor >= goal
		
		if tur_bitti_mi or skor_yeterli:
			_tur_sonu_hesaplamasi()

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
	# 3. BOSS GÜNCELLEME (Görünürlük LevelManager tarafından yönetilir)
	var aktif_boss = boss_objesi
	if not aktif_boss:
		aktif_boss = get_tree().get_first_node_in_group("Dusman")
	
	if aktif_boss:
		# Sadece resmi güncelle, görünürlüğü LevelManager'a bırak
		if boss_yolu != "":
			var doku = load(boss_yolu)
			if doku:
				if boss_objesi is Sprite3D:
					boss_objesi.texture = doku
				elif boss_objesi is MeshInstance3D:
					var mat = boss_objesi.get_active_material(0)
					if not mat:
						# Materyal yoksa veya hata veriyorsa yeni oluştur (Godot null material check)
						var yeni_mat = StandardMaterial3D.new()
						yeni_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						boss_objesi.material_override = yeni_mat
						mat = yeni_mat
					
					mat.albedo_texture = doku
			else:
				print("HATA: Boss resmi yüklenemedi! Yol: ", boss_yolu)
	else:
		print("HATA: Boss Objesi atanmamış!")

	# 4. Grid Temizle
	if grid: grid._gridi_yenile()
	
	# SPAWN NOKTALARINI GIZLE (Silindirleri kapat)
	_spawn_noktalarini_guncelle(false)

	emit_signal("stok_guncellendi", kalan_stok)
	emit_signal("blok_sayisi_degisti", kalan_stok + masadaki_aktif_bloklar)
	# OTO SPAWN İPTAL (Kullanıcı İsteği)
	# await get_tree().create_timer(1.0).timeout
	# _stoktan_yeni_parti_ver()

func baslat_spawn_dongusu() -> void:
	print("!!! BLOK DAGITICISI TETIKLENDI !!!")
	# Oyun başladığında (Tabureye oturunca) çağrılacak
	_spawn_noktalarini_guncelle(true)
	
	# Periyodik yer kontrolü timer'ını başlat
	if _yer_kontrol_timer == null:
		_yer_kontrol_timer = Timer.new()
		_yer_kontrol_timer.wait_time = 2.0
		_yer_kontrol_timer.one_shot = false
		add_child(_yer_kontrol_timer)
		_yer_kontrol_timer.timeout.connect(_on_yer_kontrol_timer)
	_yer_kontrol_timer.start()
	
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()

func _on_yer_kontrol_timer():
	# Her 2 saniyede bir blokların yerleşip yerleşemeyeceğini kontrol et
	if tur_bitti_mi:
		if _yer_kontrol_timer: _yer_kontrol_timer.stop()
		return
	# Boss aksiyondayken kontrol etme (boss daha taş koyuyor olabilir)
	if LevelManager and LevelManager.is_boss_acting:
		return
	# YER KONTROLÜ (Ağır bir işlem olduğu için asenkron veya basit hale getirdik)
	call_deferred("yer_yok_kontrolu_yap")

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
	# Bütün katmanlarda sonsuz blok sağla (User Request)
	kalan_stok = 999
	emit_signal("stok_guncellendi", kalan_stok)
	
	print(">>> Stok Kontrol Ediliyor - Kalan: ", kalan_stok, " Masadaki: ", masadaki_aktif_bloklar)
	if tur_bitti_mi:
		print("--- Tur Zaten Bitti, Blok Verilmeyecek ---")
		return
	if blok_sahneleri.is_empty():
		print("--- HATA: Blok Sahneleri Bos! ---")
		return
	
	if kalan_stok <= 0 and masadaki_aktif_bloklar <= 0:
		emit_signal("stok_bitti")
		_tur_sonu_hesaplamasi()
		return

	var eksik_sayisi = elde_tutulan_max - masadaki_aktif_bloklar
	var dagitilacak_adet = min(eksik_sayisi, kalan_stok)
	
	if dagitilacak_adet > 0:
		spawn_bloklar(dagitilacak_adet)
	else:
		# Eğer yeni blok dağıtılmıyorsa (stok bitti ama masada kalan varsa)
		# Kalan o blokların herhangi bir yere sığıp sığmadığını kontrol et
		await get_tree().create_timer(0.2).timeout
		yer_yok_kontrolu_yap()

func _on_blok_yerlesti() -> void:
	masadaki_aktif_bloklar -= 1
	emit_signal("blok_sayisi_degisti", kalan_stok + masadaki_aktif_bloklar)
	# Boss artık satır patlatarak ölmüyor — sadece silahla öldürülebilir
	# _anlik_boss_kontrolu() KALDIRILDI
	await get_tree().create_timer(0.5).timeout
	_stoktan_yeni_parti_ver()

# Boss artık sadece silahla öldürülebilir — bu fonksiyon devre dışı
#func _anlik_boss_kontrolu() -> void:
#	pass

# Boss artık sadece silahla öldürülebilir — bu fonksiyon devre dışı
#func _boss_olum_animasyonu() -> void:
#	pass

func _tur_sonu_hesaplamasi() -> void:
	# Aktif düşman kontrolü
	var boss_list = get_tree().get_nodes_in_group("Dusman")
	var yasayan_boss_list = []
	var toplam_kalan_hp = 0
	
	for boss in boss_list:
		if is_instance_valid(boss) and not boss.get("oldu_mu"):
			yasayan_boss_list.append(boss)
			if "boss_hp" in boss:
				toplam_kalan_hp += boss.boss_hp

	# Eğer boss zaten öldüyse veya kaçtıysa ve masada blok kalmadıysa tekrar işlem yapma
	if (yasayan_boss_list.is_empty() or GameManager.boss_kacti) and (kalan_stok <= 0 and masadaki_aktif_bloklar <= 0):
		return

	if _yer_kontrol_timer: _yer_kontrol_timer.stop()
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if not arayuz: return
	var skor = 0
	if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
	elif "puan" in arayuz: skor = arayuz.puan
	
	# --- BURADAN SONRASI KatmanBitisYoneticisi TARAFINDAN YÖNETİLECEK ---
	# Sadece kritik GAME OVER durumlarını burada tutuyoruz (Skor yetmezse ve kaynak yoksa)
	
	if (kalan_stok <= 0 and masadaki_aktif_bloklar <= 0):
		# YENİ MANTIK: Mermi/Skor kontrolü KatmanBitisYoneticisi veya GameManager tarafından yapılacak.
		# Eğer durum vahimse (puan az, mermi yok, blok bitti) GameManager bitiş tetiklemezse
		# burada manuel tetikleyebiliriz veya KatmanBitisYoneticisi'ni bekleyebiliriz.
		print("📦 Kaynaklar tükendi, bitiş yöneticisi kontrol ediyor...")

	# KatmanBitisYoneticisi'ne haber ver (Genel kontrol için)
	# Not: Zaten sinyallerle bağlı, ekstra çağrıya gerek yok ama 
	# verileri_guncelle manuel olarak çağırmak sistemi tetikler.
	var manager = LevelManager.bitis_yoneticisi if LevelManager else null
	if manager and manager.has_method("verileri_guncelle"):
		manager.verileri_guncelle(skor, kalan_stok + masadaki_aktif_bloklar, toplam_kalan_hp > 0, toplam_kalan_hp)

func _oyun_kaybedildi(arayuz_ref) -> void:
	print("💀 OYUN BİTTİ: Kaynaklar tükendi ve hedef skor ulaşılamadı.")
	if arayuz_ref and arayuz_ref.has_method("bilgi_goster"):
		arayuz_ref.bilgi_goster(DilYoneticisi.metin_al("oyun_bitti") if DilYoneticisi else "OYUN BİTTİ", 5.0)
	
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and oyuncu.has_method("game_over"):
		oyuncu.game_over()
		
		# --- TÜM DÜŞMANLARI KAÇANLAR LİSTESİNE EKLE ---
		var boss_list = get_tree().get_nodes_in_group("Dusman")
		if GameManager:
			GameManager.kacan_bosslar.clear() # Önce temizle
			for boss in boss_list:
				if is_instance_valid(boss) and not boss.get("oldu_mu"):
					var tip = 0 # Default Normal
					if "acid" in boss.name.to_lower(): tip = 1
					elif "stone" in boss.name.to_lower(): tip = 2
					
					var hp = boss.boss_hp if "boss_hp" in boss else 1
					GameManager.boss_kacti_ekle(tip, hp)
		
		# UI güncellensin ve eski mesajlar silinsin
		if arayuz_ref and arayuz_ref.has_method("kalici_bilgi_gizle"):
			arayuz_ref.kalici_bilgi_gizle()
		
		# Garanti collision temizliği (Kaçış başlamadan önce)
		if LevelManager: LevelManager.disable_all_boss_collisions()
		
		# TÜM DÜŞMANLARI (ANA VE YANCI) TEMİZLE
		for boss in boss_list:
			if is_instance_valid(boss):
				boss.set_process(false)
				if "oldu_mu" in boss: boss.oldu_mu = true
				
				var tween = create_tween()
				tween.tween_property(boss, "position:y", boss.position.y - 10.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tween.parallel().tween_property(boss, "scale", Vector3(0.01, 0.01, 0.01), 2.0)
				tween.tween_callback(boss.queue_free)
		
		# Kaçış animasyonu bitince oyunu bitir
		get_tree().create_timer(1.5).timeout.connect(func():
			# Kamera kontrolünü oyuncuya ver (Dışarıdaki `oyuncu` kullanılıyor)
			if oyuncu and oyuncu.has_node("Camera3D"):
				oyuncu.get_node("Camera3D").make_current()
			
			_sahne_bitis_animasyonu()
		)

func _sahne_bitis_animasyonu() -> void:
	set_process_input(false)
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and oyuncu.has_method("stand_up"):
		oyuncu.stand_up(true) # Direkt ve zorunlu kaldır
		await get_tree().process_frame # Teleportasyonun tamamlanması için bekle
		
	if LevelManager:
		LevelManager.is_boss_acting = false
		# Sadece boss gerçekten öldüyse veya kaçtıysa kolizyonları temizle
		# Eğer boss hayattaysa, oyuncu onu vurabilmeli.
		LevelManager.disable_all_boss_collisions()
		
	# Mekan bariyerlerini erkenden kaldır ki oyuncu kapıya gidebilsin
	get_tree().call_group("Bariyer", "bolum_bitti")
		
	# 1. MERMİ VE DÜŞMAN DURUMU KONTROLÜ
	var toplam_mermi = 0
	if GameManager:
		toplam_mermi = GameManager.mermi_sayisi + GameManager.shotgun_mermi_count
		
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	var boss_yasiyor = false
	var toplam_boss_hp = 0
	var aktif_dusman = boss_objesi
	
	for d in dusmanlar:
		if is_instance_valid(d) and not d.get("oldu_mu"):
			boss_yasiyor = true
			toplam_boss_hp += d.boss_hp if "boss_hp" in d else 1
			if not aktif_dusman: aktif_dusman = d
	
	var mermi_yeterli = (toplam_mermi > 0) # Oyuncunun elinde mermi varsa savaş devam etmeli
	
	# OYUNCUYU TABUREDEN KALDIR (KRİTİK)
	if oyuncu and oyuncu.has_method("stand_up"):
		oyuncu.stand_up()
	
	if mermi_yeterli and boss_yasiyor:
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		if arayuz and arayuz.has_method("bilgi_goster"):
			# DilYoneticisi'nden "kill_the_boss" çek
			var msg = DilYoneticisi.metin_al("kill_the_boss") if DilYoneticisi else "KILL THE BOSS"
			arayuz.bilgi_goster(msg, 5.0)
	else:
		# Mermi yoksa boss zaten GameManager tarafından carry-over yapıldı
		var kapi = kapi_sistemi
		if not is_instance_valid(kapi):
			kapi = get_tree().current_scene.find_child("KapiSistemi", true, false)
		if kapi:
			if "kilitli_mi" in kapi: kapi.kilitli_mi = false
			if kapi.has_method("kapiyi_ac"):
				kapi.kapiyi_ac()

	var tween = create_tween()
	tween.set_parallel(true)
		
	if is_instance_valid(masa_objesi):
		_disable_all_collisions(masa_objesi)
		tween.tween_property(masa_objesi, "position:y", -10.0, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# DÜŞMAN TEMİZLİĞİ: Sadece boss mermi yetersizliğiyle kaçıyorsa veya öldüyse minions'ları temizle
	if not (mermi_yeterli and boss_yasiyor):
		var boss_list = get_tree().get_nodes_in_group("Dusman")
		for b in boss_list:
			if is_instance_valid(b) and b != aktif_dusman:
				b.queue_free()

	tween.chain().tween_callback(func(): 
		var check_dusmanlar = get_tree().get_nodes_in_group("Dusman")
		var is_any_alive = false
		for cd in check_dusmanlar:
			if is_instance_valid(cd) and not cd.get("oldu_mu"):
				is_any_alive = true; break
				
		if is_any_alive: 
			if not (mermi_yeterli and boss_yasiyor):
				# Eğer savaş bittiyse (mermi yok) gizle
				for cd in check_dusmanlar:
					if is_instance_valid(cd): cd.visible = false
				print("👋 BlokDagiticisi: Bosslar kaçıyor/öldü, gizlendi.")
			else:
				print("⚔️ BlokDagiticisi: Boss Fight aktif, bosslar korunuyor.")
		if is_instance_valid(masa_objesi): masa_objesi.queue_free()
		if grid and grid.has_method("engelleri_temizle"):
			grid.engelleri_temizle()
			
		# Mekan bariyerlerini kaldır
		get_tree().call_group("Bariyer", "bolum_bitti")
		
		# GARANTİ: Mouse Modunu Tekrar Kilitle (Oyuncu yürüyebilsin)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		emit_signal("bolum_temizlendi") 
	)

func _disable_all_collisions(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.set_deferred("disabled", true)
	# if StaticBody3D or AnimatableBody3D, disable masks/layers just in case
	if node is PhysicsBody3D:
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
	for child in node.get_children():
		_disable_all_collisions(child)


func spawn_bloklar(adet: int) -> void:
	print(">>> Yaratilacak Blok Adedi: ", adet)
	for i in range(adet):
		print(">> Spawn denemesi: ", i)
		var hedef_marker = _bos_spawn_noktasi_bul()
		if hedef_marker == null: 
			print("--- HATA: Bos Spawn Noktasi Bulunamadi veya Spawn Array'i Bos! ---")
			break
		print(">> Hedef Marker Bulundu: ", hedef_marker.name)
		kalan_stok -= 1
		emit_signal("stok_guncellendi", kalan_stok)
		masadaki_aktif_bloklar += 1
		emit_signal("blok_sayisi_degisti", kalan_stok + masadaki_aktif_bloklar)
		_blok_yarat_ve_firlat(hedef_marker)
		await get_tree().create_timer(0.2).timeout

	# Her şey spawnlandıktan sonra yer var mı kontrol et
	await get_tree().create_timer(0.5).timeout
	yer_yok_kontrolu_yap()

func _bos_spawn_noktasi_bul() -> Marker3D:
	if spawn_noktalari.is_empty():
		print(">>> HATA: spawn_noktalari dizisi bombos!")
		return null
		
	for nokta in spawn_noktalari:
		if nokta == null: continue
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
	# Yeni ayar: 90 derece ofset verelim. Ya da sağdaysa -90 verelim.
	var hedef_rotasyon_y = 90
	if sag_tarafta_mi:
		hedef_rotasyon_y = -90

	var hedef_rotasyon = Vector3(0, deg_to_rad(hedef_rotasyon_y), 0) 
	
	yeni_blok.rotation_degrees = Vector3(0, 180, 0) # Başlangıç (Tween öncesi önemsiz ama animasyon için)
	
	# EVE DÖN ROTASYONUNU GÜNCELLE
	# BlokSurukle scripti _ready'de o anki açıyı (180) "orjinal" olarak kaydediyor.
	# Ama biz onu tween ile hedefe götüreceğiz. Bırakınca oraya (hedefe) dönsün.
	if yeni_blok is BlokSurukle:
		yeni_blok.orjinal_rotasyon_degrees = Vector3(0, hedef_rotasyon_y, 0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(yeni_blok, "position", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(yeni_blok, "scale", hedef_scale, 0.5)
	
	# Rotasyonu Tweenle
	tween.tween_property(yeni_blok, "rotation", hedef_rotasyon, 0.5)

# --- YER YOK KONTROLÜ ---
func yer_yok_kontrolu_yap() -> void:
	if tur_bitti_mi: return
	if not grid: return
	
	# Sahnedeki tüm sürüklenebilir blokları topla
	var tum_bloklar = get_tree().get_nodes_in_group("Blok")
	var suruklenebilir_bloklar: Array = []
	for child in tum_bloklar:
		if child is BlokSurukle and is_instance_valid(child) and not child.is_queued_for_deletion():
			# Phantom (hayalet/gizli) blokları engellemek için sadece spawn noktasındakileri veya eldekini al
			if child.get("tutuluyor") == true:
				suruklenebilir_bloklar.append(child)
			elif child.get_parent() is Marker3D and child.get_parent() in spawn_noktalari:
				suruklenebilir_bloklar.append(child)
	
	# Eğer masada/elde hiç sürüklenebilir blok yoksa VE stok da bittiyse,
	# oyun zaten _tur_sonu_hesaplamasi ile bitecek. Burada kontrol etmemize gerek yok.
	if suruklenebilir_bloklar.size() <= 0:
		if kalan_stok <= 0:
			if not tur_bitti_mi:
				_tur_sonu_hesaplamasi()
		return
	
	var en_az_yere_koyulabilen_var_mi = false
	
	for child in suruklenebilir_bloklar:
		var orj_fp = child.footprint
		for rot in range(4):
			# Eğer 2 saniyede bir tam gridi iteratif tarıyorsak bu zayıf PC'lerde
			# 1-saniyelik takılmalara (CPU spike) neden olur.
			# Şimdilik sadece her 2 adımdaki bir hücreye bakarak optimizasyon sağlıyoruz.
			var test_fp = child._footprint_dondur(orj_fp, rot)
			
			var adim_x = 1 if grid.grid_boyutu.x < 10 else 2
			var adim_y = 1 if grid.grid_boyutu.y < 10 else 2
			
			for x in range(0, grid.grid_boyutu.x, adim_x):
				for y in range(0, grid.grid_boyutu.y, adim_y):
					if grid.can_place(Vector2i(x, y), test_fp):
						en_az_yere_koyulabilen_var_mi = true
						break
				if en_az_yere_koyulabilen_var_mi: break
			if en_az_yere_koyulabilen_var_mi: break
		if en_az_yere_koyulabilen_var_mi: break
		
	if not en_az_yere_koyulabilen_var_mi:
		print(">>> GRID DOLDU! HICBIR BLOK KOYULAMIYOR! OYUN BİTTİ! <<<")
		
		# Timer'ı durdur
		if _yer_kontrol_timer: _yer_kontrol_timer.stop()
		
		# Boss eğer saldırma modundaysa anında kes
		if LevelManager: LevelManager.is_boss_acting = false
		
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu:
			# Oyuncunun elindeki bloklar dahil tüm aktif serbest blokları sil
			get_tree().call_group("Blok", "queue_free")
		
		# Bütün oyun sonu kuralları (mermi, boss kaçması vb.) _tur_sonu_hesaplamasi içinden yönetilir!
		_tur_sonu_hesaplamasi()
	else:
		print(">>> Yer var, oyun devam ediyor.")

func spawn_void_cubuk():
	"""Void'den (görünmez bir noktadan) çubuk blok getirir."""
	if not block_cubuk_sahnesi:
		# Fallback: Eğer export edilmemişse manuel yükle
		block_cubuk_sahnesi = load("res://Scenes/Blocks/block_cubuk.tscn")
	
	if not block_cubuk_sahnesi:
		print("⚠️ block_cubuk.tscn bulunamadı!")
		return
	
	var blok = block_cubuk_sahnesi.instantiate()
	get_tree().current_scene.add_child(blok)
	
	# Başlangıç pozisyonu (Void): Masanın arkasında bir yer
	var void_pos = global_position + Vector3(0, 10, -5)
	blok.global_position = void_pos
	
	# Hedef pozisyon: Masadaki bir spawn noktası (boş olanı seç)
	var hedef_nokta = global_position # Fallback
	if spawn_noktalari.size() > 0:
		hedef_nokta = spawn_noktalari[0].global_position
		for sn in spawn_noktalari:
			if sn.get_child_count() == 0:
				hedef_nokta = sn.global_position
				break
			
	# Animasyonla uçarak gelir
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(blok, "global_position", hedef_nokta, 1.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(blok, "rotation_degrees", Vector3(0, 360, 0), 1.2)
	
	# Blok ayarlarını yap (Blok script'i varsa)
	# BlokDagiticisi.gd içinde _blok_yarat_ve_firlat benzeri mantık:
	if blok.has_method("firlat_hazirla"):
		blok.firlat_hazirla(self)
	
	masadaki_aktif_bloklar += 1
	emit_signal("stok_guncellendi", kalan_stok)
	print("🌌 Void'den çubuk blok geldi!")
