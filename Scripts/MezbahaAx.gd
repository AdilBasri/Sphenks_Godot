extends Node

@export var kilitli_mi: bool = false
@export var etkilesim_yazisi: String = "[E] Baltayı Al"
var asilabilir_mi: bool = false

func _ready():
	# Sprite3D'nin çocuğu olduğumuzda parent artık CollisionObject3D değil
	# Bu yüzden collision_layer'ı doğrudan self (StaticBody3D) üzerinde setliyoruz
	self.collision_layer = 1 # Raycast'in bizi bulabilmesi için Layer 1'de olmalıyız

func get_etkilesim_yazisi() -> String:
	# Mesafe kontrolü
	var p = get_tree().get_first_node_in_group("Oyuncu")
	if p and p.global_position.distance_to(get_parent().global_position) > 3:
		return ""
		
	if asilabilir_mi:
		return "[E] Baltayı Yerine As"
		
	if kilitli_mi:
		return ""
		
	return etkilesim_yazisi

func interact(oyuncu: Node):
	if kilitli_mi and not asilabilir_mi: return
	
	if oyuncu and oyuncu.global_position.distance_to(get_parent().global_position) > 3:
		return
	
	# Sadece E ile alınması için (sol tıkı engelliyoruz)
	if Input.is_action_just_pressed("sol_tik") or Input.is_action_pressed("sol_tik"):
		return
	
	var manager = get_tree().current_scene.find_child("MezbahaManager", true, false)
	var parent_ax = get_parent()
	
	if asilabilir_mi:
		if manager:
			manager.axe_returned()
		asilabilir_mi = false
		kilitli_mi = true
		self.collision_layer = 0 # Bir daha hedef alınamasın
		if parent_ax:
			parent_ax.show()
		return

	if manager:
		manager.axe_picked_up()
		
	kilitli_mi = true
	self.collision_layer = 0 # Görünmezken etkileşime girilmesin

	# Hide the physical axe
	if parent_ax:
		parent_ax.hide()
