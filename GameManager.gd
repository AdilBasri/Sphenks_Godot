extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi # Blok konulunca
signal satir_patladi      # Satır silinince
signal boss_oldu          # YENİ: Boss ölünce (Zar atmayı kesmek için)

var envanter = [] 
var max_totem_sayisi = 5

func totem_ekle(yeni_esya: ItemData) -> bool:
	if envanter.size() >= max_totem_sayisi:
		return false
	
	envanter.append(yeni_esya)
	print("Envantere eklendi. Toplam: " + str(envanter.size()))
	envanter_guncellendi.emit() 
	return true
