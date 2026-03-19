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

func _senaryo_uygula(id: int):
	if _aktif_senaryo == id: return
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
			if has_method("masa_sistemi_tween_kaybol"):
				call("masa_sistemi_tween_kaybol")
			
			var arayuz = get_tree().get_first_node_in_group("Arayuz")
			if arayuz and arayuz.has_method("bilgi_goster"):
				arayuz.bilgi_goster(DilYoneticisi.metin_al("kill_boss_with_weapon") if DilYoneticisi else "Silahını çek ve boss'u öldür!")
		5:
			# Puan tamam, blok bitti, boss hayatta, mermi YOK
			_bitis_tetiklendi = true
			if has_method("kapi_ac"): 
				call("kapi_ac")
			
			# Boss carry-over
			if BossManager and BossManager.has_method("carry_over_ekle"):
				# Boss tipini GameManager'dan veya mevcut boss'tan almalıyız
				BossManager.carry_over_ekle(0, boss_current_hp)
			
			# Boss kaybolma efekti (Burada varsayılan bir tween veya boss'un kendi metodunu çağırabiliriz)
			print("🏃 Boss kaçıyor (Yetersiz mermi)...")

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
