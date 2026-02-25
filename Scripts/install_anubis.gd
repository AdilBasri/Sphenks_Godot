@tool
extends EditorScript

# install_anubis.gd
# Bu script Anubis (Meshy_AI...) noduna Area3D, Camera3D ve etkileşim Scriptini otomatik ekler.

func _run():
	var scene = get_editor_interface().get_edited_scene_root()
	if not scene:
		print("HATA: yenisahne.tscn dosyasını açıp Editor'de görüntülediğinizden emin olun!")
		return
		
	print("--- Anubis Sinematiği Kurulumu Başladı ---")
	
	# Anubisi bul
	var anubis = _sahneyi_tara_ve_bul(scene, "Meshy_AI_Meshy_Merged_Animations")
	
	if not anubis:
		print("HATA: Sahnede 'Meshy_AI_Meshy_Merged_Animations' bulunamadı!")
		return
		
	print("Anubis bulundu! Kurulum yapılıyor...")
	
	var mevcut_area = anubis.get_node_or_null("AnubisEtkilesim")
	if mevcut_area:
		print("UYARI: Zaten bir Etkileşim Alanı bulunuyor. Öncekini siliyorum...")
		anubis.remove_child(mevcut_area)
		mevcut_area.free()
		
	var mevcut_yazi = anubis.get_node_or_null("EtkilesimYazisi")
	if mevcut_yazi:
		anubis.remove_child(mevcut_yazi)
		mevcut_yazi.free()
		
	var mevcut_kamera = anubis.get_node_or_null("SinematikKamera")
	if mevcut_kamera:
		anubis.remove_child(mevcut_kamera)
		mevcut_kamera.free()
		
	# 1. Etkileşim StaticBody3D'sini ve scriptini ekle
	var area = StaticBody3D.new()
	area.name = "AnubisEtkilesim"
	# Collision Layer 1 ve Mask 1 oyuncunun Raycast'inin çarpması için gerekliyse bunu açabilirsiniz.
	# OyuncuBus raycast maskesi 6 ise ona göre de ayarlayabilirsiniz, genelde 1 veya 2'dir.
	area.collision_layer = 1
	area.collision_mask = 1
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(5, 5, 5) # Raycast'in rahatça çarpması için Büyük Kutu
	col.shape = box
	# Kafasının hizasına al
	col.position = Vector3(0, 1.5, 0)
	area.add_child(col)
	
	# Script bağla
	var script_res = load("res://Scripts/anubis_dialog.gd")
	if script_res:
		area.set_script(script_res)
	else:
		print("HATA: res://Scripts/anubis_dialog.gd bulunamadı!")
	
	anubis.add_child(area)
	
	area.owner = scene
	col.owner = scene
	
	# 2. Üzerine bir "[E] Konuş" Label3D Ekle
	var label = Label3D.new()
	label.name = "EtkilesimYazisi"
	label.text = "[E] Konus"
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.5, 0) # Kafasının üstüne
	label.font_size = 64
	label.outline_size = 8
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	anubis.add_child(label)
	label.owner = scene
	
	# 3. Sinematik Kamerayı Ayarla
	var kamera = Camera3D.new()
	kamera.name = "SinematikKamera"
	# Anubise çaprazdan ve aşağıdan yukarı (veya uygun bir açı) bakacak şekilde.
	# Anubis'in pozisyonuna göre offset verelim
	anubis.add_child(kamera)
	kamera.owner = scene
	
	kamera.position = Vector3(-1.5, 2.0, 2.0)
	
	kamera.current = false # Godot bunu varsayılan yapmaya çalışmasın!
	
	# Node scene tree'ye girdikten sonra look_at çalıştırılır.
	var global_kafa_pos = anubis.global_transform.origin + Vector3(0, 2.5, 0)
	kamera.look_at(global_kafa_pos, Vector3.UP)
	
	print("--- KURULUM TAMAMLANDI: Lütfen Ctrl+S ile sahneyi kaydedin! ---")

func _sahneyi_tara_ve_bul(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var res = _sahneyi_tara_ve_bul(child, target_name)
		if res: return res
	return null
