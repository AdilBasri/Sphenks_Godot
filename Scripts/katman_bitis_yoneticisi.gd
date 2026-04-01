extends Node

## Katman Bitiş Yöneticisi
## 5 farklı senaryoya göre bölüm bitiş mantığını yönetir.

# --- VERİLER ---
var grid_minimum_puan: int = 0
var grid_mevcut_puan: int = 0
var blok_sayisi: int = 0
var boss_hayatta: bool = true
var revolver_mermi: int = 0
var shotgun_mermi: int = 0
var boss_current_hp: int = 0

# --- DURUM TAKİBİ ---
var _bitis_tetiklendi: bool = false # Her senaryonun sadece bir kez çalışması için genel kilit
var _aktif_senaryo: int = 0

func _ready():
	_setup_initial_values()
	_connect_signals()

func _setup_initial_values():
	if GameManager:
		grid_minimum_puan = GameManager.hedef_puan
		grid_mevcut_puan = GameManager.suanki_puan
		revolver_mermi = GameManager.mermi_sayisi
		shotgun_mermi = GameManager.shotgun_mermi_count
		boss_current_hp = _get_active_boss_hp()
		boss_hayatta = boss_current_hp > 0
		
	var dagitici = _find_dagitici()
	if dagitici:
		blok_sayisi = dagitici.kalan_stok + dagitici.masadaki_aktif_bloklar

func _connect_signals():
	if GameManager:
		GameManager.mermi_degisti.connect(_on_revolver_mermi_degisti)
		GameManager.shotgun_mermi_degisti.connect(_on_shotgun_mermi_degisti)
		GameManager.puan_degisti.connect(_on_puan_degisti)
		GameManager.boss_hp_degisti.connect(_on_boss_hp_degisti)
		GameManager.boss_oldu.connect(_on_boss_oldu_sinyali)
		
	var dagitici = _find_dagitici()
	if dagitici:
		dagitici.blok_sayisi_degisti.connect(_on_blok_sayisi_degisti)

func _find_dagitici():
	return get_tree().current_scene.find_child("BlokDagiticisi", true, false)

func _get_active_boss_hp() -> int:
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	var total_hp = 0
	for d in dusmanlar:
		if is_instance_valid(d) and not d.get("oldu_mu"):
			total_hp += d.get("boss_hp") if d.get("boss_hp") != null else 1
	return total_hp

func verileri_guncelle(puan: int, bloklar: int, b_hayatta: bool, b_hp: int):
	grid_mevcut_puan = puan
	blok_sayisi = bloklar
	boss_hayatta = b_hayatta
	boss_current_hp = b_hp
	
	_kontrol_et()

func _on_revolver_mermi_degisti(count: int):
	revolver_mermi = count
	_kontrol_et()

func _on_shotgun_mermi_degisti(count: int):
	shotgun_mermi = count
	_kontrol_et()

func _on_puan_degisti(puan: int):
	grid_mevcut_puan = puan
	_kontrol_et()

func _on_blok_sayisi_degisti(toplam: int):
	blok_sayisi = toplam
	_kontrol_et()

func _on_boss_hp_degisti(_tip, hp: int):
	boss_current_hp = _get_active_boss_hp() # Tekrar hesapla çünkü birden fazla boss olabilir
	boss_hayatta = boss_current_hp > 0
	_kontrol_et()

func _on_boss_oldu_sinyali():
	boss_hayatta = false
	boss_current_hp = 0
	_kontrol_et()

