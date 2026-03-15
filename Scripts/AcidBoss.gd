extends Node3D

signal saldiri_tamamlandi

var anim_player: AnimationPlayer = null
var boss_kamera: Camera3D = null

var suanki_durum: String = "IDLE"
var boss_hp: int = 2
var oldu_mu: bool = false
var _saldiri_resume_ediliyor: bool = false
var glitch_canvas: CanvasLayer = null
var glitch_ui_rect: TextureRect = null

@export_group("QTE Ayarları")
@export var glitch_yuzu_dokusu: Texture2D
@export var kirik_cam_sesi: AudioStream

func _ready():
	add_to_group("Dusman")
	add_to_group("boss")
	
	# Animatoru dinamik bul (Direct cocuk veya model icindeki)
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false)
	
	print("--- ACID BOSS HAZIRLANIYOR ---")
	print("Animator: ", anim_player.name if anim_player else "BULUNAMADI")
	
	if GameManager:
		GameManager.boss_oldu.connect(_on_boss_oldu_sinyali)
	
	# Katmana göre HP belirle
	_hp_ayarla()
	
	# Mermi hitbox oluştur
	_hitbox_olustur()
	
	# Animasyonları yükle
	_animasyonlari_yukle()
	
	# Birleşik Boss kamerasını bul
	boss_kamera = get_parent().find_child("BossCamera", true, false)
	
	# Başlangıçta Idle
	idle_baslat()

func _animasyonlari_yukle():
	if not anim_player: return
	
	var lib = AnimationLibrary.new()
	
	var idle_path = "res://idle_acid.res"
	var idle_anim = load(idle_path)
	if idle_anim:
		idle_anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("idle", idle_anim)
	else:
		print("Hata: Idle animasyonu bulunamadi: ", idle_path)
		
	var hit_path = "res://hit_acid.res"
	var hit_anim = load(hit_path)
	if hit_anim:
		lib.add_animation("hit", hit_anim)
	else:
		print("Hata: Hit animasyonu bulunamadi: ", hit_path)
		
	var shooting_path = "res://shooting_acid.res"
	var shooting_anim = load(shooting_path)
	if shooting_anim:
		lib.add_animation("shooting", shooting_anim)
	else:
		print("Hata: Shooting animasyonu bulunamadi: ", shooting_path)
		
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
		
	anim_player.add_animation_library("", lib)

func idle_baslat():
	suanki_durum = "IDLE"
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle", -1, 0.5) # Yarı hızda oynat (0.5x)

func saldiri_baslat():
	# Acid Boss yalnızca asit atacak
	suanki_durum = "SALDIRI"
	
	# Kamerayı aktif et
	if boss_kamera:
		boss_kamera.make_current()
	
	# --- 👁️ GLITCH PARRY WINDOW (PRE-ATTACK) ---
	if not _saldiri_resume_ediliyor:
		var parry_basarili = await pre_attack()
		if parry_basarili:
			# PARRY EDİLDİ! Saldırı sekansını tamamen durdur.
			# Boss, Ghost Move periyodu bitene veya oyuncu blok koyana kadar donar.
			return
	_saldiri_resume_ediliyor = false
	# -------------------------------------------

	# Telegraph mesajı
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster(DilYoneticisi.metin_al("asit_tukuruyor"), 1.5)
	
	await get_tree().create_timer(1.0).timeout

	if anim_player and anim_player.has_animation("shooting"):
		anim_player.play("shooting")
		await get_tree().create_timer(0.5).timeout # Atma anını bekle
		await _asit_firlat() # Bekle ki kamera içeride değişsin
	
	idle_baslat()
	saldiri_tamamlandi.emit()

