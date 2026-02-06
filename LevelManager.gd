extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1
var baz_hedef_puan: int = 300
var katman_basi_artis: int = 150
var baz_blok_limiti: int = 12

# Oyun ilk açıldığında veya menüden basılınca
func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

# Bölüm bitti, her şey sıfırlanıp zorluk artacak
func odaya_don_ve_level_atla():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	# Sahneyi tamamen yenile (Reset atar ve oyuncuyu spawn noktasına koyar)
	# call_deferred, çökme olmaması için güvenli yoldur.
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
