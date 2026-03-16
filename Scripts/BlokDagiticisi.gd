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

var kalan_stok: int = 0
var masadaki_aktif_bloklar: int = 0
var tur_bitti_mi: bool = false
var boss_oldu_mu: bool = false 
var sag_tarafta_mi: bool = false # Sağa alındığında blokların yönünü düzeltmek için
var dongu_basladi_mi: bool = false # GHOST BUG FIX (Yedekte duruyor)
var _yer_kontrol_timer: Timer = null


signal stok_bitti 
signal stok_guncellendi(kalan: int)
signal bolum_temizlendi 

func _ready() -> void:
	# Başlangıçta biraz bekle ki sahne yüklensin
	await get_tree().create_timer(0.1).timeout
	yeni_bolumu_baslat()
	
	if GameManager:
		if not GameManager.mermi_degisti.is_connected(_on_mermi_degisti_kontrol):
			GameManager.mermi_degisti.connect(_on_mermi_degisti_kontrol)
		if not GameManager.boss_oldu.is_connected(_on_boss_oldu_gm_sinyali):
			GameManager.boss_oldu.connect(_on_boss_oldu_gm_sinyali)

func _on_boss_oldu_gm_sinyali():
	boss_oldu_mu = true

func _on_mermi_degisti_kontrol(_yeni_sayi: int) -> void:
	# Eğer mermi değiştiyse ve boss yaşıyorsa
	if not boss_oldu_mu and not GameManager.boss_kacti:
		# Puan hedefine çoktan ulaşılmış olabilir (erken kalkış)
		# veya taşlar/stok bitmiş olabilir.
		var arayuz = get_tree().get_first_node_in_group("Arayuz")
		var skor_yeterli = false
		if arayuz:
			var skor = arayuz.toplam_puan if "toplam_puan" in arayuz else 0
			var goal = arayuz.hedef_puan if "hedef_puan" in arayuz else 1
			skor_yeterli = skor >= goal
		
		if tur_bitti_mi or skor_yeterli:
			# Eğer mermi kalmadıysa veya yetersizse Boss'un kaçması gerekir
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
	print(">>> Stok Kontrol Ediliyor - Kalan: ", kalan_stok, " Masadaki: ", masadaki_aktif_bloklar)
	if tur_bitti_mi:
		print("--- Tur Zaten Bitti, Blok Verilmeyecek ---")
		return
	if blok_sahneleri.is_empty():
		print("--- HATA: Blok Sahneleri Bos! ---")
		return

	# Tutorial'da boss ölmediği sürece sonsuz blok sağla (User Request)
	if LevelManager and LevelManager.suanki_katman == 1:
		if not boss_oldu_mu and kalan_stok <= 5:
			kalan_stok += 10
	
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
	# Eğer boss zaten öldüyse veya kaçtıysa tekrar işlem yapma
	if boss_oldu_mu or GameManager.boss_kacti:
		return

	tur_bitti_mi = true
	if _yer_kontrol_timer: _yer_kontrol_timer.stop()
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if not arayuz: return
	var skor = 0
	if "toplam_puan" in arayuz: skor = arayuz.toplam_puan
	elif "puan" in arayuz: skor = arayuz.puan
	
	# 1. BOSS HP KONTROLÜ (Tüm düşmanların HP toplamını al)
	var boss_list = get_tree().get_nodes_in_group("Dusman")
	var toplam_kalan_hp = 0
	var aktif_boss_tipi = LevelManager.suanki_katman % 3 if LevelManager else 0
	
	for boss in boss_list:
		if is_instance_valid(boss) and not boss.get("oldu_mu"):
			if "boss_hp" in boss:
				toplam_kalan_hp += boss.boss_hp
	
	# Eğer bütün düşmanlar öldüyse (HP 0 ise) direkt bitişe geç
	if toplam_kalan_hp <= 0 and boss_list.size() > 0:
		_sahne_bitis_animasyonu()
		return
		
	# Katman 1 (Eğitim) kontrolü — sınırsız oynayış ve mermi kısıtlamasız geçiş vs.
	if LevelManager and LevelManager.suanki_katman == 1:
		if skor >= arayuz.hedef_puan:
			_sahne_bitis_animasyonu()
		else:
			_oyun_kaybedildi(arayuz)
		return

	# --- KATMAN > 1 İÇİN MERMİ VE KAÇMA KONTROLÜ ---
	# Kullanıcı isteği: mermi yeterli olmasa bile sıfır olana kadar ateş edebilsin
	var mermisi_varm_mi = GameManager and (GameManager.mermi_sayisi > 0 or GameManager.shotgun_mermi_count > 0)
	
	if mermisi_varm_mi:
		# Eğer mermi varsa ve henüz mesaj verilmediyse uyar
		if arayuz and arayuz.has_method("bilgi_goster"):
			arayuz.bilgi_goster("Silahını Çek (Sağ Tık) ve Boss'u Öldür!", 3.0) 
		
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu and oyuncu.has_method("stand_up"):
			oyuncu.stand_up(true)
	else:
		# Mermi tamamen bittiyse (0 ise)
		# Hem skor yetersizse hem de mermi bittiyse yine de Boss kaçmalı (Tutsak kalmamak için)
		print("👹 Kaynaklar tükendi. Boss kaçıyor.")
		
		if arayuz and arayuz.has_method("bilgi_goster"):
			var msg = "Mermi yetersiz! Boss kaçıyor..."
			if GameManager and (GameManager.mermi_sayisi <= 0 and GameManager.shotgun_mermi_count <= 0):
				msg = "Mermin bitti! Boss kaçıyor..."
			arayuz.bilgi_goster(msg, 4.0)
		
		# Eğer skor da yetmediyse "Kaybettin" mesajı ver ama oyun devam etsin (kilitlenmesin/tutsak kalmasın)
		if skor < arayuz.hedef_puan:
			_oyun_kaybedildi(arayuz)
		
		GameManager.boss_kacti = true
		GameManager.boss_kalan_hp = toplam_kalan_hp
		GameManager.kacan_boss_tipi = aktif_boss_tipi
		
		# UI güncellensin ve eski mesajlar silinsin
		if arayuz and arayuz.has_method("kalici_bilgi_gizle"):
			arayuz.kalici_bilgi_gizle()
		
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
			# Kamera kontrolünü oyuncuya ver
			var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
			if oyuncu and oyuncu.has_node("Camera3D"):
				oyuncu.get_node("Camera3D").make_current()
			
			_sahne_bitis_animasyonu()
		)

