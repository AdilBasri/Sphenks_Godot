extends Node3D

var tiklanma_sayisi = 0
@onready var main_script = get_tree().current_scene

# Bu fonksiyonu artık Oyuncu (Player) çağıracak
func etkilesim_baslat():
	if main_script and "etkilesim_aktif" in main_script:
		if main_script.etkilesim_aktif:
			tiklanma_sayisi += 1
			
			if tiklanma_sayisi == 1:
				# İlk tık: Titret
				main_script.yolcuya_tiklandi(self, false)
			elif tiklanma_sayisi >= 2:
				# İkinci tık: Yok et
				main_script.yolcuya_tiklandi(self, true)
