extends Node3D

signal saldiri_tamamlandi

var anim_player: AnimationPlayer = null

var suanki_durum: String = "IDLE"

func _ready():
	add_to_group("Dusman")
	
	# Animatoru dinamik bul (Direct cocuk veya model icindeki)
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false)
	
	print("--- STONE BOSS HAZIRLANIYOR ---")
	print("Animator: ", anim_player.name if anim_player else "BULUNAMADI")
	
	# Animasyonları yükle
	_animasyonlari_yukle()
	# Başlangıçta Idle
	idle_baslat()

func _animasyonlari_yukle():
	if not anim_player: return
	
	var lib = AnimationLibrary.new()
	
	var idle_path = "res://idle_stone.res"
	var idle_anim = load(idle_path)
	if idle_anim:
		idle_anim.loop_mode = Animation.LOOP_LINEAR
		_animasyon_olcegini_temizle(idle_anim)
		lib.add_animation("idle", idle_anim)
	else:
		print("Hata: Idle animasyonu bulunamadi: ", idle_path)
		
	var hit_path = "res://hit_stone.res"
	var hit_anim = load(hit_path)
	if hit_anim:
		_animasyon_olcegini_temizle(hit_anim)
		lib.add_animation("hit", hit_anim)
	else:
		print("Hata: Hit animasyonu bulunamadi: ", hit_path)
		
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
		
	anim_player.add_animation_library("", lib)

func idle_baslat():
	suanki_durum = "IDLE"
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle", -1, 0.5) # Yarı hızda oynat (0.5x)

func saldiri_baslat():
	# Stone Boss yalnızca taş atacak
	suanki_durum = "SALDIRI"
	
	# Kamerayı aktif et (Unified BossCamera)
	var boss_kamera = get_parent().find_child("BossCamera", true, false)
	if boss_kamera:
		boss_kamera.make_current()
	
	# Uyarı mesajı
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("bilgi_goster"):
		arayuz.bilgi_goster(DilYoneticisi.metin_al("kaya_firlatiyor"), 2.0)
	
	await get_tree().create_timer(1.0).timeout

	if anim_player and anim_player.has_animation("hit"):
		anim_player.play("hit")
		await get_tree().create_timer(0.5).timeout # Atma anını bekle (0.4 -> 0.5)
		await _tas_firlat()
		await anim_player.animation_finished
	
	idle_baslat()
	saldiri_tamamlandi.emit()

func _tas_firlat():
	var grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	if not grid: return
	
	# Rastgele bir hücre seç
	var grid_boyutu = grid.grid_boyutu if "grid_boyutu" in grid else Vector2i(5, 5)
	var hedef_hucre = Vector2i(randi_range(0, grid_boyutu.x - 1), randi_range(0, grid_boyutu.y - 1))
	
	var grid_pos = Vector3.ZERO
	if grid.has_method("cell_center_world"):
		grid_pos = grid.cell_center_world(hedef_hucre)
	
	var final_pos = Vector3(grid_pos.x, grid.global_position.y, grid_pos.z)
	
	# Taş Mermisi
	var mermi = MeshInstance3D.new()
	mermi.set_as_top_level(true)
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mermi.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.DARK_GRAY
	mat.roughness = 0.9
	mermi.material_override = mat
	
	get_tree().current_scene.add_child(mermi)
	mermi.global_position = global_position + Vector3(0, 1.5, 0)
	
	var tween = create_tween() # fixed
	tween.tween_property(mermi, "global_position", final_pos, 0.4).set_ease(Tween.EASE_IN)
	await tween.finished
	
	# Taş gride düştüğü an kamerayı oyuncuya ver
	_kamerayi_oyuncuya_ver()
	
	if is_instance_valid(mermi):
		mermi.queue_free()
	
	# Hücreyi taşla kilitle
	if is_instance_valid(grid) and grid.has_method("hucreyi_kilitle"):
		grid.hucreyi_kilitle(hedef_hucre, "TAS")

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
	pass # Stone boss hit interaction

func _animasyon_olcegini_temizle(anim: Animation):
	"""Animasyondaki tüm scale tracklerini temizleyerek boss'un küçülmesini engeller."""
	if not anim: return
	
	# Sondan başa doğru silmek güvenlidir
	for i in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(i) == Animation.TYPE_SCALE_3D:
			anim.remove_track(i)
	
	print("✅ Animasyon ölçek trackleri temizlendi: ", anim.resource_name)
