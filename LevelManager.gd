extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1
var baz_hedef_puan: int = 300
var katman_basi_artis: int = 150
var baz_blok_limiti: int = 12

# --- KONUM REFERANSLARI ---
var market_pos: Vector3
var campfire_pos: Vector3
var start_pos: Vector3
var oyuncu_ref: CharacterBody3D

# Oyun ilk açıldığında
func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

# --- HATA VEREN FONKSİYON EKLENDİ ---
# OyunOdasi.gd _ready() fonksiyonunda burayı çağırıyor.
func konumlari_kaydet(p1: Vector3, p2: Vector3, p3: Vector3, oyuncu: CharacterBody3D):
	market_pos = p1
	campfire_pos = p2
	start_pos = p3
	oyuncu_ref = oyuncu
	print("LevelManager: Konumlar başarıyla kaydedildi.")
	
	# Eğer oyun reload edildiyse (Katman > 1), oyuncuyu başlangıç noktasına emin olmak için taşıyalım
	if suanki_katman > 1 and oyuncu_ref:
		oyuncu_ref.global_position = start_pos

# Bölüm bitti, her şey sıfırlanıp zorluk artacak
func odaya_don_ve_level_atla():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	# Sahneyi tamamen yenile
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz:
		await arayuz.perde_kapat(1.0)
		
	call_deferred("_sahne_yenile")

func _sahne_yenile():
	get_tree().reload_current_scene()

# BlokDağıtıcısı bu fonksiyonu çağırıp zorluğu öğrenecek
func bolum_verilerini_getir() -> Dictionary:
	var yeni_hedef = baz_hedef_puan + ((suanki_katman - 1) * katman_basi_artis)
	
	return {
		"katman": suanki_katman,
		"hedef_puan": yeni_hedef,
		"blok_limiti": baz_blok_limiti
	}
