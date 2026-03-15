extends CanvasLayer

# --- BAĞLANTILAR (OyunArayuzu) ---
@onready var panel = get_node_or_null("ParsomenPanel")
@onready var quota_label = get_node_or_null("ParsomenPanel/PuanTablosu/QuotaDeger")
@onready var score_label = get_node_or_null("ParsomenPanel/PuanTablosu/TotalScoreDeger")
@onready var liste = get_node_or_null("ParsomenPanel/PuanTablosu/Liste")
@onready var altin_label = get_node_or_null("AnaKontrol/MarginContainer/HBoxContainer/AltinSayisi")
@onready var bilgi_label = get_node_or_null("AnaKontrol/BilgiLabel")
@onready var katman_label = get_node_or_null("KatmanLabel")
@onready var mermi_hud: Control = find_child("MermiKonteyner", true, false)
@onready var nisangah: Control = find_child("Nisangah", true, false)
@onready var pyro_filtresi: ColorRect = find_child("PyroFiltresi", true, false)

# --- BAĞLANTILAR (Silah) ---
@export var silah_gorsel: TextureRect
@export var namlu_ucu: Marker2D
@export var mermi_sahnesi: PackedScene 
@export var animasyon_kareleri: Array[Texture2D] 

# --- DEĞİŞKENLER ---
var orjinal_pos: Vector2
var islem_mesgul: bool = false 
var panel_acik: bool = false
var toplam_puan: int = 0
var hedef_puan: int = 300
var flash_rect: ColorRect = null
var oyuncu_ref: Node = null
var _3d_gun: Node = null
var _3d_shotgun: Node = null
var active_weapon_index: int = 1 # 1: Gun, 2: Shotgun
var perde: ColorRect = null
var bilgi_tween: Tween 

# --- SES ---
var sfx_inspect: AudioStreamPlayer
var sfx_blank: AudioStreamPlayer
var sfx_fire: AudioStreamPlayer

func _ready():
	add_to_group("Arayuz")
	visible = true # CanvasLayer her zaman açık kalmalı
	
	# Silah parçalarını başlangıçta gizle
	if mermi_hud: mermi_hud.visible = false
	if nisangah: nisangah.visible = false
	if panel: panel.visible = false
	GameManager.silah_cekildi = false 
	
	# GameManager Bağlantıları
	if GameManager:
		if not GameManager.mermi_degisti.is_connected(_on_mermi_degisti):
			GameManager.mermi_degisti.connect(_on_mermi_degisti)
		if not GameManager.altin_guncellendi.is_connected(_on_altin_guncellendi):
			GameManager.altin_guncellendi.connect(_on_altin_guncellendi)
		if not GameManager.envanter_guncellendi.is_connected(totem_sayacini_guncelle):
			GameManager.envanter_guncellendi.connect(totem_sayacini_guncelle)
			
		_on_mermi_degisti(GameManager.mermi_sayisi)
		_on_altin_guncellendi(GameManager.toplam_altin)
		totem_sayacini_guncelle()

	# Sesler
	sfx_inspect = AudioStreamPlayer.new()
	sfx_inspect.stream = load("res://Assets/Audio/gun_inspect.mp3")
	add_child(sfx_inspect)
	
	sfx_blank = AudioStreamPlayer.new()
	sfx_blank.stream = load("res://Assets/Audio/gun_blank.mp3")
	add_child(sfx_blank)
	
	sfx_fire = AudioStreamPlayer.new()
	sfx_fire.stream = load("res://Assets/Audio/gun_fire.mp3")
	add_child(sfx_fire)
	
	if silah_gorsel:
		orjinal_pos = silah_gorsel.position
		silah_gorsel.texture = animasyon_kareleri[7] if animasyon_kareleri.size() > 7 else null
	
	# Muzzle flash
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.95, 0.5, 0.85)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.visible = false
	add_child(flash_rect)

	# Perde
	perde = get_node_or_null("Perde")
	if perde:
		perde.color.a = 1.0
		perde_ac()
	
	# Katman yazısını başlangıçta gizle
	if katman_label: katman_label.visible = false
	
	# Oyuncu/3D Silah
	oyuncu_ref = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu_ref:
		_3d_gun = oyuncu_ref.get_node_or_null("Camera3D/Sketchfab_Scene")
		_3d_shotgun = oyuncu_ref.get_node_or_null("Camera3D/Sketchfab_Scene2")

