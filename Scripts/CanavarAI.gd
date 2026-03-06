extends CharacterBody3D

# ============================================================
# CanavarAI.gd — final_oda.tscn icindeki canavarin yapay zekasi
# ============================================================

# --- DURUM MAKINESI ---
enum Durum { DEVRIYE, KOS, SALDIRI }
var suanki_durum: Durum = Durum.DEVRIYE

# --- PARAMETRELER ---
@export var yurume_hizi: float = 1.8         # Devriyedeki yavas yurume hizi
@export var kos_hizi: float = 5.5            # Kovalama kosu hizi
@export var saldiri_mesafesi: float = 1.3    # Kapsüller birbirine çarptığı için 1.0 çok dardı
@export var kovalama_suresi: float = 3.0
@export var isik_algi_mesafesi: float = 20.0 # Fenerin algilanabilir mesafesi
@export var fener_kontrol_aralik: float = 0.1

var yercekimi: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Odanin devriye atilacak kose koordinatlari (Manuel Waypoints)
var devriye_noktalari: Array[Vector3] = [
	Vector3(-4.0, 0.0, -1.0),
	Vector3(-4.0, 0.0, 8.0),
	Vector3(-14.0, 0.0, 8.0),
	Vector3(-14.0, 0.0, -1.0)
]
var siradaki_hedef_idx: int = 0

# --- REFERANSLAR ---
@onready var animasyon: AnimationPlayer = $canavar_mesh/AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# --- IC DURUM ---
var oyuncu: Node3D = null
var kovalama_sayaci: float = 0.0
var suanki_animasyon: String = ""
var fener_kontrol_sayaci: float = 0.0
var oldu_mu: bool = false
var son_pozisyon: Vector3 = Vector3.ZERO
var takilma_sayaci: float = 0.0

func _ready() -> void:
	# "Anti-Gravity" (Ucma/Takilma Onleme) Ayarlari
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(45.0)

	# GODOT MOTORU HASAR KORUMASI: CharacterBody3D boyutlandırılırsa (Scale) 
	# yerin altına girer ve hareketleri (Velocity) 0'a kilitlenir. 
	# Eğer siz Editör'den 1.55 yaptıysanız, kod bunu otomatik alt dallara (Mesh ve Collider'a) paylaştırır:
	if scale != Vector3.ONE:
		var s = scale
		scale = Vector3.ONE
		for child in get_children():
			if child is Node3D and not child is NavigationAgent3D:
				child.scale *= s
				child.position = child.position * s

	await get_tree().process_frame
	oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu:
		push_warning("CanavarAI: 'Oyuncu' grubu bulunamadi!")
		return

	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 1.0
		nav_agent.path_max_distance = 2.0

	# Eger navmesh sahnede otomatik bake olmadiysa:
	var nav = get_node_or_null("../NavigationRegion3D")
	if nav and nav is NavigationRegion3D:
		nav.bake_navigation_mesh(false)
		await get_tree().create_timer(0.5).timeout

	_devriyeye_gec()

func _physics_process(delta: float) -> void:
	if oldu_mu or not is_instance_valid(oyuncu): return
	if not nav_agent: return

	match suanki_durum:
		Durum.DEVRIYE:
			_devriye_guncelle(delta)
			_fener_kontrol(delta)
			_kosma_kontrol()

		Durum.KOS:
			_kos_guncelle(delta)

		Durum.SALDIRI:
			pass

	# --- TAKILMA KONTROLU (STUCK DETECTION) ---
	if velocity.length() < 0.1 and suanki_durum == Durum.KOS:
		takilma_sayaci += delta
		if takilma_sayaci > 1.0: # 1 saniye boyunca milim oynamadıysa
			# Hafifçe oyuncudan uzağa veya rastgele bir yöne "itme" kuvveti ver
			velocity = (global_position - oyuncu.global_position).normalized() * 2.0
			move_and_slide()
			takilma_sayaci = 0.0
	else:
		takilma_sayaci = 0.0

