extends Node

# --- SİNYALLER ---
signal envanter_guncellendi 
signal blok_yerlestirildi
signal satir_patladi        
signal boss_oldu            
signal saglik_guncellendi(bar, hp) 
signal altin_guncellendi(miktar)   
signal mermi_degisti(yeni_sayi)

# --- OYUNCU SAĞLIK VERİLERİ ---
var oyuncu_max_bar: int = 4
var oyuncu_kalan_bar: int = 4
var oyuncu_suanki_hp: int = 10

# --- OYUN İLERLEMESİ ---
var suanki_seviye: int = 1 
var kayitli_seviye: int = 1
var toplam_altin: int = 10 
var intro_tamamlandi: bool = false

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
var tek_zar_modu: bool = false
var fener_aktif: bool = false

# --- 🔥 PYRO MODU & SİLAH SİSTEMİ DEĞİŞKENLERİ ---
var pyro_aktif: bool = false
var mermi_sayisi: int = 10
var max_mermi: int = 40
var silah_cekildi: bool = false 

func _ready():
	print("GameManager Başlatıldı.")
	# Sadece intro durumunu yükle — oyun state'i her açılışta sıfır başlar
	_intro_durumu_yukle()

func verileri_sifirla():
	"""Tüm oyun verilerini başlangıç değerlerine sıfırlar."""
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	suanki_seviye = 1
	kayitli_seviye = 1
	toplam_altin = 10
	mermi_sayisi = 10
	pyro_aktif = false
	silah_cekildi = false 
	envanter.clear()
	bolum_bufflarini_sifirla()
	zar_atlama_hakki = 0
	_arayuz_guncelle()

func _arayuz_guncelle():
	await get_tree().process_frame 
	emit_signal("saglik_guncellendi", oyuncu_kalan_bar, oyuncu_suanki_hp)
	emit_signal("envanter_guncellendi")
	emit_signal("altin_guncellendi", toplam_altin)
	emit_signal("mermi_degisti", mermi_sayisi)

func bolum_bufflarini_sifirla():
	puan_carpani = 1.0
	revive_aktif = false
	zar_yok_sayma = false
	pyro_yavaslatma = false
	yarasa_bonusu = false
	mantar_modu = false
	zar_atlama_hakki = 0
	tek_zar_modu = false
	fener_aktif = false

func oyunu_kaydet():
	var config = ConfigFile.new()
	config.set_value("Oyun", "KayitliSeviye", suanki_seviye)
	config.set_value("Oyun", "Altin", toplam_altin)
	config.set_value("Oyuncu", "KalanBar", oyuncu_kalan_bar)
	config.set_value("Oyuncu", "SuankiHP", oyuncu_suanki_hp)
	config.set_value("Oyuncu", "MermiSayisi", mermi_sayisi)
	config.set_value("Oyuncu", "PyroAktif", pyro_aktif)
	
	config.set_value("Bufflar", "PuanCarpani", puan_carpani)
	config.set_value("Bufflar", "ReviveAktif", revive_aktif)
	config.set_value("Bufflar", "FenerAktif", fener_aktif)
	config.set_value("Bufflar", "ZamanYavas", pyro_yavaslatma)
	
	var esya_yollari = []
	for esya in envanter:
		if esya != null: esya_yollari.append(esya.resource_path)
	config.set_value("Oyun", "Envanter", esya_yollari)
	config.set_value("Oyun", "IntroTamamlandi", intro_tamamlandi)
	config.save("user://savegame.cfg")
	print("💾 Oyun kaydedildi.")

func oyunu_yukle():
	"""Kedi maması verildiğinde kaydedilen TÜM verileri yükler.
	Sadece ana_menu 'Devam Et' mantığında çağrılır."""
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	if hata == OK:
		kayitli_seviye = config.get_value("Oyun", "KayitliSeviye", 1)
		toplam_altin = config.get_value("Oyun", "Altin", 10)
		oyuncu_kalan_bar = config.get_value("Oyuncu", "KalanBar", 4)
		oyuncu_suanki_hp = config.get_value("Oyuncu", "SuankiHP", 10)
		mermi_sayisi = config.get_value("Oyuncu", "MermiSayisi", 10)
		pyro_aktif = config.get_value("Oyuncu", "PyroAktif", false)
		
		puan_carpani = config.get_value("Bufflar", "PuanCarpani", 1.0)
		revive_aktif = config.get_value("Bufflar", "ReviveAktif", false)
		fener_aktif = config.get_value("Bufflar", "FenerAktif", false)
		pyro_yavaslatma = config.get_value("Bufflar", "ZamanYavas", false)
		
		envanter.clear()
		var esya_yollari = config.get_value("Oyun", "Envanter", [])
		for yol in esya_yollari:
			if ResourceLoader.exists(yol):
				envanter.append(load(yol))

		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)

		# Corrupt save fix: HP sıfırsa tam sağlığa döndür
		if oyuncu_kalan_bar <= 0 or oyuncu_suanki_hp <= 0:
			print("⚠️ Yükleme: Corrupt HP tespit edildi, tam sağlığa sıfırlanıyor.")
			oyuncu_kalan_bar = oyuncu_max_bar
			oyuncu_suanki_hp = 10
	else:
		kayitli_seviye = 1


func _intro_durumu_yukle():
	"""Sadece intro tamamlandı mı bilgisini yükler.
	Oyun state'i (HP, altın, envanter vb.) YÜKLENMİYOR — her açılışta sıfır."""
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	if hata == OK:
		intro_tamamlandi = config.get_value("Oyun", "IntroTamamlandi", false)
		print("📂 Intro durumu yüklendi: ", intro_tamamlandi)
	else:
		intro_tamamlandi = false
		print("📂 Save dosyası bulunamadı, intro sıfır.")

func mermi_ekle(miktar: int) -> bool:
	if mermi_sayisi >= max_mermi: return false
	mermi_sayisi = min(mermi_sayisi + miktar, max_mermi)
	emit_signal("mermi_degisti", mermi_sayisi)
	return true

func mermi_harca() -> bool:
	if mermi_sayisi > 0:
		mermi_sayisi -= 1
		emit_signal("mermi_degisti", mermi_sayisi)
		return true
	return false

func saglik_guncelle(bar: int, hp: int):
	oyuncu_kalan_bar = bar; oyuncu_suanki_hp = hp;
	emit_signal("saglik_guncellendi", bar, hp)

func altin_harca(miktar: int) -> bool:
	if toplam_altin >= miktar: 
		toplam_altin -= miktar
		emit_signal("altin_guncellendi", toplam_altin)
		return true
	return false

func pelerin_korumasi_var_mi() -> bool:
	return zar_atlama_hakki > 0

func pelerin_hak_dus():
	if zar_atlama_hakki > 0:
		zar_atlama_hakki -= 1