func _process(_delta):
	# Nişangah ve Filtre kontrolü
	# Mermi HUD her zaman görünür olmalı (Silah çekili olsun olmasın)
	if mermi_hud and not mermi_hud.visible:
		mermi_hud.visible = true
	
	# Nişangah artık sadece silahın çekili olup olmamasına ve yeme durumuna bakıyor
	var nisangah_aktif = GameManager.silah_cekildi and not GameManager.yeme_aktif_mi
	if nisangah and nisangah.visible != nisangah_aktif:
		nisangah.visible = nisangah_aktif
	
	if pyro_filtresi:
		var filtre_gorunur = GameManager.pyro_aktif and not GameManager.yeme_aktif_mi
		if pyro_filtresi.visible != filtre_gorunur:
			pyro_filtresi.visible = filtre_gorunur
	
	# --- MASAYA OTURMA & MARKET KONTROLÜ ---
	# Eğer masaya oturulmuşsa veya Marketteysek (kese elindeyse) silahı zorla kapat.
	var market = get_tree().get_first_node_in_group("Market") # Market script'i Dusman yerine Market grubunda olabilir veya name ile bulunur
	if not market: market = get_tree().current_scene.find_child("Market", true, false)
	
	var markette_mi = market and market.get("iceride_mi") == true
	var oturuyor_mu = oyuncu_ref and oyuncu_ref.get("is_sitting") == true
	
	if oturuyor_mu or markette_mi:
		if GameManager.silah_cekildi:
			_silah_durumunu_degistir()

func _input(event):
	if event.is_action_pressed("panel_ac"):
		toggle_panel()

	if not GameManager.pyro_aktif and not _3d_gun: return
	if oyuncu_ref and oyuncu_ref.get("oldu_mu") == true: return
	
	if event.is_action_pressed("sag_tik"):
		var market = get_tree().current_scene.find_child("Market", true, false)
		var markette_mi = market and market.get("iceride_mi") == true
		if (oyuncu_ref and oyuncu_ref.get("is_sitting") == true) or markette_mi:
			return
		_silah_durumunu_degistir()
	
	if GameManager.silah_cekildi and event.is_action_pressed("ates_et") and not islem_mesgul:
		if _3d_gun and is_instance_valid(_3d_gun):
			pass
		else:
			if GameManager.mermiyi_kullan():
				_animasyon_oynat_ates()
			else:
				_mermi_yok_uyarisi()

	if GameManager.silah_cekildi and event.is_action_pressed("incele") and not islem_mesgul:
		sfx_inspect.play()
		_animasyon_oynat_incele()

	# --- WEAPON SWITCHING (1 & 2 KEYS) ---
	if event is InputEventKey and event.pressed:
		var market = get_tree().current_scene.find_child("Market", true, false)
		var markette_mi = market and market.get("iceride_mi") == true
		if (oyuncu_ref and oyuncu_ref.get("is_sitting") == true) or markette_mi: return
		
		if event.keycode == KEY_1 and active_weapon_index != 1:
			_switch_weapon(1)
		elif event.keycode == KEY_2 and active_weapon_index != 2:
			_switch_weapon(2)

func _switch_weapon(index: int):
	var old_weapon = _3d_gun if active_weapon_index == 1 else _3d_shotgun
	var new_weapon = _3d_gun if index == 1 else _3d_shotgun
	
	active_weapon_index = index
	print("Weapon Selection Switched to: ", "Gun" if index == 1 else "Shotgun")

	if GameManager.silah_cekildi:
		islem_mesgul = true
		if is_instance_valid(old_weapon) and old_weapon.has_method("hide_weapon"):
			old_weapon.hide_weapon()
		
		# Animasyon bitene kadar bekle (hide_weapon süresi yaklaşık 0.25s)
		await get_tree().create_timer(0.25).timeout
		
		# Switching sırasında kullanıcı tekrar basmış olabilir, en güncel seçimi al
		new_weapon = _3d_gun if active_weapon_index == 1 else _3d_shotgun
		
		if is_instance_valid(new_weapon) and new_weapon.has_method("show_weapon"):
			new_weapon.show_weapon()
		
		await get_tree().create_timer(0.35).timeout
		islem_mesgul = false

func toggle_panel():
	panel_acik = !panel_acik
	if panel: panel.visible = panel_acik

