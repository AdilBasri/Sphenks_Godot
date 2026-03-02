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
var cards_resolved: bool = false # KART SEÇİMİ VE KAPI ETKİLEŞİMİ DÜZELTMESİ

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
		# Sadece bir kere tetiklenmesi için one_shot bağlantı yapıyoruz (Auto-Door Close Bug)
		gecis_area.body_entered.connect(_oyuncu_girdi)
		print("✅ CampfireOdasi: Geçiş alanı bağlandı.")
	else:
		print("⚠️ CampfireOdasi: Geçiş Alan3D bulunamadı!")


func _gecis_alanini_bul() -> Area3D:
	var gecis_area2 = Area3D.new()
	var col2 = CollisionShape3D.new()
	var shp2 = BoxShape3D.new()
	shp2.size = Vector3(35.0, 15.0, 35.0) # Alanı tüm odayı kaplayacak ama taşmayacak makul bir seviyeye getirdik
	col2.shape = shp2
	gecis_area2.add_child(col2)
	var kmp2 = get_node_or_null("KampAtesi")
	if kmp2: gecis_area2.position = kmp2.position
	add_child(gecis_area2)
	gecis_area2.collision_layer = 0
	gecis_area2.collision_mask = 1
	return gecis_area2

# ─────────── KART OLUŞTURMA ───────────
func _kartlari_olustur():
	var kampates = get_node_or_null("KampAtesi")
	var ates_pos = Vector3.ZERO
	if kampates: ates_pos = kampates.global_position

	gold_kart  = _kart_olustur(gold_card_texture,  ates_pos + Vector3(-2.5, 1.0, 0.5), "GoldKart")
	sleep_kart = _kart_olustur(sleep_card_texture, ates_pos + Vector3( 2.5, 1.0, 0.5), "SleepKart")

func _kart_olustur(texture: Texture2D, konum: Vector3, ad: String) -> Node3D:
	var kart_kok = Node3D.new()
	kart_kok.name = ad
	add_child(kart_kok) # Doğrudan eklensin ki scale vs yamulmasın, global_position çalışsın.
	kart_kok.global_position = konum
	kart_kok.scale = Vector3(0.001, 0.001, 0.001)  # Başlangıçta katlanmış

	# Görsel (Sprite3D)
	var sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 0.003
	if texture: sprite.texture = texture
	sprite.alpha_cut = 2
	kart_kok.add_child(sprite)

	# Tıklanabilir fiziksel alan (StaticBody3D)
	var sb = StaticBody3D.new()
	sb.add_to_group("CampfireKart")
	sb.input_ray_pickable = true  # ← Kritik! Godot 4'te tıklama için şart
	var col = CollisionShape3D.new()
	var shp = BoxShape3D.new()
	shp.size = Vector3(2.8, 4.0, 1) # 2 katı büyütüldü: (1.4, 2.0, 0.15) -> (2.8, 4.0, 0.3)
	col.shape = shp
	sb.add_child(col)
	kart_kok.add_child(sb)

	return kart_kok

