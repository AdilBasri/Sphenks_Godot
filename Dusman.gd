extends CharacterBody3D

# --- AYARLAR ---
@export var hiz: float = 3.0
@export var hasar: int = 1
@export var saldiri_menzili: float = 1.5
@export var can: int = 3

# --- REFERANSLAR ---
var oyuncu: Node3D = null
var yercekimi = 9.8

# Saldırı Zamanlaması
var saldiri_bekleme_suresi = 1.0
var son_saldiri_zamani = 0.0

func _ready():
	# Oyuncuyu gruptan bul (Daha güvenli)
	oyuncu = get_tree().get_first_node_in_group("Oyuncu")

func _physics_process(delta):
	# Yerçekimi
	if not is_on_floor():
		velocity.y -= yercekimi * delta

	if oyuncu:
		var hedef_pos = oyuncu.global_position
		var mesafe = global_position.distance_to(hedef_pos)
		
		# Oyuncuya bak (Y eksenini sabitle ki havaya bakmasın)
		look_at(Vector3(hedef_pos.x, global_position.y, hedef_pos.z), Vector3.UP)
		
		if mesafe > saldiri_menzili:
			# Yürü
			var yon = (hedef_pos - global_position).normalized()
			velocity.x = yon.x * hiz
			velocity.z = yon.z * hiz
		else:
			# Dur ve Saldır
			velocity.x = 0
			velocity.z = 0
			_saldir()
	
	move_and_slide()

func _saldir():
	# HATA BURADAYDI: "su an" -> "su_an" olarak düzeltildi.
	var su_an = Time.get_ticks_msec() / 1000.0
	
	if su_an - son_saldiri_zamani < saldiri_bekleme_suresi:
		return # Henüz saldıramaz (Cooldown)

	son_saldiri_zamani = su_an
	
	# YENİ YÖNTEM (LevelManager üzerinden saldır):
	# Bu sayede LevelManager araya girip "Pelerin var mı?" diye bakar.
	if LevelManager:
		LevelManager.oyuncuya_saldir(hasar)
	else:
		# Yedek plan
		if oyuncu and oyuncu.has_method("hasar_al"):
			oyuncu.hasar_al(hasar)
