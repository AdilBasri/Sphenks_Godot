extends Node3D

@onready var yan_sehpa = $YanSehpa # Sahneye koyduğun sehpa düğümü

func _ready():
	# Sahne açılır açılmaz:
	# "GameManager, çantada ne varsa ver, sehpaya dizeyim."
	if yan_sehpa:
		yan_sehpa.envanteri_yukle(GameManager.envanter)
	else:
		print("HATA: YanSehpa düğümü Oyun Odasında bulunamadı!")