func _silah_durumunu_degistir():
	if islem_mesgul: return
	GameManager.silah_cekildi = !GameManager.silah_cekildi
	
	if mermi_hud: mermi_hud.visible = GameManager.silah_cekildi
	
	var current_weapon = _3d_gun if active_weapon_index == 1 else _3d_shotgun

	if GameManager.silah_cekildi:
		if current_weapon and is_instance_valid(current_weapon):
			if current_weapon.has_method("show_weapon"): current_weapon.show_weapon()
		elif silah_gorsel:
			silah_gorsel.visible = true
			silah_gorsel.position.y = get_viewport().size.y + 200
			create_tween().tween_property(silah_gorsel, "position", orjinal_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if current_weapon and is_instance_valid(current_weapon):
			if current_weapon.has_method("hide_weapon"): current_weapon.hide_weapon()
		elif silah_gorsel:
			var tw = create_tween()
			tw.tween_property(silah_gorsel, "position:y", get_viewport().size.y + 200, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): silah_gorsel.visible = false)

func _on_mermi_degisti(sayi):
	var m_label = find_child("MermiSayisi", true, false)
	if m_label:
		var parca = GameManager.mermi_parcasi_sayisi if GameManager else 0
		if parca > 0:
			m_label.text = "%d/%d (🔩%d/3)" % [sayi, GameManager.max_mermi, parca]
		else:
			m_label.text = "%d/%d" % [sayi, GameManager.max_mermi]
		m_label.modulate = Color.RED if sayi == 0 else (Color(1, 0.55, 0) if sayi <= 5 else Color.WHITE)

func _on_altin_guncellendi(miktar):
	if altin_label:
		altin_label.text = str(miktar)
		var tw = create_tween()
		tw.tween_property(altin_label, "scale", Vector2(1.2, 1.2), 0.1)
		tw.tween_property(altin_label, "scale", Vector2(1.0, 1.0), 0.1)

func totem_sayacini_guncelle():
	var sayac = find_child("SayacLabel", true, false)
	if sayac:
		var mevcut = GameManager.envanter.size()
		var maks = GameManager.max_totem_sayisi
		sayac.text = DilYoneticisi.metin_al("totem_sayisi") % [mevcut, maks]

var _gerekli_puan_ulasildi_bilgisi_verildi: bool = false

func bolum_kurulumu(yeni_hedef: int):
	toplam_puan = 0
	hedef_puan = yeni_hedef
	_gerekli_puan_ulasildi_bilgisi_verildi = false
	if liste:
		for child in liste.get_children(): child.queue_free()
	kalici_bilgi_gizle() # Önceki turdan kalma mesajları temizle
	guncelle_ekran()

func katman_yazisi_goster(kat_no: int):
	if not katman_label: katman_label = find_child("KatmanLabel", true, false)
	if katman_label:
		katman_label.text = DilYoneticisi.metin_al("katman_yazisi") % [kat_no]
		katman_label.visible = true
		var tw = create_tween()
		katman_label.modulate.a = 0
		katman_label.scale = Vector2(1.5, 1.5)
		tw.tween_property(katman_label, "modulate:a", 1.0, 0.5)
		tw.parallel().tween_property(katman_label, "scale", Vector2(1, 1), 0.5)
		tw.tween_interval(2.0)
		tw.tween_property(katman_label, "modulate:a", 0.0, 0.5)

func puan_ekle(miktar: int, aciklama: String):
	toplam_puan += miktar
	if liste:
		var satir = Label.new()
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0.1, 0.6, 0.1)
		liste.add_child(satir)
		liste.move_child(satir, 0)
	bilgi_goster("+%d %s" % [miktar, aciklama])
	guncelle_ekran()

func guncelle_ekran():
	if quota_label: quota_label.text = str(hedef_puan)
	if score_label:
		score_label.text = str(toplam_puan)
		score_label.modulate = Color.GREEN if toplam_puan >= hedef_puan else Color.WHITE
	
	if toplam_puan >= hedef_puan and hedef_puan > 0:
		if LevelManager and LevelManager.suanki_katman > 1:
			_erken_hedef_kontrolu()

