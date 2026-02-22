extends Node3D

# --- TEXTURE EXPORT ---
@export var gold_card_texture: Texture2D
@export var sleep_card_texture: Texture2D

# --- DEĞİŞKENLER ---
var kartlar_gorunuyor: bool = false
var secim_yapildi: bool = false
var gold_kart: Node3D = null
var sleep_kart: Node3D = null
var oyuncu_kart_alani_icinde: bool = false
var gecici_nisangah: CanvasLayer = null
var kapi_sistemi: Node3D = null

func _ready():
	_kartlari_olustur()
	
	# Campfire kapısını bul ve kilitli başlat
	var sahne_koku = get_tree().current_scene
	if sahne_koku:
		var campfire_room = sahne_koku.find_child("Campfire_room", true, false)
		if campfire_room:
			kapi_sistemi = campfire_room.find_child("KapiSistemi3", true, false)
			if kapi_sistemi and kapi_sistemi.has_method("kilitle"):
				kapi_sistemi.kilitle()
	
	# Geçiş alanını bul ve bağla
	var gecis_area = _gecis_alanini_bul()
	if gecis_area:
		gecis_area.body_entered.connect(_oyuncu_girdi)
		print("✅ CampfireOdasi: Geçiş alanı bağlandı.")
	else:
		print("⚠️ CampfireOdasi: Geçiş Alan3D bulunamadı!")

func _gecis_alanini_bul() -> Area3D:
	var sahne_koku = get_tree().current_scene
	if not sahne_koku: return null
	var campfire_gecis = sahne_koku.find_child("campfire_gecis", true, false)
	if not campfire_gecis: return null
	for child in campfire_gecis.get_children():
		if child is Area3D:
			return child
	return null

# ─────────── KART OLUŞTURMA ───────────
func _kartlari_olustur():
	var kampates = get_node_or_null("KampAtesi")
	var ates_pos = Vector3.ZERO
	if kampates: ates_pos = kampates.position

	gold_kart  = _kart_olustur(gold_card_texture,  ates_pos + Vector3(-2.5, 1.0, 0.5), "GoldKart")
	sleep_kart = _kart_olustur(sleep_card_texture, ates_pos + Vector3( 2.5, 1.0, 0.5), "SleepKart")

func _kart_olustur(texture: Texture2D, konum: Vector3, ad: String) -> Node3D:
	var kart_kok = Node3D.new()
	kart_kok.name = ad
	kart_kok.position = konum
	kart_kok.scale = Vector3.ZERO  # Başlangıçta katlanmış
	add_child(kart_kok)

	# Görsel (Sprite3D)
	var sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.003
	if texture: sprite.texture = texture
	sprite.alpha_cut = 2
	kart_kok.add_child(sprite)

	# Tıklanabilir fiziksel alan (StaticBody3D)
	var sb = StaticBody3D.new()
	sb.input_ray_pickable = true  # ← Kritik! Godot 4'te tıklama için şart
	var col = CollisionShape3D.new()
	var shp = BoxShape3D.new()
	shp.size = Vector3(1.4, 2.0, 0.15)
	col.shape = shp
	sb.add_child(col)
	# Bağla: hangi kart seçildi bilgisini ilet
	sb.input_event.connect(func(_cam, event, _pos, _nrm, _idx):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if kartlar_gorunuyor and oyuncu_kart_alani_icinde and not secim_yapildi:
			_kart_secildi(kart_kok)
	)
	kart_kok.add_child(sb)

	return kart_kok

