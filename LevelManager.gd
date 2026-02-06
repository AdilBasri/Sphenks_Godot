extends Node

# --- OYUN DURUMU ---
var suanki_katman: int = 1

# --- ZORLUK AYARLARI ---
# Her katta hedef puan ne kadar artacak?
var baz_hedef_puan: int = 300
var katman_basi_artis: int = 150

# Her katta blok sayısı değişecek mi? (Şimdilik sabit tutabiliriz veya azaltabiliriz)
var baz_blok_limiti: int = 12

func oyunu_baslat():
	suanki_katman = 1
	get_tree().change_scene_to_file("res://Scenes/OyunOdasi.tscn")

# Marketten çıkıp yeni bölüme geçerken bu çağrılacak
func sonraki_seviyeye_gec():
	suanki_katman += 1
	print(">>> YENİ KATMAN YÜKLENİYOR: " + str(suanki_katman))
	
	# Sahneyi yeniden yükle (OyunOdasi.tscn tekrar yüklenir ama veriler değişmiş olur)
	# call_deferred, sahne geçişlerinde çökme olmaması için işlemi sıraya koyar.
	call_deferred("_sahne_degistir", "res://Scenes/OyunOdasi.tscn")

func markete_git():
	print(">>> MARKET YÜKLENİYOR <<<")
	call_deferred("_sahne_degistir", "res://Scenes/Market.tscn") # Market sahnenin yolu

func campfire_git():
	print(">>> CAMPFIRE YÜKLENİYOR <<<")
	call_deferred("_sahne_degistir", "res://Scenes/Campfire.tscn") # Campfire sahnenin yolu

func _sahne_degistir(yol: String):
	get_tree().change_scene_to_file(yol)

# BlokDağıtıcısı bu fonksiyonu çağırıp zorluğu öğrenecek
func bolum_verilerini_getir() -> Dictionary:
	var yeni_hedef = baz_hedef_puan + ((suanki_katman - 1) * katman_basi_artis)
	
	return {
		"katman": suanki_katman,
		"hedef_puan": yeni_hedef,
		"blok_limiti": baz_blok_limiti
	}
