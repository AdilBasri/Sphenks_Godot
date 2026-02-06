extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi
signal satir_patladi      
signal boss_oldu          

# --- KALICI VERİLER ---
var envanter: Array[ItemData] = [] 
var max_totem_sayisi = 5

# Oyuncu Sağlığı (Kalıcı)
var oyuncu_max_bar: int = 4
var oyuncu_kalan_bar: int = 4
var oyuncu_suanki_hp: int = 10

func _ready():
	verileri_sifirla()

func verileri_sifirla():
	envanter.clear()
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	print("GameManager: Tüm veriler sıfırlandı.")

func totem_ekle(yeni_esya: ItemData) -> bool:
	if envanter.size() >= max_totem_sayisi:
		return false
	
	envanter.append(yeni_esya)
	print("Envantere eklendi. Toplam: " + str(envanter.size()))
	envanter_guncellendi.emit() 
	return true

# Oyuncu hasar aldığında burayı güncelleyecek
func saglik_guncelle(bar: int, hp: int):
	oyuncu_kalan_bar = bar
	oyuncu_suanki_hp = hp
