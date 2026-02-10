extends StaticBody3D

# YENİ TÜR: BILET EKLENDİ
enum Tur {MUSLUK, BLENDER, ESYA, BILET}
@export var nesne_turu : Tur = Tur.ESYA
@export var esya_ismi : String = "Eşya"

# Ana sahneye erişim
@onready var main_script = get_tree().current_scene

# Musluklar için kendi içindeki suyu bul
@onready var benim_suyum = $SuPartikulleri if has_node("SuPartikulleri") else null
var su_acik = false

func etkilesim_baslat():
	match nesne_turu:
		Tur.MUSLUK:
			# ANA SAHNEYE GİTMEDEN KENDİ İŞİMİ HALLEDİYORUM
			if benim_suyum:
				su_acik = !su_acik
				benim_suyum.emitting = su_acik
				# İstersen ses de çaldırabilirsin
			else:
				print("HATA: Bu musluğun içinde 'SuPartikulleri' yok!")

		Tur.BLENDER:
			if main_script.has_method("blenderi_calistir"):
				main_script.blenderi_calistir()

		Tur.ESYA:
			if main_script.has_method("malzeme_topla"):
				main_script.malzeme_topla(esya_ismi)
				queue_free() # Eşyayı yok et

		Tur.BILET:
			# Bilet yerden alındığında final başlar
			if main_script.has_method("bilet_alindi_final"):
				main_script.bilet_alindi_final()
				queue_free() # Bileti yok et (Cebe attı)
