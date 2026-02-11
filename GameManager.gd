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
var kayitli_seviye: int = 1 # <--- YENİ: Kayıt sistemimiz için eklendi
var toplam_altin: int = 10 
var intro_tamamlandi: bool = false # <--- YENİ EKLENECEK: Intro bitti mi kontrolü

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
var tek_zar_modu: bool = false

# --- 🔥 PYRO MODU & SİLAH SİSTEMİ DEĞİŞKENLERİ 🔥 ---
var pyro_aktif: bool = false
var mermi_sayisi: int = 10
var max_mermi: int = 40
var silah_cekildi: bool = false # Silah elimizde mi?

func _ready():
	print("GameManager Başlatıldı.")
	oyunu_yukle()
	# verileri_sifirla() # <--- DİKKAT: Bunu buradaki _ready'den silebilirsin.
	# Çünkü sıfırlama işlemini "Ana Menü"den "Başla" dediğimizde yapacağız.

func verileri_sifirla():
	# EĞER KAYITLI SEVİYE 1'DEN BÜYÜKSE, DEMEK Kİ DEVAM EDİYORUZ.
	# O YÜZDEN CANI VE ALTINI SIFIRLAMA!
	if kayitli_seviye > 1:
		suanki_seviye = kayitli_seviye
		if LevelManager: LevelManager.suanki_katman = suanki_seviye
		
		# Arayüzü güncelle
		await get_tree().process_frame 
		emit_signal("saglik_guncellendi", oyuncu_kalan_bar, oyuncu_suanki_hp)
		emit_signal("envanter_guncellendi")
		emit_signal("altin_guncellendi", toplam_altin)
		emit_signal("mermi_degisti", mermi_sayisi)
		return # FONKSİYONDAN ÇIK (Sıfırlamayı iptal et)

	# --- BURADAN SONRASI SADECE YENİ OYUN İÇİN ÇALIŞIR ---
	oyuncu_kalan_bar = 4
	oyuncu_suanki_hp = 10
	suanki_seviye = 1
	toplam_altin = 10
	mermi_sayisi = 10
	pyro_aktif = false
	silah_cekildi = false 
	envanter.clear()
	bolum_bufflarini_sifirla()
	zar_atlama_hakki = 0
	
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

# --- KAYDETME VE YÜKLEME SİSTEMİ (YENİ EKLENDİ) ---
func oyunu_kaydet():
	var config = ConfigFile.new()
	
	# ... (Diğer kayıtlar: Seviye, Altın vs. aynen kalsın) ...
	config.set_value("Oyun", "KayitliSeviye", suanki_seviye)
	config.set_value("Oyun", "Altin", toplam_altin)
	config.set_value("Oyuncu", "KalanBar", oyuncu_kalan_bar)
	config.set_value("Oyuncu", "SuankiHP", oyuncu_suanki_hp)
	config.set_value("Oyuncu", "MermiSayisi", mermi_sayisi)
	config.set_value("Oyuncu", "PyroAktif", pyro_aktif)
	
	# --- YENİ: BUFF DURUMUNU KAYDET ---
	config.set_value("Bufflar", "PuanCarpani", puan_carpani)
	# ----------------------------------
	
	# Envanter kaydı...
	var esya_yollari = []
	for esya in envanter:
		if esya != null: esya_yollari.append(esya.resource_path)
	config.set_value("Oyun", "Envanter", esya_yollari)
	
	config.save("user://savegame.cfg")
	# ... (Bildirim kodları aynen kalsın)

func oyunu_yukle():
	var config = ConfigFile.new()
	var hata = config.load("user://savegame.cfg")
	
	if hata == OK:
		# ... (Diğer yüklemeler aynen kalsın) ...
		kayitli_seviye = config.get_value("Oyun", "KayitliSeviye", 1)
		toplam_altin = config.get_value("Oyun", "Altin", 10)
		oyuncu_kalan_bar = config.get_value("Oyuncu", "KalanBar", 4)
		oyuncu_suanki_hp = config.get_value("Oyuncu", "SuankiHP", 10)
		mermi_sayisi = config.get_value("Oyuncu", "MermiSayisi", 10)
		pyro_aktif = config.get_value("Oyuncu", "PyroAktif", false)
		
		# --- YENİ: BUFF DURUMUNU GERİ YÜKLE ---
		puan_carpani = config.get_value("Bufflar", "PuanCarpani", 1.0)
		# --------------------------------------
		
		# Envanter yükleme...
		envanter.clear()
		var esya_yollari = config.get_value("Oyun", "Envanter", [])
		for yol in esya_yollari:
			if ResourceLoader.exists(yol):
				envanter.append(load(yol))
				
		print("📂 Kayıt Yüklendi. Seviye:", kayitli_seviye, " Puan Çarpanı:", puan_carpani)
	else:
		kayitli_seviye = 1

func dev_sifirla_ve_basa_don():
	intro_tamamlandi = false
	suanki_seviye = 1
	kayitli_seviye = 1
	toplam_altin = 10
	oyunu_kaydet() # Temizlenmiş halini kaydet
	print("⚠️ DEVELOPER RESET: Tüm ilerleme ve Intro silindi!")
	get_tree().change_scene_to_file("res://ana_menu.tscn") # Menüye at
		

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
		
func dosyalari_tamamen_sil():
	# 1. Kayıt dosyasını fiziksel olarak sil
	var dir = DirAccess.open("user://")
	if dir.file_exists("savegame.cfg"):
		dir.remove("savegame.cfg")
		print("🗑️ Kayıt dosyası diskten silindi.")
	
	# 2. Hafızadaki verileri sıfırla
	intro_tamamlandi = false
	kayitli_seviye = 1
	suanki_seviye = 1
	toplam_altin = 10
	
	# 3. ÖNEMLİ: oyunu_kaydet() fonksiyonunu burada ÇAĞIRMA. 
	# Çünkü o fonksiyon içinde UI'a erişmeye çalışan kodlar (bilgi_goster gibi) hata verebilir.
	print("⚙️ Hafıza sıfırlandı.")
