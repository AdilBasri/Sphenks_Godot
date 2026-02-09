extends CharacterBody3D

# Hız ve Can ayarları
@export var hiz: float = 3.5 
@export var saglik: int = 20 # 20 Can = 2 Mermi (Her mermi 10 vurur)

@onready var anim_sprite = $AnimatedSprite3D
@onready var collision_shape = $CollisionShape3D

var oyuncu: Node3D = null
var hasar_verdi_mi: bool = false 
var oluyor: bool = false

func _ready():
	add_to_group("Dusman")
	
	# Editörde boyut ne olursa olsun, oyun içinde küçült (0.25 katı)
	scale = Vector3(0.25, 0.25, 0.25)
	
	# Oyuncuyu bulmayı tekrar tekrar dene (Garanti yöntem)
	call_deferred("_oyuncuyu_bul")
	
	if anim_sprite:
		anim_sprite.play("default")

func _oyuncuyu_bul():
	var players = get_tree().get_nodes_in_group("Oyuncu")
	if players.size() > 0:
		oyuncu = players[0]
		print("🦇 Yarasa: Hedef kilitlendi -> ", oyuncu.name)
	else:
		print("🔴 Yarasa HATA: 'Oyuncu' grubunda kimse yok! Bekleniyor...")
		# 1 saniye sonra tekrar dene
		await get_tree().create_timer(1.0).timeout
		_oyuncuyu_bul()

func _physics_process(delta):
	# Ölüyorsa veya oyuncu yoksa hareket etme
	if oluyor or not oyuncu: 
		# Yerçekimi etkisi (Havada asılı kalmasınlar)
		velocity.y -= 9.8 * delta
		move_and_slide()
		return
	
	# --- HEDEF ---
	var hedef_pos = oyuncu.global_position
	hedef_pos.y += 0.8 # Göğüs hizasına nişan al
	
	# --- HAREKET (SÜZÜLME) ---
	var yon = (hedef_pos - global_position).normalized()
	velocity = yon * hiz
	
	# Yüzünü oyuncuya dön
	look_at(Vector3(oyuncu.global_position.x, global_position.y, oyuncu.global_position.z))
	
	move_and_slide()
	
	# --- SANA HASAR VERME ---
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Sadece oyuncuya çarpınca ve daha önce vurmadıysa
		if collider.is_in_group("Oyuncu") and not hasar_verdi_mi:
			_oyuncuya_vur(collider)

func _oyuncuya_vur(oyuncu_ref):
	hasar_verdi_mi = true
	print("🩸 YARASA TEMAS ETTİ! Hasar veriliyor...")
	
	if oyuncu_ref.has_method("hasar_al"):
		oyuncu_ref.hasar_al(20) # 2 Bar Hasar
	
	# Vurduktan sonra yok ol
	queue_free()

# --- MERMİDEN HASAR ALMA ---
# Bu fonksiyon Mermi.gd tarafından çağrılır
func hasar_al_efekt():
	print("🔫 YARASA VURULDU! Can: ", saglik)
	if oluyor: return
	
	saglik -= 10
	
	# Kızarma Efekti
	if anim_sprite:
		anim_sprite.modulate = Color(10, 0, 0) # Parlak kırmızı
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.1)
	
	if saglik <= 0:
		olum_animasyonu()

func olum_animasyonu():
	oluyor = true
	print("💀 YARASA ÖLÜYOR...")
	
	# Artık mermi çarpmasın
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.set_parallel(true)
	# Yere düş
	tween.tween_property(self, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Küçül
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
	# Şeffaflaş
	if anim_sprite:
		tween.tween_property(anim_sprite, "modulate:a", 0.0, 0.4)
	
	await tween.finished
	queue_free()