func _asit_firlat():
	var grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	if not grid: return
	
	# Rastgele bir hücre seç (BossCanavar.gd ile benzer mantık)
	var grid_boyutu = grid.grid_boyutu if "grid_boyutu" in grid else Vector2i(5, 5)
	var hedef_hucre = Vector2i(randi_range(0, grid_boyutu.x - 1), randi_range(0, grid_boyutu.y - 1))
	
	var grid_pos = Vector3.ZERO
	if grid.has_method("cell_center_world"):
		grid_pos = grid.cell_center_world(hedef_hucre)
	
	var final_pos = Vector3(grid_pos.x, grid.global_position.y, grid_pos.z)
	
	# Asit Mermisi (Sphere)
	var mermi = MeshInstance3D.new()
	mermi.set_as_top_level(true)
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mermi.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.GREEN
	mat.emission_enabled = true
	mat.emission = Color.GREEN
	mermi.material_override = mat
	
	get_tree().current_scene.add_child(mermi)
	mermi.global_position = global_position + Vector3(0, 1.5, 0)
	
	var tween = create_tween()
	tween.tween_property(mermi, "global_position", final_pos, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished
	
	# Asit gride düştüğü an kamerayı oyuncuya ver
	_kamerayi_oyuncuya_ver()
	
	if is_instance_valid(mermi):
		mermi.queue_free()
	
	# Hücreyi asitle kilitle
	if is_instance_valid(grid) and grid.has_method("hucreyi_kilitle"):
		grid.hucreyi_kilitle(hedef_hucre, "ASIT")

func _kamerayi_oyuncuya_ver():
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		var cam = oyuncu.find_child("Camera3D", true, false)
		if cam:
			cam.make_current()

func boss_durumu_sifirla():
	idle_baslat()
	# Kamera iade
	_kamerayi_oyuncuya_ver()

func hasar_al_bolgesel(_bolge_adi: String):
	"""Mermi çarptığında tetiklenir."""
	if suanki_durum == "HIT": return
	
	var eski_durum = suanki_durum
	suanki_durum = "HIT"
	
	if anim_player and anim_player.has_animation("hit"):
		anim_player.play("hit")
		await anim_player.animation_finished
	
	# Eğer hala hayattaysa (veya durum değişmediyse) idle'a dön
	if suanki_durum == "HIT":
		idle_baslat()

# ==========================================
# KATMANA GÖRE HP AYARLAMA
# ==========================================

func _hp_ayarla():
	"""Katmana ve dengelere göre boss HP değerini her zaman 2'ye sabitler."""
	boss_hp = 2
	print("💚 ACID BOSS HP: %d (Sabit)" % boss_hp)

# ==========================================
# MERMİ HITBOX OLUŞTURMA
# ==========================================

func _hitbox_olustur():
	"""Boss'a mermi algılayacak bir Area3D hitbox ekler."""
	var hitbox = Area3D.new()
	hitbox.name = "BossHitbox"
	hitbox.add_to_group("BossHitbox")
	hitbox.collision_layer = 4  # Mermiyle etkileşim katmanı
	hitbox.collision_mask = 4   # Mermi katmanını algıla
	hitbox.monitorable = true
	hitbox.monitoring = false
	hitbox.input_ray_pickable = false # Raycast'leri (mouse seçimini) engellemesin
	
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 1.0
	shape.height = 3.0
	col.shape = shape
	col.position = Vector3(0, 1.2, -1.0)
	hitbox.add_child(col)
	
	add_child(hitbox)
	print("🎯 ACID BOSS hitbox oluşturuldu.")

# ==========================================
# MERMİ HASARI ALMA
# ==========================================

func mermi_hasari_al(hit_pos: Vector3, hit_dir: Vector3):
	"""Oyuncunun mermisi boss'a çarptığında çağrılır. HP 1 azalır."""
	if oldu_mu: return
	
	boss_hp -= 1
	print("🔫 ACID BOSS'a mermi çarptı! Kalan HP: %d" % boss_hp)
	
	# 1 — Kan Efekti Spawn
	_kan_efekti_olustur(hit_pos, hit_dir)
	
	# 2 — Görsel Darbe Efekti (Sarsılma)
	# Not: AnimasyonPlayer'ı kesmiyoruz ki saldırı bozulmasın.
	_darbe_efekti_oynat()
	
	if boss_hp <= 0:
		_boss_oldu_mermi()

func hasar_al(miktar: int, hit_pos: Vector3 = Vector3.ZERO):
	mermi_hasari_al(hit_pos, Vector3.ZERO)

func _kan_efekti_olustur(pos: Vector3, dir: Vector3):
	var kan_sahne = load("res://Scenes/KanSpreyi.tscn")
	if kan_sahne:
		var kan = kan_sahne.instantiate()
		get_tree().current_scene.add_child(kan)
		
		# Kan efektini boss'un biraz daha içine itiyoruz
		kan.global_position = pos + (dir * 0.4)
		
		if kan is CPUParticles3D:
			kan.direction = dir
			kan.spread = 15.0
			kan.initial_velocity_min = 8.0
			kan.initial_velocity_max = 15.0
			
			# Efekt süresini kısaltıyoruz
			kan.lifetime = 0.3
			kan.emitting = true
			
			var sfx = AudioStreamPlayer3D.new()
			sfx.stream = load("res://Assets/Audio/BloodSplatter.mp3")
			sfx.bus = "SFX"
			sfx.max_distance = 20.0
			kan.add_child(sfx)
			sfx.play()
			
			get_tree().create_timer(0.5).timeout.connect(kan.queue_free)

func _darbe_efekti_oynat():
	# 1 — Violent Shake (Root Node sarsılır ki AnimationPlayer karışmasın)
	var orj_pos = global_position
	var tween = create_tween()
	var sarsma_gucu = 0.35 
	
	for i in range(3):
		var rand_offset = Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1)).normalized() * sarsma_gucu
		tween.tween_property(self, "global_position", orj_pos + rand_offset, 0.03)
		tween.tween_property(self, "global_position", orj_pos, 0.03)
	
	# 2 — Hit Flash (Parlamayı güçlendirdim)
	_modulate_recursive(self, Color(10.0, 1.0, 1.0), 0.08)

