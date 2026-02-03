extends Node

# OYUNCUNUN CEBİNDEKİLER
var envanter = [] # Satın alınan totemlerin listesi (ItemData'ları tutacak)
var max_totem_sayisi = 5

# Bir eşya eklemeye çalışır.
# Başarılı olursa 'true', yer yoksa 'false' döndürür.
func totem_ekle(yeni_esya: ItemData) -> bool:
	if envanter.size() >= max_totem_sayisi:
		return false # Çanta dolu!
	
	envanter.append(yeni_esya)
	print("Envantere eklendi: " + yeni_esya.esya_adi + " | Toplam: " + str(envanter.size()))
	return true

# Oyun odasına geçince bu listeyi boşaltmak gerekebilir veya kullanıldıkça silinir.
func totem_kullan(index: int):
	if index < envanter.size():
		envanter.remove_at(index)