func _erken_hedef_kontrolu():
	if _gerekli_puan_ulasildi_bilgisi_verildi: return
	
	var boss_list = get_tree().get_nodes_in_group("Dusman")
	var kalan_hp = 100
	var boss_yasiyor = false
	
	for boss in boss_list:
		if is_instance_valid(boss) and "boss_hp" in boss:
			if not boss.get("oldu_mu"):
				kalan_hp = boss.boss_hp
				boss_yasiyor = true
				break
				
	if not boss_yasiyor: return # Zaten boss öldüyse gerek yok
	
	var mermi_yeterli = GameManager and GameManager.mermi_sayisi >= kalan_hp
	
	if mermi_yeterli:
		_gerekli_puan_ulasildi_bilgisi_verildi = true
		bilgi_goster("Silahını Çek (Sağ Tık) ve Boss'u Öldür!", 6.0, true)
		
		# Boss sırası ondaysa oyuncuyu sabırsız bırakmamak için kamerasını ve Inputu zorla kaldır
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu and oyuncu.has_method("stand_up"):
			oyuncu.stand_up(true)

var _kalici_mesaj_aktif: bool = false

func bilgi_goster(mesaj: String, sure: float = 2.0, kalici_mi: bool = false):
	if _kalici_mesaj_aktif and not kalici_mi: return # Eğer kalıcı bir mesaj varsa standart bilgi mesajlarını reddet!
	
	if kalici_mi: _kalici_mesaj_aktif = true
	
	if not bilgi_label: return
	if bilgi_tween: bilgi_tween.kill()
	bilgi_label.text = mesaj
	bilgi_label.modulate.a = 1.0
	
	if not kalici_mi:
		bilgi_tween = create_tween()
		bilgi_tween.tween_property(bilgi_label, "modulate:a", 0.0, sure).set_delay(1.5)

func kalici_bilgi_gizle():
	_kalici_mesaj_aktif = false
	if bilgi_label:
		if bilgi_tween: bilgi_tween.kill()
		bilgi_label.modulate.a = 0.0

func perde_ac():
	if perde: create_tween().tween_property(perde, "color:a", 0.0, 1.0)

func _animasyon_oynat_ates():
	sfx_fire.play()
	islem_mesgul = true
	if silah_gorsel:
		silah_gorsel.texture = animasyon_kareleri[7] if animasyon_kareleri.size() > 7 else null
		var tw = create_tween()
		tw.tween_property(silah_gorsel, "position", orjinal_pos + Vector2(30, -50), 0.05)
		tw.tween_property(silah_gorsel, "position", orjinal_pos, 0.1)
	_mermi_olustur()
	_muzzle_flash_goster()
	await get_tree().create_timer(0.2).timeout
	islem_mesgul = false

func _muzzle_flash_goster():
	if flash_rect:
		flash_rect.visible = true
		var tw = create_tween()
		tw.tween_property(flash_rect, "color:a", 0.0, 0.1)
		tw.tween_callback(func(): flash_rect.visible = false; flash_rect.color.a = 0.85)

func _mermi_olustur():
	if not mermi_sahnesi: return
	var cam = get_viewport().get_camera_3d()
	var ray_origin = cam.project_ray_origin(get_viewport().size / 2)
	var ray_dir = cam.project_ray_normal(get_viewport().size / 2)
	var mermi = mermi_sahnesi.instantiate()
	get_tree().current_scene.add_child(mermi)
	mermi.global_position = ray_origin + ray_dir * 1.0
	mermi.baslat(ray_dir)

func _mermi_yok_uyarisi():
	if not sfx_blank.playing: sfx_blank.play()
	if silah_gorsel:
		var tw = create_tween()
		tw.tween_property(silah_gorsel, "modulate", Color.RED, 0.1)
		tw.tween_property(silah_gorsel, "modulate", Color.WHITE, 0.1)

func _animasyon_oynat_incele():
	islem_mesgul = true
	if silah_gorsel and animasyon_kareleri.size() >= 8:
		for i in range(7, -1, -1):
			silah_gorsel.texture = animasyon_kareleri[i]
			await get_tree().create_timer(0.06).timeout
		for i in range(1, 8):
			silah_gorsel.texture = animasyon_kareleri[i]
			await get_tree().create_timer(0.06).timeout
	islem_mesgul = false
	
func mantar_efekti_yonet(aktif: bool):
	var efekt_node = get_node_or_null("MantarEfekti")
	if not efekt_node:
		efekt_node = find_child("MantarEfekti", true, false)
		
	if efekt_node:
		efekt_node.visible = aktif
		efekt_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if efekt_node.material:
			# Kullanıcı isteği: Şiddet ve bozulma yarı yarıya düşürüldü (0.02 -> 0.01)
			var guc = 0.01 if aktif else 0.0
			efekt_node.material.set_shader_parameter("strength", guc)
			print("🍄 Mantar Efekti: ", "AKTİF" if aktif else "KAPALI", " (Giriş: ", guc, ")")
