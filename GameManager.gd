extends Node

# YENİ: Sinyal Tanımla
signal envanter_guncellendi 

var envanter = [] 
var max_totem_sayisi = 5

func totem_ekle(yeni_esya: ItemData) -> bool:
	if envanter.size() >= max_totem_sayisi:
		return false
	
	envanter.append(yeni_esya)
	print("Envantere eklendi. Toplam: " + str(envanter.size()))
	
	# YENİ: Sinyali Ateşle! (Bütün oyuna haber ver)
	envanter_guncellendi.emit() 
	
	return true

# (Diğer fonksiyonlar aynen kalsın)
