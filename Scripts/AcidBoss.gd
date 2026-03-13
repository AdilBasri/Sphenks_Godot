extends Node3D

signal saldiri_tamamlandi

var anim_player: AnimationPlayer = null
@onready var kamera: Camera3D = $Camera3D

var suanki_durum: String = "IDLE"

func _ready():
	add_to_group("Dusman")
	
	# Animatoru dinamik bul (Direct cocuk veya model icindeki)
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false)
	
	print("--- ACID BOSS HAZIRLANIYOR ---")
	print("Animator: ", anim_player.name if anim_player else "BULUNAMADI")
	
	# Animasyonları yükle
	_animasyonlari_yukle()
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
	if kamera:
		kamera.make_current()
	
	# Uyarı mesajı
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster(DilYoneticisi.metin_al("asit_tukuruyor"), 2.0)
	
	await get_tree().create_timer(1.0).timeout

	if anim_player and anim_player.has_animation("shooting"):
		anim_player.play("shooting")
		await get_tree().create_timer(0.5).timeout # Atma anını bekle
		await _asit_firlat() # Bekle ki kamera içeride değişsin
		await anim_player.animation_finished
	
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
