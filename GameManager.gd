extends Node

# --- SİNYALLER (HEPSİ BURADA) ---
signal envanter_guncellendi 
signal blok_yerlestirildi # BlokSurukle.gd arıyor
signal satir_patladi      # GridYonetici.gd arıyor
signal boss_oldu          # LevelManager veya Düşmanlar arıyor
signal saglik_guncellendi(bar, hp) # Oyuncu.gd arıyor
signal altin_guncellendi(miktar)   # Arayüz arıyor

# --- OYUNCU SAĞLIK VERİLERİ ---
var oyuncu_max_bar: int = 4
var oyuncu_kalan_bar: int = 4
var oyuncu_suanki_hp: int = 10

# --- EKONOMİ ---
var toplam_altin: int = 0 

# --- ENVANTER ---
var envanter: Array[ItemData] = []
var max_totem_sayisi = 5 # Senin ayarın (5 Slot)

# --- BUFFLAR / PASİF ETKİLER ---
var puan_carpani: float = 1.0
var revive_aktif: bool = false
var zar_atlama_hakki: int = 0
var zar_yok_sayma: bool = false
var pyro_yavaslatma: bool = false
var yarasa_bonusu: bool = false
var mantar_modu: bool = false

func _ready():
	# Başlangıçta test için biraz altın verelim
	altin_ekle(50)
	print("GameManager Hazır.")

# --- SIFIRLAMA FONKSİYONLARI ---
func verileri_sifirla():
	envanter.clear()
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	bolum_bufflarini_sifirla()
	print("GameManager: Tüm veriler sıfırlandı.")

func bolum_bufflarini_sifirla():
	puan_carpani = 1.0
	revive_aktif = false
	zar_atlama_hakki = 0
	zar_yok_sayma = false
	pyro_yavaslatma = false
	yarasa_bonusu = false
	mantar_modu = false

# --- ENVANTER YÖNETİMİ ---
# Not: Senin kodunda 'totem_ekle' olarak geçiyor, onu koruduk.
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
