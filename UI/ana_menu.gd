extends Control

# --- DOSYA YOLLARI ---
# DİKKAT: Dosyalarının gerçek yollarını buraya yaz (Büyük/Küçük harfe dikkat et)
var oyun_sahnesi_yolu = "res://Scenes/Sphenks.tscn"  # Tutorial / Oyun Başlangıcı
var intro_sahnesi_yolu = "res://Scenes/intro_sahnesi.tscn" # Otobüs Sahnesi

func _ready():
	print("Ana Menü Açıldı.")
	
	# 1. ADIM: Sadece intro durumunu kontrol et (oyun state'i her açılışta sıfır)
	GameManager._intro_durumu_yukle()
	print("Menü Yüklendi. Intro Bitti mi: ", GameManager.intro_tamamlandi)

	# --- BUTON BAĞLANTILARI (Defansif Kodlama) ---
	
	# OYNA BUTONU
	if has_node("VBoxContainer/OynaButonu"):
		$VBoxContainer/OynaButonu.pressed.connect(_on_oyna_pressed)
	else:
		print("UYARI: 'OynaButonu' bulunamadı!")
	
	# ÇIKIŞ BUTONU
	if has_node("VBoxContainer/CikisButonu"):
		$VBoxContainer/CikisButonu.pressed.connect(_on_cikis_pressed)
		
	# AYARLAR BUTONU
	if has_node("VBoxContainer/AyarlarButonu"):
		$VBoxContainer/AyarlarButonu.pressed.connect(_on_ayarlar_pressed)

	# 🔥 SIFIRLA (HARD RESET) BUTONU 🔥
	if has_node("VBoxContainer/SifirlaButonu"):
		$VBoxContainer/SifirlaButonu.pressed.connect(_on_sifirla_pressed)

	DilYoneticisi.dil_degisti.connect(metinleri_guncelle)
	metinleri_guncelle()

func metinleri_guncelle():
	if has_node("VBoxContainer/OynaButonu"):
		$VBoxContainer/OynaButonu.text = DilYoneticisi.metin_al("devam_et") if GameManager.intro_tamamlandi else DilYoneticisi.metin_al("basla")
	if has_node("VBoxContainer/AyarlarButonu"):
		$VBoxContainer/AyarlarButonu.text = DilYoneticisi.metin_al("ayarlar")
	if has_node("VBoxContainer/CikisButonu"):
		$VBoxContainer/CikisButonu.text = DilYoneticisi.metin_al("cikis")
	if has_node("VBoxContainer/SifirlaButonu"):
		$VBoxContainer/SifirlaButonu.text = DilYoneticisi.metin_al("kaydi_sifirla")

func _on_ayarlar_pressed():
	# PauseMenu AutoLoad nesnesini bul ve sadece ayarlar arayüzünü açmasını iste
	var pause_menu = get_node_or_null("/root/PauseMenu")
	if pause_menu:
		pause_menu.uykuya_dal()
		pause_menu.ayarlari_ac()

func _on_oyna_pressed():
	# --- KARAR MEKANİZMASI ---
	
	# DURUM A: Oyuncu daha önce introyu bitirmiş (DEVAM ETMEK İSTİYOR)
	if GameManager.intro_tamamlandi:
		print("✅ Oyuncu eski toprak. Kaldığı yerden devam ediyor.")
		
		# KRİTİK NOKTA: Burada 'verileri_sifirla()' ASLA çağırmıyoruz!
		# Çünkü oyuncu 3. seviyedeyse, o veriyi koruyarak sahneye girmeli.
		
		# GameManager'daki kayıtlı seviyeyi garantiye al
		GameManager.oyunu_yukle()
		
		# LEVEL MANAGER UZERINDEN YONLENDIR Kİ PYRO VS KONTROLLERİ YAPILSIN
		var level_manager = get_node_or_null("/root/LevelManager")
		if level_manager and level_manager.has_method("oyunu_baslat"):
			level_manager.oyunu_baslat()
		else:
			if GameManager.kayitli_seviye > 0:
				GameManager.suanki_seviye = GameManager.kayitli_seviye
			else:
				GameManager.suanki_seviye = 1
			get_tree().change_scene_to_file(oyun_sahnesi_yolu)

	# DURUM B: Yeni Oyuncu (veya save silinmiş) (SIFIRDAN BAŞLIYOR)
	else:
		print("🆕 Yeni Oyuncu. Hikaye Modu (Otobüs) Başlıyor...")
		
		# KRİTİK NOKTA: Yeni oyun olduğu için eski kalıntıları temizle!
		GameManager.intro_tamamlandi = false
		GameManager.kayitli_seviye = 1 # Seviyeyi 1'e çek
		GameManager.verileri_sifirla() # Can, altın, envanter hepsini sıfırla
		
		get_tree().change_scene_to_file(intro_sahnesi_yolu)

func _on_cikis_pressed():
	print("Çıkılıyor...")
	get_tree().quit()

func _on_sifirla_pressed():
	print("🗑️ Sıfırlama işlemi başlatılıyor...")
	
	# 1. GameManager sadece işini yapsın
	GameManager.dosyalari_tamamen_sil()
	
	# 2. Görsel bildirim ver
	if has_node("VBoxContainer/SifirlaButonu"):
		var btn = $VBoxContainer/SifirlaButonu
		btn.text = "SİLİNDİ!"
		btn.disabled = true # Çift tıklamayı engelle
		btn.modulate = Color.RED

	# 3. KRİTİK KORUMA: 
	# Eğer GameManager bir şekilde sahneyi değiştirdiyse burada dur.
	if not is_inside_tree(): 
		return

	# 4. Sahne ağacı üzerinden değil, SceneTreeTimer üzerinden bekle
	# Bu yöntem get_tree() hatasını büyük oranda engeller.
	await get_tree().create_timer(1.0).timeout
	
	# 5. Sahne hâlâ buradaysa yenile
	if is_inside_tree():
		print("🔄 Menü yenileniyor...")
		get_tree().reload_current_scene()
		
func _input(event):
	if event is InputEventKey and event.pressed:
		
		# F1: SIFIRLA (Menüdeki butonla aynı işi yapar)
		if event.keycode == KEY_F1:
			if GameManager.has_method("dev_sifirla_ve_basa_don"):
				GameManager.dev_sifirla_ve_basa_don()
			else:
				_on_sifirla_pressed()
			
		# F2: Direkt PİRAMİT BÖLÜMÜNE ATLA (Test için)
		if event.keycode == KEY_F2:
			print("🛠️ Dev: Piramit Sahnesine atlanıyor...")
			get_tree().change_scene_to_file("res://Scenes/Sahne3_Misir.tscn")
			
		# F3: Direkt OYUN İÇİNE ATLA (Test için)
		if event.keycode == KEY_F3:
			print("🛠️ Dev: Oyun Sahnesine atlanıyor...")
			get_tree().change_scene_to_file(oyun_sahnesi_yolu)
