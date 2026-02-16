extends CharacterBody3D

@export var hiz: float = 4.0
@export var saglik: int = 100

# --- SAHNELER ---
@export var kopan_kol_sahnesi: PackedScene 
@export var kopan_bacak_sahnesi: PackedScene 
@export var kopan_kafa_sahnesi: PackedScene
@export var kan_spreyi_sahnesi: PackedScene 

@onready var anim_player = find_child("AnimationPlayer", true, false)
@onready var iskelet = find_child("Skeleton3D", true, false)
@onready var collision_shape = $CollisionShape3D

var oyuncu = null
var suanki_durum = 0 # 0: Kosu, 1: Saldiri, 99: Olum
var kemik_on_eki = "" 

func _ready():
	add_to_group("Dusman")
	oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu: oyuncu = get_tree().current_scene.find_child("Oyuncu", true, false)
	
	if iskelet:
		var ilk_kemik = iskelet.get_bone_name(0)
		if "mixamorig_" in ilk_kemik: kemik_on_eki = "mixamorig_"
		elif "mixamorig:" in ilk_kemik: kemik_on_eki = "mixamorig:"
		_meta_verilerini_yukle()

	if anim_player:
		anim_player.play("Run")

func _meta_verilerini_yukle():
	var tanimlar = { "KAFA": "Head", "Sag_Kol": "RightArm", "Sol_Kol": "LeftArm", "Sag_Bacak": "RightLeg", "Sol_Bacak": "LeftLeg" }
	for node_adi in tanimlar:
		var bone_node = iskelet.find_child(node_adi, true, false)
		if bone_node:
			var area = bone_node.find_child("Area3D", true, false)
			if area: area.set_meta("Bolge", tanimlar[node_adi])

func _physics_process(delta):
	# Ölüler hareket etmez, yerçekimine maruz kalır
	if suanki_durum == 99:
		if not is_on_floor(): velocity.y -= 9.8 * delta
		return 
		
	if not oyuncu: return

	if GameManager and GameManager.fener_aktif:
		if anim_player: anim_player.pause()
		return
	else:
		if anim_player and not anim_player.is_playing(): anim_player.play()

	# Yüzünü dön ve ilerle
	var hedef = oyuncu.global_position
	hedef.y = global_position.y
	look_at(hedef, Vector3.UP)
	rotate_y(deg_to_rad(180))
	
	if global_position.distance_to(oyuncu.global_position) > 1.5:
		var anlik_hiz = hiz
		if GameManager and GameManager.pyro_yavaslatma: anlik_hiz *= 0.5
		velocity = global_transform.basis.z * anlik_hiz
		move_and_slide()
	
	if not is_on_floor(): velocity.y -= 9.8 * delta

# --- ÇARPIŞMA VE PARÇALANMA ---
func hasar_al_bolgesel(bolge_adi: String):
	if suanki_durum == 99: return # Ölüye vurulmaz
	
	print("💥 HASAR: ", bolge_adi)
	_kan_fiskirt(bolge_adi)
	
	match bolge_adi:
		"Head":
			# Kafa: Tek atar
			uzuv_firlat("Head", kopan_kafa_sahnesi)
			kemik_gizle("Head")
			olum_efekti()
			
		"RightArm":
			# Kol: 30 hasar vurur, kolu koparır ama öldürmez
			uzuv_firlat("RightArm", kopan_kol_sahnesi) 
			kemik_gizle("RightArm"); kemik_gizle("RightForeArm"); kemik_gizle("RightHand")
			_hitbox_kapat("RightArm")
			hasar_ver(30)
			
		"LeftArm":
			uzuv_firlat("LeftArm", kopan_kol_sahnesi)
			kemik_gizle("LeftArm"); kemik_gizle("LeftForeArm"); kemik_gizle("LeftHand")
			_hitbox_kapat("LeftArm")
			hasar_ver(30)
			
		"RightLeg":
			uzuv_firlat("RightLeg", kopan_bacak_sahnesi)
			kemik_gizle("RightUpLeg"); kemik_gizle("RightLeg")
			_hitbox_kapat("RightLeg")
			hiz *= 0.3 # Çok yavaşlar
			hasar_ver(30)
			
		"LeftLeg":
			uzuv_firlat("LeftLeg", kopan_bacak_sahnesi)
			kemik_gizle("LeftUpLeg"); kemik_gizle("LeftLeg")
			_hitbox_kapat("LeftLeg")
			hiz *= 0.3
			hasar_ver(30)
			
		_:
			# Gövde: 25 hasar
			hasar_ver(25)

func hasar_ver(miktar: int):
	saglik -= miktar
	print("🩸 Kalan Sağlık: ", saglik)
	
	if saglik <= 0:
		olum_efekti()
	else:
		# Canı varsa sendeleme animasyonu eklenebilir
		pass

# HATA ÇÖZÜMÜ: 0 YERİNE 0.001 KULLANIYORUZ
func kemik_gizle(saf_kemik_adi: String):
	if not iskelet: return
	var tam_ad = kemik_on_eki + saf_kemik_adi
	var idx = iskelet.find_bone(tam_ad)
	if idx != -1:
		iskelet.set_bone_pose_scale(idx, Vector3(0.001, 0.001, 0.001))

func uzuv_firlat(kemik_adi: String, sahne: PackedScene):
	if not sahne: return
	var parca = sahne.instantiate()
	get_tree().current_scene.add_child(parca)
	
	var tam_ad = kemik_on_eki + kemik_adi
	var idx = iskelet.find_bone(tam_ad)
	
	# Parçayı biraz yukarıdan başlat ki yere düşsün
	var pos = global_position 
	pos.y += 1.5 
	if "Leg" in kemik_adi: pos.y = 0.8
	
	parca.global_position = pos
	
	# Yere doğru düşmesi için
	if parca is RigidBody3D:
		parca.linear_velocity = Vector3(randf()-0.5, 2, randf()-0.5) * 2.0

func _kan_fiskirt(bolge_adi: String):
	if not kan_spreyi_sahnesi: return
	var kan = kan_spreyi_sahnesi.instantiate()
	add_child(kan) 
	kan.position = Vector3(0, 1.5, 0)
	if kan is GPUParticles3D: kan.emitting = true

func _hitbox_kapat(hedef_meta: String):
	for cocuk in iskelet.get_children():
		if cocuk is BoneAttachment3D:
			for torun in cocuk.get_children():
				if torun is Area3D and torun.has_meta("Bolge"):
					if torun.get_meta("Bolge") == hedef_meta:
						torun.call_deferred("queue_free")

func olum_efekti():
	if suanki_durum == 99: return
	suanki_durum = 99
	print("💀 ÖLDÜ!")
	
	# Hareketi durdur
	velocity = Vector3.ZERO
	collision_shape.set_deferred("disabled", true)
	
	# 1. Ölüm Animasyonunu Oynat
	if anim_player:
		if anim_player.has_animation("Death"):
			anim_player.play("Death")
			# Animasyon bitene kadar bekle (Örn: 2.5 saniye)
			await get_tree().create_timer(3.0).timeout
		else:
			# Animasyon yoksa devrilme efekti (Manuel rotasyon)
			var tween_rot = create_tween()
			tween_rot.tween_property(self, "rotation:x", deg_to_rad(-90), 0.5)
			await get_tree().create_timer(3.0).timeout

	# 2. Yerde 3 saniye yattıktan sonra GÖMÜLME başlasın
	var tween_sink = create_tween()
	tween_sink.tween_property(self, "position:y", position.y - 1.5, 4.0)
	tween_sink.tween_callback(queue_free)
