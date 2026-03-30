extends Node

class_name PlayerInteractor

@export var raycast: RayCast3D
@export var hold_point: Node3D
@export var interaction_label: Label

var held_object: RigidBody3D = null
var mouse_free_mode: bool = false
var _last_mermi_kutusu: Node3D = null

func _physics_process(delta: float):
	if held_object and hold_point:
		var target_pos = hold_point.global_position
		var object_pos = held_object.global_position
		var dir = (target_pos - object_pos) * 15.0
		held_object.linear_velocity = dir
		held_object.angular_velocity = Vector3.ZERO

func check_interaction():
	if not raycast or not raycast.is_colliding():
		if interaction_label: interaction_label.text = ""
		# Bakış çekildiğinde mermi kutusu UI'larını gizle (Sky/Void look-away)
		if _last_mermi_kutusu:
			_mermi_kutusu_ui_kapat_hepsi()
			_last_mermi_kutusu = null
		return
		
	var collider = raycast.get_collider()
	if not collider:
		if interaction_label: interaction_label.text = ""
		if _last_mermi_kutusu:
			_mermi_kutusu_ui_kapat_hepsi()
			_last_mermi_kutusu = null
		return

	# DEBUG: Hit node and groups
	# print("RayCast Hit: ", collider.name, " Groups: ", collider.get_groups())

	# TODO: Expand interaction logic based on groups or classes
	var is_mermi_kutusu = collider.is_in_group("MermiKutusu")
	var mermi_kutusu_node = collider
	
	if not is_mermi_kutusu and collider.get_parent() and collider.get_parent().is_in_group("MermiKutusu"):
		is_mermi_kutusu = true
		mermi_kutusu_node = collider.get_parent()

	if collider.is_in_group("Etkilesim") or is_mermi_kutusu:
		# Mermi Kutusu Özel Durumu: UI Göster
		if is_mermi_kutusu:
			if _last_mermi_kutusu != mermi_kutusu_node:
				_mermi_kutusu_ui_kapat_hepsi()
				_mermi_kutusu_ui_guncelle(mermi_kutusu_node, true)
				_last_mermi_kutusu = mermi_kutusu_node
			
			if interaction_label: interaction_label.text = "[E] " + DilYoneticisi.metin_al("shotgun_mermi_isi") if DilYoneticisi else "[E] Mermi Al"
			return
		
		# Etkileşimli nesneye geçildiyse mermi kutusu UI'ını kapat
		if _last_mermi_kutusu:
			_mermi_kutusu_ui_kapat_hepsi()
			_last_mermi_kutusu = null
		var aday = collider
		var devre_disi = false
		var limit = 3
		while aday and limit > 0:
			if aday.get("e_etkilesimi_devre_disi") == true:
				devre_disi = true
				break
			if "mezar" in aday.name.to_lower():
				devre_disi = true
				break
			aday = aday.get_parent()
			limit -= 1
		
		# Sahne ismi kontrolü
		if not devre_disi and get_tree().current_scene:
			if "mezar" in get_tree().current_scene.name.to_lower():
				devre_disi = true
			
		if devre_disi:
			if interaction_label: interaction_label.text = ""
			return
		var custom_text = collider.get("interaction_text")
		if not custom_text and collider.get_parent():
			custom_text = collider.get_parent().get("interaction_text")
			
		if custom_text:
			if interaction_label: interaction_label.text = (DilYoneticisi.metin_al(custom_text) if DilYoneticisi else custom_text)
		else:
			if interaction_label: interaction_label.text = "[E] Etkileşim"
	else:
		if interaction_label: interaction_label.text = ""
		# Bakış çekildiğinde mermi kutusu UI'larını gizle
		if _last_mermi_kutusu:
			_mermi_kutusu_ui_kapat_hepsi()
			_last_mermi_kutusu = null

func _mermi_kutusu_ui_guncelle(kutu: Node3D, durum: bool):
	var rev_info = kutu.get_node_or_null("RevolverInfo")
	var shot_info = kutu.get_node_or_null("ShotgunInfo")
	
	if rev_info and shot_info:
		rev_info.visible = durum
		shot_info.visible = durum
		
		if durum:
			var rev_lab = rev_info.get_node("Label3D")
			var shot_lab = shot_info.get_node("Label3D")
			if rev_lab: rev_lab.text = "x" + str(GameManager.mermi_sayisi)
			if shot_lab: shot_lab.text = "x" + str(GameManager.shotgun_mermi_count)

func _mermi_kutusu_ui_kapat_hepsi():
	for kutu in get_tree().get_nodes_in_group("MermiKutusu"):
		var rev_info = kutu.get_node_or_null("RevolverInfo")
		var shot_info = kutu.get_node_or_null("ShotgunInfo")
		if rev_info: rev_info.visible = false
		if shot_info: shot_info.visible = false
