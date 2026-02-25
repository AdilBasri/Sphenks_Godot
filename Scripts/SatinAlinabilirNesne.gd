extends RigidBody3D

var esya_verisi: ItemData
var market_modu: bool = false 

# Bu fonksiyon Oyuncu.gd tarafından çağrılır
func etkilesime_gir():
	if not esya_verisi:
		print("HATA: Bu nesnenin verisi yok!")
		return
	
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu: return
	
	# Marketteysek satın al, değilse eline al
	if market_modu:
		if oyuncu.has_method("satin_al"):
			oyuncu.satin_al(self)
	else:
		if oyuncu.has_method("esyayi_ele_al"):
			oyuncu.esyayi_ele_al(self)
