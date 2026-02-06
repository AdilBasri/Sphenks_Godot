extends Node

# --- OYUN DURUMU ---
# HATA ÇÖZÜMÜ: Bu değişken en tepede olmalı
var suanki_katman: int = 1

# --- KONUM REFERANSLARI ---
var market_pos: Vector3
var campfire_pos: Vector3
var start_pos: Vector3
var oyuncu_ref: CharacterBody3D

# Oyun ilk açıldığında
func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

# OyunOdasi.gd _ready() fonksiyonunda burayı çağırıyor.
func konumlari_kaydet(p1: Vector3, p2: Vector3, p3: Vector3, oyuncu: CharacterBody3D):
	market_pos = p1
	campfire_pos = p2
	start_pos = p3
	oyuncu_ref = oyuncu
	
	# Eğer oyun reload edildiyse (Katman > 1), oyuncuyu başlangıç noktasına taşı
	if suanki_katman > 1 and oyuncu_ref:
		oyuncu_ref.global_position = start_pos

# Bölüm bitti, her şey sıfırlanıp zorluk artacak
func odaya_don_ve_level_atla():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz and arayuz.has_method("perde_kapat"):
		await arayuz.perde_kapat(1.0)
		
	call_deferred("_sahne_yenile")

func _sahne_yenile():
	get_tree().reload_current_scene()

# BlokDağıtıcısı bu fonksiyonu çağırıp zorluğu öğrenecek
func bolum_verilerini_getir() -> Dictionary:
	var veri = {}
	
	# ZORLUK AYARLARI
	match suanki_katman:
		1:
			veri["hedef_puan"] = 300
			veri["blok_limiti"] = 12
			veri["boss_resmi"] = "res://blob.png"
		2:
			# İsteğin üzerine 540 yapıldı
			veri["hedef_puan"] = 540 
			veri["blok_limiti"] = 15
			veri["boss_resmi"] = "res://hammer.png"
		_:
			# 3. Seviye ve sonrası
			veri["hedef_puan"] = 540 + ((suanki_katman - 2) * 200)
			veri["blok_limiti"] = 15 + (suanki_katman - 2)
			veri["boss_resmi"] = "res://hammer.png"
	
	veri["katman"] = suanki_katman
	return veri
