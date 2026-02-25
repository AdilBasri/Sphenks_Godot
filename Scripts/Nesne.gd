extends RigidBody3D

var esya_verisi: ItemData
var market_modu: bool = false 

func etkilesime_gir():
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if not oyuncu: return
	
	if market_modu:
		if oyuncu.has_method("satin_al"):
			oyuncu.satin_al(self)
	else:
		if oyuncu.has_method("esyayi_ele_al"):
			oyuncu.esyayi_ele_al(self)