func _kontrol_et():
	if _bitis_tetiklendi: return
	
	# TUTORIAL: Katman 1'de tutorial bitmeden bitiş senaryoları çalışamaz.
	if GameManager and GameManager.suanki_seviye == 1 and not GameManager.is_tutorial_segment_completed("base"):
		return
	
	# DEBUG
	print("🔍 KONTROL: Blok=%d, Puan=%d/%d, BossHP=%d" % [blok_sayisi, grid_mevcut_puan, grid_minimum_puan, boss_current_hp])

	# SENARYO 7: 1.5x PUAN Victory (Override - Puan çok iyi, masa hemen kalkar)
	var tutorial_aktif = false
	if GameManager and GameManager.has_method("is_tutorial_segment_completed"):
		tutorial_aktif = (GameManager.suanki_seviye == 1 and not GameManager.is_tutorial_segment_completed("base"))
	
	if grid_mevcut_puan >= (grid_minimum_puan * 1.5) and not tutorial_aktif:
		print("🏆 SENARYO 7 KONDİSYONU SAĞLANDI! 1.5x Puan aşıldı.")
		_senaryo_uygula(7)
		return

	# SENARYO 6: Blok bitti, puan yetmedi (Feda veya Ölüm)
	# ÖNCELİKLİ: Kaynaklar tükendiğinde oyuncuya feda şansı verilmeli.
	if blok_sayisi == 0 and grid_mevcut_puan < grid_minimum_puan:
		print("🚨 SENARYO 6 KONDİSYONU SAĞLANDI! Bloklar bitti, puan yetersiz.")
		_senaryo_uygula(6)
		return

	# SENARYO 1: Boss öldü, grid tamamlanmadı
	if not boss_hayatta and grid_mevcut_puan < grid_minimum_puan:
		_senaryo_uygula(1)
		return

	# SENARYO 2: Grid tamam, boss hayatta, bloklar var
	if grid_mevcut_puan >= grid_minimum_puan and boss_hayatta and blok_sayisi > 0:
		_senaryo_uygula(2)
		return

	# SENARYO 3: Boss öldü VE Grid tamam
	if not boss_hayatta and grid_mevcut_puan >= grid_minimum_puan:
		_senaryo_uygula(3)
		return

	# SENARYO 4: Grid tamam, bloklar bitti, boss hayatta, mermi var
	if grid_mevcut_puan >= grid_minimum_puan and blok_sayisi == 0 and boss_hayatta and (revolver_mermi + shotgun_mermi) > 0:
		_senaryo_uygula(4)
		return

	# SENARYO 5: Grid tamam, bloklar bitti, boss hayatta, mermi yetersiz
	if grid_mevcut_puan >= grid_minimum_puan and blok_sayisi == 0 and boss_hayatta and (revolver_mermi + shotgun_mermi) < boss_current_hp:
		_senaryo_uygula(5)
		return

	# SENARYO 6: Blok bitti, puan yetmedi (Feda veya Ölüm)
	if blok_sayisi == 0 and grid_mevcut_puan < grid_minimum_puan:
		print("🚨 SENARYO 6 KONDİSYONU SAĞLANDI! Bloklar bitti, puan yetersiz.")
		_senaryo_uygula(6)
		return

