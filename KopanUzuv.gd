extends RigidBody3D

var kan_havuzu_sahnesi = preload("res://KanHavuzu.tscn")
var yere_degdi = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 2 # Çarpışmayı dinle
	
	# Çarpışma sinyalini bağla
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if yere_degdi: return
	
	# Yere (StaticBody) çarptıysa
	if body is StaticBody3D or body is CSGShape3D:
		yere_degdi = true
		freeze = true # Yere yapışsın, kaymasın (İsteğe bağlı)
		
		# Kan havuzu oluştur
		if kan_havuzu_sahnesi:
			var kan = kan_havuzu_sahnesi.instantiate()
			get_tree().current_scene.add_child(kan)
			kan.global_position = global_position
			kan.position.y += 0.05 # Zeminle çakışmasın diye hafif yukarı
			
			# Kanı rastgele çevir ki doğal dursun
			kan.rotation.y = randf() * PI 

# Yok olma (queue_free) KODU YOK! Sonsuza kadar yerde kalacak.
