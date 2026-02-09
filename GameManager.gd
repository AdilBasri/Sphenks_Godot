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

# --- OYUN İLERLEMESİ ---
var suanki_seviye: int = 1 
var toplam_altin: int = 10 

# --- ENVANTER ---
var envanter: Array[ItemData] = []
var max_totem_sayisi = 5 

# --- BUFFLAR ---
var puan_carpani: float = 1.0
var revive_aktif: bool = false
var zar_atlama_hakki: int = 0  # Pelerin hakkı burada tutuluyor
var zar_yok_sayma: bool = false
var pyro_yavaslatma: bool = false
var yarasa_bonusu: bool = false
var mantar_modu: bool = false

func _ready():
	print("GameManager Başlatıldı.")
	verileri_sifirla()

func verileri_sifirla():
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	suanki_seviye = 1
	toplam_altin = 10
	
	envanter.clear()
	bolum_bufflarini_sifirla()
	
	# Pelerin hakkını da sıfırla
	zar_atlama_hakki = 0
	
	await get_tree().process_frame 
	emit_signal("saglik_guncellendi", oyuncu_kalan_bar, oyuncu_suanki_hp)
	emit_signal("envanter_guncellendi")
	emit_signal("altin_guncellendi", toplam_altin)

func bolum_bufflarini_sifirla():
	puan_carpani = 1.0
	revive_aktif = false
	zar_yok_sayma = false
	pyro_yavaslatma = false
	yarasa_bonusu = false
	mantar_modu = false
	# NOT: Pelerin hakkını burada sıfırlamıyoruz, çünkü pelerin kalıcı olabilir.
	# Eğer her bölüm pelerin silinsin istiyorsan buraya 'zar_atlama_hakki = 0' ekle.

# --- ENVANTER SİSTEMİ ---
func totem_ekle(yeni_esya: ItemData) -> bool:
	if envanter.size() >= max_totem_sayisi: return false
	envanter.append(yeni_esya); emit_signal("envanter_guncellendi"); return true

func esya_sil(veri: ItemData):
	if veri in envanter: envanter.erase(veri); emit_signal("envanter_guncellendi")

func altin_ekle(miktar: int):
	toplam_altin += miktar; emit_signal("altin_guncellendi", toplam_altin)

func altin_harca(miktar: int) -> bool:
	if toplam_altin >= miktar: toplam_altin -= miktar; emit_signal("altin_guncellendi", toplam_altin); return true
	return false

func saglik_guncelle(bar: int, hp: int):
	oyuncu_kalan_bar = bar; oyuncu_suanki_hp = hp;
	emit_signal("saglik_guncellendi", bar, hp)

# --- PELERİN (CLOAK) SİSTEMİ ---
func pelerin_aktif_et():
	zar_atlama_hakki = 3
	emit_signal("envanter_guncellendi")
	print("👻 GameManager: Pelerin aktif! 3 tur koruma başladı.")

func pelerin_korumasi_var_mi() -> bool:
	return zar_atlama_hakki > 0

func pelerin_hak_dus():
	if zar_atlama_hakki > 0:
		zar_atlama_hakki -= 1
		print("🛡️ Pelerin hasarı engelledi. Kalan hak: ", zar_atlama_hakki)
