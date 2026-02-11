extends StaticBody3D

enum Tur {MUSLUK, BLENDER, ESYA, BILET}
@export var nesne_turu : Tur = Tur.ESYA
@export var esya_ismi : String = "Eşya"

@onready var main_script = get_tree().current_scene
# Güvenli Erişim: Sadece Musluksa ara
@onready var benim_suyum = get_node_or_null("SuPartikulleri")

var su_acik = false

func etkilesim_baslat():
	print("Tıklanan Nesne: ", name, " | Türü: ", nesne_turu) # DEBUG SATIRI
	
	match nesne_turu:
		Tur.MUSLUK:
			if benim_suyum:
				su_acik = !su_acik
				benim_suyum.emitting = su_acik
				print("-> Su durumu değişti: ", su_acik)
			else:
				print("-> HATA: 'SuPartikulleri' düğümü bulunamadı! İçimdeki düğümler:")
				print_tree_pretty() # Ağacı yazdırır, hatayı görürüz.

		Tur.BLENDER:
			print("-> Blender'a sinyal gönderiliyor...")
			if main_script.has_method("blenderi_calistir"):
				main_script.blenderi_calistir()

		Tur.ESYA:
			print("-> Eşya toplandı: ", esya_ismi)
			if main_script.has_method("malzeme_topla"):
				main_script.malzeme_topla(esya_ismi)
				queue_free()

		Tur.BILET:
			# Ana sahnedeki fonksiyona 'self' (kendimi) gönderiyorum
			if main_script.has_method("bilet_alindi_final"):
				main_script.bilet_alindi_final(self) # <-- 'self' ekledik
				# queue_free() SİLDİK! Çünkü nesneyi yok etmiyoruz, eline alıyor.
