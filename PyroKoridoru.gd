extends Node3D

@onready var oyuncu = $Oyuncu
@onready var silah_sistemi = find_child("SilahKatmani", true, false)

# --- YENİ EKLENENLER: SPAWN SİSTEMİ ---
@export var dusman_sahnesi: PackedScene # Inspector'dan PyroDusman.tscn'yi buraya atacağız
@onready var spawn_noktalari_node = $SpawnNoktalari

var olum_ekrani_sahnesi = preload("res://oyun_sonu.tscn")

func _ready():
	print("🔥 Pyro Koridoru Başlatılıyor...")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if oyuncu:
		oyuncu.global_position.y = 1.0 
		if not oyuncu.oyuncu_oldu.is_connected(_on_oyuncu_oldu):
			oyuncu.oyuncu_oldu.connect(_on_oyuncu_oldu)
	
	# GameManager Ayarları
	GameManager.pyro_aktif = true
	GameManager.silah_cekildi = true 
	
	# Silahı Hazırla
	if silah_sistemi:
		silah_sistemi.visible = true 
		if "silah_gorsel" in silah_sistemi and silah_sistemi.silah_gorsel:
			if "orjinal_pos" in silah_sistemi and silah_sistemi.orjinal_pos != Vector2.ZERO:
				silah_sistemi.silah_gorsel.position = silah_sistemi.orjinal_pos

	# --- DİL ÇEVİRİLERİ VE MİDE UI ---
	_arayuzu_hazirla()
	
	# --- DÜŞMANLARI YARAT ---
	# 1 saniye bekle sonra yaratmaya başla
	await get_tree().create_timer(1.0).timeout
	dusmanlari_baslat()

func _on_oyuncu_oldu():
	print("💀 Pyro Koridoru: Oyuncu öldü.")
	await get_tree().create_timer(2.0).timeout
	if olum_ekrani_sahnesi:
		var ekran = olum_ekrani_sahnesi.instantiate()
		add_child(ekran)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func dusmanlari_baslat():
	if not dusman_sahnesi:
		print("UYARI: Düşman sahnesi atanmamış! Inspector'dan PyroDusman.tscn'yi ata.")
		return
		
	# Kaç düşman çıkacak? (LevelManager'dan veya kafadan ver)
	var dusman_sayisi = 3 
	
	for i in range(dusman_sayisi):
		spawn_et()
		# Her düşman arasında biraz bekle
		await get_tree().create_timer(2.0).timeout

func _arayuzu_hazirla():
	# Çeviriler
	var is_en = DilYoneticisi.secili_dil == "en"
	
	var katman = find_child("KatmanLabel", true, false)
	if katman: katman.text = ("LAYER " if is_en else "KATMAN ") + str(GameManager.suanki_seviye)
	
	var mermi = find_child("MermiLabel", true, false)
	if mermi: mermi.text = "AMMO:" if is_en else "MERMİ:"
		
	var hasar = find_child("HasarYazisi", true, false)
	if hasar: hasar.text = "DAMAGE: 0" if is_en else "HASAR: 0"
	
	# Mide UI Görünürlüğü (Bazen kapalı başlıyor)
	var mide = find_child("MideKatmani", true, false)
	if mide: mide.visible = true
	var mide_ui = find_child("MideUI", true, false)
	if mide_ui: 
		mide_ui.visible = true
		if mide_ui.has_method("guncelle"):
			mide_ui.guncelle(GameManager.oyuncu_mide_doluluk, GameManager.oyuncu_mide_kapasite)

func spawn_et():
	# 1. Düşmanı Hafızadan Oluştur
	var yeni_dusman = dusman_sahnesi.instantiate()
	
	# --- HATA ÇÖZÜMÜ BURADA ---
	# Önce sahneye ekliyoruz ki "Dünya"nın bir parçası olsun.
	# Böylece global_position (Dünya konumu) hesaplanabilir hale gelir.
	add_child(yeni_dusman) 
	
	# 2. Rastgele Bir Konum Seç ve Yerleştir
	var noktalar = spawn_noktalari_node.get_children()
	if noktalar.size() > 0:
		var secilen_nokta = noktalar.pick_random()
		yeni_dusman.global_position = secilen_nokta.global_position
	else:
		# Nokta yoksa koridorun ucuna koy
		yeni_dusman.global_position = Vector3(0, 1, -10)
	
	print("🧟 Düşman doğdu!")

func _exit_tree():
	GameManager.pyro_aktif = false
	GameManager.silah_cekildi = false