func _modulate_recursive(node: Node, color: Color, duration: float):
	if node is Sprite3D:
		var tween = create_tween()
		tween.tween_property(node, "modulate", color, duration)
		tween.tween_property(node, "modulate", Color.WHITE, duration)
	elif node is MeshInstance3D:
		var org_overlay = node.material_overlay
		var hit_mat = StandardMaterial3D.new()
		hit_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5) 
		hit_mat.emission_enabled = true
		hit_mat.emission = Color(1.0, 0.0, 0.0)
		hit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_overlay = hit_mat
		
		get_tree().create_timer(duration * 1.5).timeout.connect(func():
			if is_instance_valid(node):
				node.material_overlay = org_overlay
		)
		
	for child in node.get_children():
		_modulate_recursive(child, color, duration)

func _boss_oldu_mermi():
	"""Boss mermiyle öldürüldüğünde çağrılır — kapıyı otomatik açar."""
	if oldu_mu: return
	oldu_mu = true
	suanki_durum = "OLDU"
	
	print("☠️ ACID BOSS MERMİYLE ÖLDÜRÜLDÜ!")
	
	# GameManager'a boss öldü bildir
	if GameManager:
		GameManager.boss_oldu.emit()
	
	_olum_sekans()

func _on_boss_oldu_sinyali():
	"""GameManager'dan gelen ölüm sinyali (Acid Boss)."""
	if oldu_mu: return
	oldu_mu = true
	suanki_durum = "OLDU"

	print("☠️ ACID BOSS ÖLÜYOR...")
	_olum_sekans()

