extends RigidBody3D

var esya_verisi: ItemData # Hangi eşya olduğunu tutar
var market_modu: bool = false # True ise satın alınır, False ise direkt yerden alınır

func etkilesime_gir():
	if not esya_verisi: return
	
	if market_modu:
		# MARKETTEYİZ: Satın alma işlemini başlat
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu and oyuncu.has_method("satin_al"):
			oyuncu.satin_al(self) # Kendimizi gönderiyoruz ki fiyatına baksın
	else:
		# OYUN ODASINDAYIZ (veya satın alındıktan sonrası): Direkt ele al
		var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
		if oyuncu and oyuncu.has_method("esyayi_ele_al"):
			oyuncu.esyayi_ele_al(self)