# ─────────── OYUNCU GİRİŞİ ───────────
func _oyuncu_girdi(body):
	if not body.is_in_group("Oyuncu"): return
	if kartlar_gorunuyor: return
	oyuncu_kart_alani_icinde = true
	kartlar_gorunuyor = true
	
	# 🔫 SİLAHI ZORLA KAPAT (Campfire'da silah çıkmasın)
	GameManager.silah_cekildi = false
	GameManager.pyro_aktif    = false
	# Tüm Sahne'deki SilahKatmani'nı bul ve gizle
	var silah = get_tree().get_first_node_in_group("SilahKatmani")
	if not silah:
		silah = get_tree().current_scene.find_child("SilahKatmani", true, false)
	if silah: silah.visible = false
	# Revolver gibi gruptan bul
	var revolver = get_tree().get_first_node_in_group("Arayuz")
	if revolver and revolver.has_method("_silahi_kaldir"):
		revolver._silahi_kaldir()
	
	print("🔥 Campfire: Oyuncu girdi, kartlar açılıyor | Silah kapatıldı.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_nisangahi_goster()
	_kartlari_ac()

# ─────────── KART ANİMASYONU ───────────
func _kartlari_ac():
	for kart in [gold_kart, sleep_kart]:
		if not kart: continue
		var t = create_tween()
		kart.scale = Vector3(0.0, 1.0, 1.0)
		t.tween_property(kart, "scale", Vector3(1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ─────────── NİŞANGAH ───────────
func _nisangahi_goster():
	if gecici_nisangah: return
	gecici_nisangah = CanvasLayer.new()
	gecici_nisangah.layer = 100
	get_tree().current_scene.add_child(gecici_nisangah)
	
	var tr = TextureRect.new()
	var tex = load("res://1.png")
	if tex: tr.texture = tex
	gecici_nisangah.add_child(tr)
	tr.set_anchors_preset(Control.PRESET_CENTER)
	tr.offset_left = -20; tr.offset_top = -20
	tr.offset_right = 20; tr.offset_bottom = 20
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.scale = Vector2(0.5, 0.5)
	tr.pivot_offset = Vector2(20, 20)

func _nisangahi_gizle():
	if gecici_nisangah and is_instance_valid(gecici_nisangah):
		gecici_nisangah.queue_free()
		gecici_nisangah = null

# ─────────── KART SEÇİMİ ───────────
func _kart_secildi(secilen_kart: Node3D):
	if secim_yapildi: return  # Tek seferlik seçim kilidi
	if not oyuncu_kart_alani_icinde: return
	secim_yapildi = true
	_nisangahi_gizle()
	
	print("🎮 Kart seçildi: ", secilen_kart.name)
	
	# Diğer kartı küçülterek yok et
	var diger = sleep_kart if secilen_kart == gold_kart else gold_kart
	if diger and is_instance_valid(diger):
		var t_giz = create_tween()
		t_giz.tween_property(diger, "scale", Vector3.ZERO, 0.25)
		t_giz.tween_callback(diger.queue_free)
	
	# Seçilen kartı vurgula
	var t_sec = create_tween()
	t_sec.tween_property(secilen_kart, "scale", Vector3(1.2, 1.2, 1.2), 0.2)
	t_sec.tween_property(secilen_kart, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
	await t_sec.finished
	
	if secilen_kart == gold_kart:
		await _altin_secildi()
	else:
		await _uyku_secildi()

# ─────────── ALTIN KARTI ───────────
func _altin_secildi():
	var miktar = randi_range(0, 30)
	if GameManager:
		GameManager.toplam_altin += miktar
		GameManager.emit_signal("altin_guncellendi", GameManager.toplam_altin)
		print("💰 Altın eklendi: +", miktar, " | Toplam: ", GameManager.toplam_altin)
	
	await get_tree().create_timer(1.0).timeout
	
	# Seçilen kartı da gizle
	if gold_kart and is_instance_valid(gold_kart):
		var t = create_tween()
		t.tween_property(gold_kart, "scale", Vector3.ZERO, 0.3)
		t.tween_callback(gold_kart.queue_free)
		await t.finished
	
	# Kapıyı aç, yeni bölüme geç
	_kampfire_kapisini_ac()

# ─────────── UYKU KARTI ───────────
func _uyku_secildi():
	# Göz kapanma efekti
	_gozu_kapat()
	await get_tree().create_timer(1.5).timeout
	
	# +1 can barı
	if GameManager:
		GameManager.oyuncu_kalan_bar = min(GameManager.oyuncu_kalan_bar + 1, GameManager.oyuncu_max_bar)
		GameManager.saglik_guncelle(GameManager.oyuncu_kalan_bar, GameManager.oyuncu_suanki_hp)
		print("💚 Uyku: +1 can barı → Toplam: ", GameManager.oyuncu_kalan_bar)
	
	# Yeni bölüme geç
	if LevelManager:
		LevelManager.odaya_don_ve_level_atla()

# ─────────── KAPI + BÖLÜM GEÇİŞİ ───────────
func _kampfire_kapisini_ac():
	if kapi_sistemi:
		kapi_sistemi.kilitli_mi = false
		if kapi_sistemi.has_method("kapiyi_ac"):
			kapi_sistemi.kapiyi_ac()
			print("🔓 Campfire kapısı açıldı!")
	else:
		# Kapi bulunamazsa direkt geçiş
		if LevelManager:
			LevelManager.odaya_don_ve_level_atla()

# ─────────── GÖZ KAPANMA ───────────
func _gozu_kapat():
	var canvas = CanvasLayer.new()
	canvas.layer = 99
	get_tree().current_scene.add_child(canvas)
	
	var cr = ColorRect.new()
	cr.color = Color(0, 0, 0, 0)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(cr)
	
	var t = create_tween()
	t.tween_property(cr, "color", Color(0, 0, 0, 1), 0.8).set_trans(Tween.TRANS_SINE)