func _senaryo_uygula(id: int):
	if _aktif_senaryo == id: return
	
	print("🎭 SENARYO UYGULA: %d (Eski: %d)" % [id, _aktif_senaryo])
	_aktif_senaryo = id
	
	print("🎭 KATMAN BİTİŞ: Senaryo %d tetiklendi." % id)
	
	match id:
		1:
			# Boss öldü ama puan az. Do nothing.
			pass
		2:
			# Her şey yolunda, devam (Main Game).
			# TUTORIAL: Eğer Katman 1 (Tutorial) ise ve tutorial aktifse hiçbir şey yapma, tutorial bitene kadar bekle.
			# Kapı açılma kontrolü GameManager.complete_tutorial_segment üzerinden yapılacak.
			pass
		3:
			# Boss öldü + Puan tamam
			_bitis_tetiklendi = true
			if has_method("kapi_ac"): 
				call("kapi_ac")
			# Masa devam eder (Bloklar bitince kapanır logic'i BlokDagiticisi'nda)
		4:
			# Puan tamam, blok bitti, boss hayatta, mermi VAR
			_aktif_senaryo = 4 # Tekrar etmesin ama bitis_tetiklendi değil (hala boss ölebilir)
			
			var arayuz = get_tree().get_first_node_in_group("Arayuz")
			if arayuz and arayuz.has_method("bilgi_goster"):
				arayuz.bilgi_goster(DilYoneticisi.metin_al("kill_boss_with_weapon") if DilYoneticisi else "Silahını çek ve boss'u öldür!")
		5:
			# Puan tamam, blok bitti, boss hayatta, mermi YOK
			_bitis_tetiklendi = true
			if has_method("kapi_ac"): 
				call("kapi_ac")
			
			# Boss carry-over
			if GameManager and GameManager.has_method("bosslari_carry_over_yap"):
				GameManager.bosslari_carry_over_yap()
			
			# Masa sistemini kaldır
			masa_sistemi_tween_kaybol()
			
			# Boss kaybolma efekti (Burada varsayılan bir tween veya boss'un kendi metodunu çağırabiliriz)
			print("🏃 Boss kaçıyor (Yetersiz mermi)...")
		6:
			# Blok bitti, puan yetmedi
			if GameManager.cuts_in_current_layer < 2:
				_feda_etmeyi_baslat()
			else:
				_kan_kaybindan_ol()
		7:
			# 1.5x Puan Victory
			_bitis_tetiklendi = true
			
			# Boss bekleme/kaçış mantığı GameManager'daki gibi:
			var mermi_yeterli = (revolver_mermi + shotgun_mermi) > 0
			
			if boss_hayatta and mermi_yeterli:
				# Mermi varsa bekle, ama masayı kaldır
				var arayuz = get_tree().get_first_node_in_group("Arayuz")
				if arayuz and arayuz.has_method("bilgi_goster"):
					arayuz.bilgi_goster(DilYoneticisi.metin_al("kill_the_boss") if DilYoneticisi else "KILL THE BOSS", 4.0)
			else:
				# Mermi yoksa boss kaçsın
				if boss_hayatta:
					if GameManager and GameManager.has_method("bosslari_carry_over_yap"):
						GameManager.bosslari_carry_over_yap()
				
				if has_method("kapi_ac"): call("kapi_ac")
				
			masa_sistemi_tween_kaybol()
			print("🏆 1.5x Victory! Masa kaldırıldı.")

# --- YARDIMCI METODLAR (Varsayılan çağrılar) ---
func kapi_ac():
	if GameManager and GameManager.has_method("_kapiyi_ac_gercek"):
		GameManager._kapiyi_ac_gercek()

func masa_sistemi_tween_kaybol():
	var dagitici = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if dagitici and dagitici.has_method("_sahne_bitis_animasyonu"):
		dagitici._sahne_bitis_animasyonu()

func masa_sistemi_durdur():
	var dagitici = get_tree().current_scene.find_child("BlokDagiticisi", true, false)
	if dagitici:
		dagitici.set_process(false)
		dagitici.set_physics_process(false)

func _feda_etmeyi_baslat():
	print("🖐️ FEDA: Parmak feda etme sekansı başlıyor.")
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	
	if not oyuncu:
		print("❌ HATA: Oyuncu bulunamadı! 'Oyuncu' grubunda node var mı kontrol et.")
		return
		
	if not oyuncu.has_method("sacrificial_interact"):
		print("❌ HATA: Oyuncu scriptinde 'sacrificial_interact' metodu yok!")
		return
		
	print("✅ Oyuncu bulundu, feda sekansı tetikleniyor.")
	# Senaryoyu sıfırla ki bir sonraki blok bitince (ödül gelince) tekrar kontrol edilsin
	_aktif_senaryo = 0 
	oyuncu.sacrificial_interact(_feda_odulu_ver)

func _feda_odulu_ver():
	var dagitici = _find_dagitici()
	if dagitici and dagitici.has_method("spawn_void_cubuk"):
		dagitici.spawn_void_cubuk()
		# Oyuncu tekrar otursun
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu and oyuncu.has_method("sit_on_stool"):
			# En yakındaki tabureyi bulup oturtabiliriz veya son tabureyi
			# Şimdilik serbest bırakıyoruz, oyuncu etkileşime girip oturabilir.
			# Aslında otomatik oturması daha akıcı olur.
			var stool = get_tree().get_first_node_in_group("Stool") # Varsa
			if stool: oyuncu.sit_on_stool(stool)

func _kan_kaybindan_ol():
	print("🩸 ÖLÜM: Kan kaybından oyuncu ölüyor.")
	_bitis_tetiklendi = true
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and oyuncu.has_method("hasar_al"):
		# Kalıcı olarak öldür (Çok yüksek hasar)
		oyuncu.hasar_al(100)