# ============================================================
# DEVRIYE
# ============================================================
func _devriyeye_gec() -> void:
	suanki_durum = Durum.DEVRIYE
	_animasyon_oynat("kosu", 0.35)
	_yeni_devriye_hedefi()

func _devriye_guncelle(delta: float) -> void:
	var hedef = devriye_noktalari[siradaki_hedef_idx]
	hedef.y = global_position.y
	
	var mesafe = global_position.distance_to(hedef)
	if mesafe < 0.5:
		_yeni_devriye_hedefi()
		return

	var yon = (hedef - global_position).normalized()
	
	velocity.x = yon.x * yurume_hizi
	velocity.z = yon.z * yurume_hizi
	if not is_on_floor():
		velocity.y -= yercekimi * delta
	else:
		velocity.y = 0.0
		
	move_and_slide()
	
	if velocity.length() > 0.1:
		var hedef_yon = Vector2(velocity.x, velocity.z).angle()
		var hedef_rot = -hedef_yon + PI/2 
		global_rotation.y = lerp_angle(global_rotation.y, hedef_rot, delta * 5.0)

func _yeni_devriye_hedefi() -> void:
	# Bir sonraki devriye noktasina gec
	siradaki_hedef_idx = (siradaki_hedef_idx + 1) % devriye_noktalari.size()

# ============================================================
# KOVALAMA
# ============================================================
func _kovalama_baslat() -> void:
	if suanki_durum == Durum.SALDIRI: return
	suanki_durum = Durum.KOS
	kovalama_sayaci = kovalama_suresi
	_animasyon_oynat("kosu", 1.0)

func _kos_guncelle(delta: float) -> void:
	if not is_instance_valid(oyuncu): return

	# 1) Zekice Takip (Eger canavar oyuncuyu doğrudan görüyorsa sayaci sifirla)
	if _oyuncuyu_goruyor_mu():
		kovalama_sayaci = kovalama_suresi
	else:
		kovalama_sayaci -= delta
		if kovalama_sayaci <= 0.0:
			_devriyeye_gec()
			return

	# 2) NavMesh ile kovalama (Duvara dümdüz takilmayi önler)
	nav_agent.target_position = oyuncu.global_position
	
	var sonraki_nokta = nav_agent.get_next_path_position()
	var suanki_pozisyon = global_transform.origin
	sonraki_nokta.y = suanki_pozisyon.y
	
	var yeni_velocity = (sonraki_nokta - suanki_pozisyon).normalized() * kos_hizi
	
	velocity.x = yeni_velocity.x
	velocity.z = yeni_velocity.z
	
	if not is_on_floor():
		velocity.y -= yercekimi * delta
	else:
		velocity.y = 0.0
		
	move_and_slide()

	# Dönüş yumuşatması (Yürüme yönüne bak)
	if velocity.length() > 0.1:
		var hedef_yon = Vector2(velocity.x, velocity.z).angle()
		var hedef_rot = -hedef_yon + PI/2 
		global_rotation.y = lerp_angle(global_rotation.y, hedef_rot, delta * 10.0)

	var mesafe = global_position.distance_to(oyuncu.global_position)
	if mesafe <= saldiri_mesafesi:
		_saldiri_baslat()

# ============================================================
# SALDIRI
# ============================================================
func _saldiri_baslat() -> void:
	if oldu_mu: return
	suanki_durum = Durum.SALDIRI
	_animasyon_oynat("saldiri")

	var anim_uzunluk = 1.5
	if animasyon and animasyon.has_animation("saldiri"):
		anim_uzunluk = animasyon.get_animation("saldiri").length

	await get_tree().create_timer(anim_uzunluk * 0.5).timeout
	_oyuncuyu_oldurmek()

func _oyuncuyu_oldurmek() -> void:
	oldu_mu = true
	if is_instance_valid(oyuncu) and oyuncu.has_method("canavar_saldirdi"):
		oyuncu.canavar_saldirdi()