func _sahne_bitis_animasyonu() -> void:
	set_process_input(false)
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and oyuncu.has_method("stand_up"):
		oyuncu.stand_up(true) # Direkt ve zorunlu kaldır
		
	if LevelManager:
		LevelManager.is_boss_acting = false
		LevelManager.disable_all_boss_collisions()
		
	# Mekan bariyerlerini erkenden kaldır ki oyuncu kapıya gidebilsin
	get_tree().call_group("Bariyer", "bolum_bitti")
		
	var tween = create_tween()
	tween.set_parallel(true)
		
	if is_instance_valid(masa_objesi):
		_disable_all_collisions(masa_objesi)
		tween.tween_property(masa_objesi, "position:y", -10.0, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# TÜM DÜŞMANLARI EKSTRA GÜVENLİK İÇİN TEMİZLE (Kalan yancılar olabilir)
	var boss_list = get_tree().get_nodes_in_group("Dusman")
	for b in boss_list:
		if is_instance_valid(b) and b != boss_objesi:
			b.queue_free()

	tween.chain().tween_callback(func(): 
		if is_instance_valid(boss_objesi): boss_objesi.visible = false
		if is_instance_valid(masa_objesi): masa_objesi.queue_free()
		if grid and grid.has_method("engelleri_temizle"):
			grid.engelleri_temizle()
			
		var kapi = kapi_sistemi
		if not is_instance_valid(kapi):
			kapi = get_tree().current_scene.find_child("KapiSistemi", true, false)
		if kapi:
			if "kilitli_mi" in kapi: kapi.kilitli_mi = false
			if kapi.has_method("kapiyi_ac"):
				kapi.kapiyi_ac()
		
		# Mekan bariyerlerini kaldır
		get_tree().call_group("Bariyer", "bolum_bitti")
		
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

func _oyun_kaybedildi(arayuz_ref) -> void:
	if arayuz_ref.has_method("puan_ekle"):
		arayuz_ref.puan_ekle(0, DilYoneticisi.metin_al("yetersiz_puan"))

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