func _olum_sekans():
	"""Ölüm animasyonu, patlama efekti ve kapı açma."""
	if anim_player:
		anim_player.stop()

	_kamerayi_oyuncuya_ver()

	if LevelManager:
		LevelManager.is_boss_acting = false
	
	# 1 — Patlama efekti spawn (Modelin tam konumunda)
	var patlama_sahne = load("res://efektler/boss_patlama.tscn")
	if patlama_sahne:
		var patlama = patlama_sahne.instantiate()
		get_parent().add_child(patlama)
		# AcidBossModel node'unun pozisyonunu kullanıyoruz
		var model_pos = global_position
		if has_node("AcidBossModel"):
			model_pos = get_node("AcidBossModel").global_position
		patlama.global_position = model_pos + Vector3(0, 1, 0)
	
	await get_tree().create_timer(0.1).timeout
	
	# 2 — Yerin altına girme (Hızlı ve belirsiz)
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 12.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	visible = false
	
	var bariyer = get_tree().get_first_node_in_group("Bariyer")
	if bariyer and bariyer.has_method("bolum_bitti"):
		bariyer.bolum_bitti()
	
	# 3 — KAPIYI OTOMATİK AÇ
	_kapiyi_otomatik_ac()
		
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _kapiyi_otomatik_ac():
	"""Boss öldüğünde kapıyı otomatik açar (tüm boss'lar ölmüşse)."""
	# Çift boss kontrolü: Dusman grubunda hayatta boss var mı?
	var dusmanlar = get_tree().get_nodes_in_group("Dusman")
	for d in dusmanlar:
		if is_instance_valid(d) and d != self:
			var d_oldu = d.get("oldu_mu")
			if d_oldu == null or d_oldu == false:
				print("⏳ Diğer boss hâlâ hayatta, kapı açılmayacak.")
				return
	
	var kapi = get_tree().current_scene.find_child("KapiSistemi", true, false)
	if kapi and kapi.has_method("kapiyi_ac"):
		# Kilidi kaldır ve aç
		if "kilitli_mi" in kapi:
			kapi.kilitli_mi = false
		kapi.kapiyi_ac()
		print("🚪 Tüm boss'lar öldü — Kapı otomatik açıldı!")
	else:
		print("⚠️ KapiSistemi bulunamadı, kapı açılamadı!")

# ==========================================
# 🌌 GLITCH PARRY (REALITY DENIAL)
# ==========================================

func pre_attack() -> bool:
	"""
	Saldırı öncesi kısa (0.5s) pencere açar. 
	Oyuncu bu pencerede sağ tıklarsa gerçekliği inkar eder (Glitch Parry).
	"""
	if not glitch_yuzu_dokusu: return false
	
	if GameManager: GameManager.is_parry_window_open = true
	glitch_yuzu_kapat()
	
	# Ekranda Korkunç Yüz Göster
	glitch_ui_rect = TextureRect.new()
	glitch_ui_rect.texture = glitch_yuzu_dokusu
	glitch_ui_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glitch_ui_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	glitch_ui_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_ui_rect.modulate = Color(1, 1, 1, 0.8)
	
	var mat = ShaderMaterial.new()
	var shader = load("res://Materials_Shaders/glitch_yuz.gdshader")
	if shader: mat.shader = shader
	glitch_ui_rect.material = mat
	
	glitch_canvas = CanvasLayer.new()
	glitch_canvas.layer = 99 
	glitch_canvas.add_child(glitch_ui_rect)
	add_child(glitch_canvas)
	
	await get_tree().create_timer(0.5, false).timeout
	
	if GameManager and GameManager.is_parry_window_open:
		GameManager.is_parry_window_open = false
		glitch_yuzu_kapat()
		return false
	else:
		glitch_yuzu_kapat()
		if kirik_cam_sesi:
			var as_player = AudioStreamPlayer3D.new()
			as_player.stream = kirik_cam_sesi
			as_player.max_distance = 15.0
			add_child(as_player)
			as_player.play()
			as_player.finished.connect(as_player.queue_free)
			
		print("❌ ACID BOSS ATTACK CANCELLED! (GLITCH PARRY)")
		return true

func glitch_yuzu_kapat():
	if is_instance_valid(glitch_canvas):
		glitch_canvas.queue_free()
		glitch_canvas = null
		glitch_ui_rect = null

func gercek_saldiri_basa_don():
	"""Ghost Move bitince (5s sessizlik) saldırıya devam et."""
	print("⏳ Ghost Move bitti (Acid). Boss saldırıya geçiyor!")
	await get_tree().create_timer(0.5).timeout
	_saldiri_resume_ediliyor = true
	saldiri_baslat()
