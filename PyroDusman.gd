extends CharacterBody3D

@export var hiz: float = 2.0 
@export var saglik: int = 20

@onready var anim_sprite = $AnimatedSprite3D
@onready var hitbox = $Hitbox 

var oyuncu: Node3D = null
var hasar_verdi_mi: bool = false 
var saldiri_aktif: bool = false # Başlangıçta SALDIRAMAZ

func _ready():
	add_to_group("Dusman")
	
	# Görünmezlik efektini İPTAL ETTİM.
	# Direkt görünür olsunlar ki nerede olduklarını görelim.
	if anim_sprite:
		anim_sprite.modulate.a = 1.0 
	
	oyuncuyu_bul()
	
	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Saldırı yine kilitli başlasın (Spawn Kill koruması)
	await get_tree().create_timer(2.0).timeout
	saldiri_aktif = true
	
	# Saldırı açılınca kırmızılaşsın
	if anim_sprite:
		anim_sprite.modulate = Color(1, 0.5, 0.5)

func oyuncuyu_bul():
	var players = get_tree().get_nodes_in_group("Oyuncu")
	if players.size() > 0:
		oyuncu = players[0]
	else:
		oyuncu = get_tree().current_scene.find_child("CharacterBody3D", true, false)

func _physics_process(delta):
	if not oyuncu: return

	look_at(Vector3(oyuncu.global_position.x, global_position.y, oyuncu.global_position.z))

	# Saldırı aktif değilse çok yavaş süzülsün (korku efekti)
	var anlik_hiz = hiz
	if not saldiri_aktif:
		anlik_hiz = hiz * 0.2 # Çok yavaş
	
	var hedef_pos = oyuncu.global_position
	hedef_pos.y += 0.8 
	var yon = (hedef_pos - global_position).normalized()
	velocity = yon * anlik_hiz
	
	move_and_slide()

# --- ISIRMA (ARTIK KORUMALI) ---
func _on_hitbox_body_entered(body):
	# Eğer henüz saldırı moduna geçmediyse İŞLEM YAPMA
	if not saldiri_aktif: 
		return 

	if body.is_in_group("Oyuncu"):
		print("🩸 YARASA ISIRDI!")
		if body.has_method("hasar_al"):
			body.hasar_al(20)
		queue_free()

func hasar_al_efekt():
	# Vurulmak her zaman serbest!
	saglik -= 10
	if anim_sprite:
		anim_sprite.modulate = Color(10, 0, 0)
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.1)
	
	if saglik <= 0:
		queue_free()
