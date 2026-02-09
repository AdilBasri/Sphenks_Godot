extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi
signal satir_patladi       
signal boss_oldu           
signal saglik_guncellendi(bar, hp) 
signal altin_guncellendi(miktar)   
signal mermi_degisti(yeni_sayi) # Pyro modu için

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
var zar_atlama_hakki: int = 0
var zar_yok_sayma: bool = false
var pyro_yavaslatma: bool = false
var yarasa_bonusu: bool = false
var mantar_modu: bool = false

# --- 🔥 PYRO MODU & SİLAH SİSTEMİ DEĞİŞKENLERİ 🔥 ---
var pyro_aktif: bool = false
var mermi_sayisi: int = 10
var max_mermi: int = 40
var silah_cekildi: bool = false # Silah elimizde mi? (Trafik Polisi)

func _ready():
	print("GameManager Başlatıldı.")
	verileri_sifirla()

func verileri_sifirla():
	# Temel Değerler
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	suanki_seviye = 1
	toplam_altin = 10
	
	# Pyro ve Silah Sıfırlama
	pyro_aktif = false
	mermi_sayisi = 10
	silah_cekildi = false # Başlangıçta silah gizli
	
	# Envanter ve Bufflar
	envanter.clear()
	bolum_bufflarini_sifirla()
	
	# Arayüzü Güncelle
	await get_tree().process_frame 
	
	emit_signal("saglik_guncellendi", oyuncu_kalan_bar, oyuncu_suanki_hp)
	emit_signal("envanter_guncellendi")
	emit_signal("altin_guncellendi", toplam_altin)
	emit_signal("mermi_degisti", mermi_sayisi)
	
	print("GameManager: Oyun sıfırlandı. Altın: 10")

func bolum_bufflarini_sifirla():
	puan_carpani = 1.0
	revive_aktif = false
	zar_atlama_hakki = 0
	zar_yok_sayma = false
	pyro_yavaslatma = false
	yarasa_bonusu = false
	mantar_modu = false

# --- ENVANTER VE ALTIN YÖNETİMİ ---
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
	oyuncu_kalan_bar = bar; oyuncu_suanki_hp = hp; emit_signal("saglik_guncellendi", bar, hp)

# --- 🔥 MERMİ YÖNETİMİ 🔥 ---
func mermi_ekle(miktar: int) -> bool:
	if mermi_sayisi >= max_mermi:
		return false # Zaten dolu, alınamaz
	
	mermi_sayisi = min(mermi_sayisi + miktar, max_mermi)
	emit_signal("mermi_degisti", mermi_sayisi)
	return true

func mermi_harca() -> bool:
	if mermi_sayisi > 0:
		mermi_sayisi -= 1
		emit_signal("mermi_degisti", mermi_sayisi)
		return true
	return false
