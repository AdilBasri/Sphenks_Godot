extends CanvasLayer

@export var silah_gorsel: TextureRect
@export var namlu_ucu: Marker2D
@export var mermi_sahnesi: PackedScene 

# Inspector'dan resimleri at (1..8)
@export var animasyon_kareleri: Array[Texture2D] 

var orjinal_pos: Vector2
var islem_mesgul: bool = false 

# Muzzle flash overlay
var flash_rect: ColorRect = null
var oyuncu_ref: Node = null

# --- SES ---
var sfx_inspect: AudioStreamPlayer
var sfx_blank: AudioStreamPlayer
var sfx_fire: AudioStreamPlayer

func _ready():
	# Başlangıçta silahı gizle
	visible = false
	GameManager.silah_cekildi = false  # Başlangıçta silah kesinlikle gizli
	
	sfx_inspect = AudioStreamPlayer.new()
	sfx_inspect.stream = load("res://Sesler/gun_inspect.mp3")
	add_child(sfx_inspect)
	
	sfx_blank = AudioStreamPlayer.new()
	sfx_blank.stream = load("res://Sesler/gun_blank.mp3")
	add_child(sfx_blank)
	
	sfx_fire = AudioStreamPlayer.new()
	sfx_fire.stream = load("res://Sesler/gun_fire.mp3")
	add_child(sfx_fire)
	
	if silah_gorsel:
		orjinal_pos = silah_gorsel.position
		if animasyon_kareleri.size() > 0:
			silah_gorsel.texture = animasyon_kareleri[7] # Idle
	# Muzzle flash oluştur
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.95, 0.5, 0.85)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.visible = false
	add_child(flash_rect)
	# Oyuncu referansı
	oyuncu_ref = get_tree().get_first_node_in_group("Oyuncu")

func _input(event):
	# Eğer PYRO modunda değilsek bu tuşlar çalışmasın
	if not GameManager.pyro_aktif: return
	# Oyuncu öldüyse ateş edemez
	if oyuncu_ref and oyuncu_ref.get("oldu_mu") == true: return
	
	# --- SAĞ TIK: SİLAHI ÇEK / GİZLE ---
	if event.is_action_pressed("sag_tik"): # Input Map'te 'sag_tik' (Right Mouse Button) ekli olmalı
		_silah_durumunu_degistir()
	
	# --- SOL TIK: ATEŞ (Sadece Silah Çekiliyse) ---
	if GameManager.silah_cekildi and event.is_action_pressed("ates_et") and not islem_mesgul:
		if GameManager.mermiyi_kullan():
			_animasyon_oynat_ates()
		else:
			_mermi_yok_uyarisi()

	# --- F TUŞU: İNCELEME (Sadece Silah Çekiliyse) ---
	if GameManager.silah_cekildi and event.is_action_pressed("incele") and not islem_mesgul:
		sfx_inspect.play()
		_animasyon_oynat_incele()

func _silah_durumunu_degistir():
	if islem_mesgul: return # Animasyon bitmeden değiştirme
	
	# Durumu tersine çevir
	GameManager.silah_cekildi = !GameManager.silah_cekildi
	
	if GameManager.silah_cekildi:
		# Silahı ÇIKAR
		visible = true
		
		# Aşağıdan yukarı çıkma animasyonu (Draw Animation)
		var tween = create_tween()
		silah_gorsel.position.y = get_viewport().size.y + 200 # Ekranın altından başla
		tween.tween_property(silah_gorsel, "position", orjinal_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		print("🔫 Silah Çekildi!")
	else:
		# Silahı GİZLE
		var tween = create_tween()
		tween.tween_property(silah_gorsel, "position:y", get_viewport().size.y + 200, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): visible = false) # Animasyon bitince görünmez yap
		
		print("🤚 Silah Gizlendi.")

# --- İNCELEME, ATEŞ ETME ve MERMİ KODLARI AYNEN KALIYOR ---
# (Önceki cevaptaki _animasyon_oynat_incele, _animasyon_oynat_ates, _mermi_olustur fonksiyonlarını buraya yapıştır)
# Tek fark: _input fonksiyonunu yukarıdaki gibi değiştirdik.

func _animasyon_oynat_incele():
	islem_mesgul = true
	for i in range(7, -1, -1):
		silah_gorsel.texture = animasyon_kareleri[i]
		await get_tree().create_timer(0.06).timeout
	for i in range(1, 8):
		silah_gorsel.texture = animasyon_kareleri[i]
		await get_tree().create_timer(0.06).timeout
	islem_mesgul = false

func _animasyon_oynat_ates():
	sfx_fire.play()
	islem_mesgul = true
	silah_gorsel.texture = animasyon_kareleri[7]
	var tween = create_tween()
	var tepme_vektoru = Vector2(30, -50)
	tween.tween_property(silah_gorsel, "position", orjinal_pos + tepme_vektoru, 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(silah_gorsel, "position", orjinal_pos, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_mermi_olustur()
	_muzzle_flash_goster()
	# Tüm düşmanlar öldü mü kontrol et
	await get_tree().create_timer(0.15).timeout
	islem_mesgul = false
	_dusman_kontrol()

func _muzzle_flash_goster():
	if not flash_rect: return
	flash_rect.visible = true
	var t = create_tween()
	t.tween_property(flash_rect, "color:a", 0.0, 0.08)
	t.tween_callback(func(): 
		if is_instance_valid(flash_rect):
			flash_rect.color.a = 0.85
			flash_rect.visible = false
	)

func _dusman_kontrol():
	# Pyro düşmanları bitince silahı otomatik kaldır
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	# Ölmemiş düşman var mı?
	var hayatta_kalan = false
	for d in dusmanlar:
		if is_instance_valid(d) and d.get("suanki_durum") != 99:
			hayatta_kalan = true
			break
	if not hayatta_kalan and dusmanlar.size() > 0:
		_silahi_kaldir()

func _silahi_kaldir():
	if not GameManager.silah_cekildi: return
	GameManager.silah_cekildi = false
	GameManager.pyro_aktif = false
	var tween = create_tween()
	tween.tween_property(silah_gorsel, "position:y", get_viewport().size.y + 200, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)
	print("✅ Tüm düşmanlar öldü — silah kaldırıldı.")

func _mermi_olustur():
	if not mermi_sahnesi: return
	
	var cam = get_viewport().get_camera_3d()
	
	# 1. Hedef Yönü (Ekranın Tam Ortası)
	var ekran_ortasi = get_viewport().get_visible_rect().size / 2.0
	var hedef_yonu = cam.project_ray_normal(ekran_ortasi)
	
	# 2. Başlangıç Noktası (Namlunun ucu)
	# Mermi görsel olarak silahtan çıksın ama ortaya gitsin
	var namlu_screen_pos = namlu_ucu.global_position
	var baslangic_noktasi = cam.project_ray_origin(namlu_screen_pos)
	
	# 3. Mermiyi Yarat
	var mermi = mermi_sahnesi.instantiate()
	get_tree().current_scene.add_child(mermi)
	
	# Mermiyi kameranın biraz önünden başlat (İç içe girmesin)
	mermi.global_position = baslangic_noktasi + (hedef_yonu * 1.0)
	
	# Mermiye "Ekranın ortasına git" emri ver
	mermi.baslat(hedef_yonu)

func _mermi_yok_uyarisi():
	if not sfx_blank.playing:
		sfx_blank.play()
	var tween = create_tween()
	tween.tween_property(silah_gorsel, "modulate", Color.RED, 0.1)
	tween.tween_property(silah_gorsel, "modulate", Color.WHITE, 0.1)
