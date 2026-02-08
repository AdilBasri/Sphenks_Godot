extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi
signal satir_patladi      
signal boss_oldu          
signal saglik_guncellendi(bar, hp) 
signal altin_guncellendi(miktar)   

# --- OYUNCU SAĞLIK VERİLERİ ---
var oyuncu_max_bar: int = 4
var oyuncu_kalan_bar: int = 4
var oyuncu_suanki_hp: int = 10

# --- EKONOMİ ---
var toplam_altin: int = 0 

# --- ENVANTER ---
var envanter: Array[ItemData] = []
var max_totem_sayisi = 5 

# --- BUFFLAR ---
var puan_carpani: float = 1.0
var revive_aktif: bool = false
var zar_atlama_hakki: int = 0
var zar_yok_sayma: bool = false
var pyro_yavaslatma: bool = false
var yarasa_bonusu: bool = false
var mantar_modu: bool = false

func _ready():
	# Oyun ilk açıldığında
	print("GameManager Başlatıldı.")
	# Başlangıç altını (İstersen 0 yapabilirsin)
	altin_ekle(50)

# --- KRİTİK: SIFIRLAMA FONKSİYONLARI ---
func verileri_sifirla():
	# 1. Canı Fulle
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	
	# 2. Envanter ve Buffları Temizle
	envanter.clear()
	bolum_bufflarini_sifirla()
	
	# 3. Sinyalleri Gönder (Arayüz ve Oyuncu haberdar olsun)
	emit_signal("saglik_guncellendi", oyuncu_kalan_bar, oyuncu_suanki_hp)
	emit_signal("envanter_guncellendi")
	
	print("GameManager: Oyun sıfırlandı. Can Fullendi (4 Bar, 10 HP).")

func bolum_bufflarini_sifirla():
	puan_carpani = 1.0
	revive_aktif = false
	zar_atlama_hakki = 0
	zar_yok_sayma = false
	pyro_yavaslatma = false
	yarasa_bonusu = false
	mantar_modu = false

# --- ENVANTER YÖNETİMİ ---
func totem_ekle(yeni_esya: ItemData) -> bool:
	if envanter.size() >= max_totem_sayisi:
		return false
	
	envanter.append(yeni_esya)
	print("Envantere eklendi: " + yeni_esya.esya_adi)
	emit_signal("envanter_guncellendi") 
	return true

func esya_sil(veri: ItemData):
	if veri in envanter:
		envanter.erase(veri)
		emit_signal("envanter_guncellendi")

# --- ALTIN SİSTEMİ ---
func altin_ekle(miktar: int):
	toplam_altin += miktar
	emit_signal("altin_guncellendi", toplam_altin)
	print("💰 Altın: ", toplam_altin)

func altin_harca(miktar: int) -> bool:
	if toplam_altin >= miktar:
		toplam_altin -= miktar
		emit_signal("altin_guncellendi", toplam_altin)
		return true
	return false

# --- SAĞLIK YÖNETİMİ ---
func saglik_guncelle(bar: int, hp: int):
	oyuncu_kalan_bar = bar
	oyuncu_suanki_hp = hp
	emit_signal("saglik_guncellendi", bar, hp)
