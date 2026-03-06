extends Node

# FinalOdaYoneticisi.gd
# final_oda.tscn içindeki oyun akışını yönetir.
# Oyuncu ölünce oyun_sonu ekranını getirir.

var olum_ekrani = preload("res://Scenes/oyun_sonu.tscn")

func _ready() -> void:
	# Biraz bekle ki tüm node'lar hazır olsun
	await get_tree().process_frame
	
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and oyuncu.has_signal("oyuncu_oldu"):
		if not oyuncu.oyuncu_oldu.is_connected(_on_oyuncu_oldu):
			oyuncu.oyuncu_oldu.connect(_on_oyuncu_oldu)
		print("FinalOdaYoneticisi: Oyuncu sinyali bağlandı.")
	else:
		push_warning("FinalOdaYoneticisi: Oyuncu grubu veya sinyali bulunamadı!")

func _on_oyuncu_oldu() -> void:
	print("💀 Final Oda: Oyuncu öldü — oyun sonu ekranı açılıyor.")
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(self):
		var ekran = olum_ekrani.instantiate()
		get_tree().current_scene.add_child(ekran)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