# ============================================================
# TETIKLEYICILER
# ============================================================
func _fener_kontrol(delta: float) -> void:
	fener_kontrol_sayaci -= delta
	if fener_kontrol_sayaci > 0.0: return
	fener_kontrol_sayaci = fener_kontrol_aralik

	if not is_instance_valid(oyuncu): return

	var kamera = oyuncu.get_node_or_null("Camera3D")
	if not kamera: return

	# FenerIsigi: ASCII-safe node name (SpotLight3D on Camera3D)
	var fener = kamera.get_node_or_null("FenerIsigi")
	if not fener or not fener.visible: return

	var yon_kamera_canavar = (global_position - kamera.global_position)
	var mesafe = yon_kamera_canavar.length()
	if mesafe > isik_algi_mesafesi: return

	yon_kamera_canavar = yon_kamera_canavar.normalized()
	var fener_yon = -kamera.global_transform.basis.z

	var kos_acisi = fener.spot_angle if fener is SpotLight3D else 45.0
	var esik = cos(deg_to_rad(kos_acisi * 0.6))
	var dot = fener_yon.dot(yon_kamera_canavar)

	if dot >= esik:
		var space_state = get_world_3d().direct_space_state
		var sorgu = PhysicsRayQueryParameters3D.create(
			kamera.global_position,
			global_position + Vector3.UP * 1.0,
			1 # Sadece 1. katmana (genelde duvarlar/zemin) çarpmasını sağla
		)
		sorgu.exclude = [oyuncu, self]
		var sonuc = space_state.intersect_ray(sorgu)
		# Eğer canavar ve oyuncu yoksayıldığında hiçbir şeye çarpmazsa, arada engel yoktur!
		if not sonuc:
			_kovalama_baslat()

func _oyuncuyu_goruyor_mu() -> bool:
	if not is_instance_valid(oyuncu): return false
	var space_state = get_world_3d().direct_space_state
	
	# Kafadan Kafaya
	var sorgu = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.2, 0),
		oyuncu.global_position + Vector3(0, 1.2, 0),
		1 # Sadece 1. katmana (genelde duvarlar/zemin) çarpmasını sağla
	)
	sorgu.exclude = [self, oyuncu]
	var sonuc = space_state.intersect_ray(sorgu)
	if not sonuc: return true # Engel yoksa görüyor demektir
	
	# Gövdeden Gövdeye (Alternatif görüş, bariyer arkasından eğilmeler vs için)
	sorgu.from = global_position + Vector3(0, 0.5, 0)
	sorgu.to = oyuncu.global_position + Vector3(0, 0.5, 0)
	sonuc = space_state.intersect_ray(sorgu)
	if not sonuc: return true # Engel yoksa görüyor demektir

	return false

func _canavar_mi(node: Node) -> bool:
	var p = node
	while p:
		if p == self: return true
		p = p.get_parent()
	return false

func _kosma_kontrol() -> void:
	if not is_instance_valid(oyuncu): return
	var oyuncu_hizi = oyuncu.get("velocity")
	if oyuncu_hizi == null: return
	var yatay_hiz = Vector2(oyuncu_hizi.x, oyuncu_hizi.z).length()
	if yatay_hiz > 4.0:
		var mesafe = global_position.distance_to(oyuncu.global_position)
		if mesafe < 15.0:
			_kovalama_baslat()

# ============================================================
# YARDIMCI FONKSIYONLAR
# ============================================================
func _animasyon_oynat(isim: String, hiz: float = 1.0) -> void:
	if not animasyon: return
	
	# Eger ayni animasyon ayni hizda cagiriliyorsa devam et.
	if suanki_animasyon == isim and animasyon.speed_scale == hiz: return
	
	var gercek_isim = isim
	match isim:
		"yurume": gercek_isim = "yürüme"
		"kosu":   gercek_isim = "koşu"
		"saldiri": gercek_isim = "saldırı"
		
	if not animasyon.has_animation(gercek_isim): return
	
	suanki_animasyon = isim
	animasyon.speed_scale = hiz
	animasyon.stop()
	animasyon.play(gercek_isim)
	
	var anim = animasyon.get_animation(gercek_isim)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR

# Dis sistem cagrisina izin ver (örn. ses sistemi)
func uyar() -> void:
	_kovalama_baslat()