# ─────────── OYUNCU GİRİŞİ ───────────
func _oyuncu_girdi(body):
	if not body.is_in_group("Oyuncu"): return
	if kartlar_gorunuyor: return
	oyuncu_kart_alani_icinde = true
	kartlar_gorunuyor = true
	
	# Giriş kapısını bulup kapat (Auto-Door Close Bug)
	get_tree().call_group("Kapi", "_oyuncu_gecti", body)
	var sahne_koku = get_tree().current_scene
	if sahne_koku:
		var c_room = null
		if "Campfire" in sahne_koku.name:
			c_room = sahne_koku
		else:
			c_room = sahne_koku.find_child("*Campfire*", true, false)
			
		if c_room:
			for child in c_room.get_children():
				if child is Node3D and "KapiSistemi" in child.name and child.name != "KapiSistemi3" and child.has_method("_oyuncu_gecti"):
					child._oyuncu_gecti(body) # Kapıyı kapat ve kilitle
	
	# 🔫 SİLAHI ZORLA KAPAT VE OYUNCU DURUMUNU GÜNCELLE (Forced Weapon Unequip Bug)
	GameManager.silah_cekildi = false
	GameManager.pyro_aktif    = false
	
	# Oyuncu statüsünü "Safe" yap ve silahı kapat
	body.set("state", "Safe") # Eğer state machine varsa Safe state e zorla
	if body.has_method("unequip_weapons"):
		body.unequip_weapons()
	elif body.has_method("hide_weapon"):
		body.hide_weapon()
	body.set("weapon_input_disabled", true) # Silah inputlarını engelle
	
	# Mevcut mantıktaki silah gizleme kodu
	var silah = get_tree().get_first_node_in_group("SilahKatmani")
	if not silah:
		silah = get_tree().current_scene.find_child("SilahKatmani", true, false)
	if silah: silah.visible = false
	var revolver = get_tree().get_first_node_in_group("Arayuz")
	if revolver and revolver.has_method("_silahi_kaldir"):
		revolver._silahi_kaldir()
	
	print("🔥 Campfire: Oyuncu girdi, kartlar açılıyor | Silah kapatıldı.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_nisangahi_goster()
	_kartlari_ac()
	
	# Ateş sesini odaya girince başlatma
	var kampates = get_node_or_null("KampAtesi")
	if kampates and not kampates.has_node("CampfireSfxPlayer"):
		var sfx = AudioStreamPlayer3D.new()
		sfx.name = "CampfireSfxPlayer"
		var stream = load("res://Sesler/campfire.mp3")
		if stream and stream is AudioStream:
			if stream.has_method("set_loop"): stream.set_loop(true)
			elif "loop" in stream: stream.loop = true
		sfx.stream = stream
		sfx.bus = "Master"
		sfx.autoplay = true
		kampates.add_child(sfx)


# ─────────── KART ANİMASYONU ───────────
func _kartlari_ac():
	for kart in [gold_kart, sleep_kart]:
		if not kart or not is_instance_valid(kart): continue
		var t = create_tween()
		kart.scale = Vector3(0.001, 1.0, 1.0)
		t.tween_property(kart, "scale", Vector3(1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ─────────── NİŞANGAH ───────────
func _nisangahi_goster():
	pass

func _nisangahi_gizle():
	pass

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
		t_giz.tween_property(diger, "scale", Vector3(0.001, 0.001, 0.001), 0.25)
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
	cards_resolved = true # İlerleme bayrağını işaretle
	var miktar = randi_range(0, 30)
	if GameManager:
		GameManager.toplam_altin += miktar
		GameManager.emit_signal("altin_guncellendi", GameManager.toplam_altin)
		print("💰 Altın eklendi: +", miktar, " | Toplam: ", GameManager.toplam_altin)
	
	await get_tree().create_timer(1.0).timeout
	
	# Seçilen kartı da gizle
	if gold_kart and is_instance_valid(gold_kart):
		var t = create_tween()
		t.tween_property(gold_kart, "scale", Vector3(0.001, 0.001, 0.001), 0.3)
		t.tween_callback(gold_kart.queue_free)
		await t.finished
	
	# Kapıyı aç, yeni bölüme geç
	_kampfire_kapisini_ac()

# ─────────── UYKU KARTI ───────────
func _uyku_secildi():
	cards_resolved = true # İlerleme bayrağını işaretle
	# Göz kapanma efekti
	_gozu_kapat()
	await get_tree().create_timer(1.5).timeout
	
	# +1 can barı
	if GameManager:
		if GameManager.oyuncu_kalan_bar < GameManager.oyuncu_max_bar:
			GameManager.oyuncu_kalan_bar += 1
			GameManager.saglik_guncelle(GameManager.oyuncu_kalan_bar, GameManager.oyuncu_suanki_hp)
			print("💚 Uyku: +1 can barı → Toplam: ", GameManager.oyuncu_kalan_bar)
		else:
			GameManager.oyuncu_suanki_hp = 10
			GameManager.saglik_guncelle(GameManager.oyuncu_kalan_bar, GameManager.oyuncu_suanki_hp)
			print("💚 Uyku: Zaten max barsın, mevcut hp tam dolduruldu.")
	
	# Yeni bölüme geç (Uyku sahnesine git ya da hak bittiyse/uygun değilse direkt atla)
	var direkt_atla = false
	var ucuncu_ruyaya_git = false
	if GameManager:
		if GameManager.uyku_sahnesi_giris_sayisi >= 3:
			direkt_atla = true
		elif GameManager.uyku_sahnesi_giris_sayisi == 2:
			ucuncu_ruyaya_git = true
		elif GameManager.uyku_sahnesi_giris_sayisi == 1:
			# 3'ün katı olan Pyro bölümüne girmeden önceyse 2. rüyayı ertele
			if LevelManager and (LevelManager.suanki_katman + 1) % 3 == 0:
				direkt_atla = true
				
	if direkt_atla:
		if LevelManager:
			LevelManager.odaya_don_ve_level_atla()
	elif ucuncu_ruyaya_git:
		if GameManager: GameManager.uyku_sahnesi_giris_sayisi += 1
		get_tree().change_scene_to_file("res://sandik_odasi.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/UykuSahnesi.tscn")

# ─────────── KAPI + BÖLÜM GEÇİŞİ ───────────
func _kampfire_kapisini_ac():
	if kapi_sistemi:
		kapi_sistemi.kilitli_mi = false
		print("🔓 Campfire kapısının kilidi açıldı, oyuncu etkileşime girebilir!")
		# Otomatik açılması yerine oyuncunun etkileşime girmesi için kapiyi_ac() KALDIRILDI
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
