extends CanvasLayer

signal tutorial_adimi_tamamlandi(adim_no: int)

# --- TUTORIAL DURUMU ---
var tutorial_aktif: bool = false
var suanki_adim: int = 0

# Arayüz Referansları
@onready var panel = $Panel
@onready var lbl_baslik = $Panel/VBox/LblBaslik
@onready var lbl_metin = $Panel/VBox/LblMetin
@onready var lbl_ipucu = $Panel/VBox/LblIpucu

var metinler = {
	1: {
		"baslik": "EĞİTİM: SPHENKS'E HOŞ GELDİN",
		"metin": "Sphenks'e hoş geldin! Temelde yapman gereken şey çok basit:\n\nKarşındaki firavunu alt etmek için elinde çeşitli bloklar var. Bu blokları satır ve sütun olarak dizip patlatarak firavuna hasar verebilir ve onu yoldan kaldırabilirsin!",
		"ipucu": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	2: {
		"baslik": "ADIM 1: OYUN ALANINA GEÇİŞ",
		"metin": "Oyunu başlatmak için önce tabureye oturmalısın.\nMasaya yaklaş ve otur.",
		"ipucu": "(Tabureye odaklanıp [E] veya [Y] tuşuna bas)",
		"beklenen_eylem": "oturma"
	},
	3: {
		"baslik": "ADIM 2: BLOKLARI SÜRÜKLE",
		"metin": "Sol tarafta voidden çıkan bloklar yer alıyor. Blokları tıklayıp basılı tutarak istediğin gibi sürükleyebilir ve masadaki ızgaraya (grid) bırakabilirsin!",
		"ipucu": "(Farenin Sol Tuşuna veya [A] tuşuna basılı tutarak bloğu masaya çek)",
		"beklenen_eylem": "blok_sürükleme" # Normalde tiklama koyuyoruz, oyuncu okuyup kendisi yapsın
	},
	4: {
		"baslik": "ADIM 3: MASAYA BAKIŞ",
		"metin": "Kamerayı ayarlamak masayı daha iyi görmeni sağlar.\n[A] ve [D] tuşlarıyla (Gamepad: LT / RT) masaya baktığın konumu sağa ve sola çevirebilirsin.\n\nŞimdi blokları dizerek bir satır veya sütun patlatmayı dene!",
		"ipucu": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	5: {
		"baslik": "ADIM 4: FİRAVUNUN UYANIŞI",
		"metin": "DİKKAT! Satır patlattıktan sonra blokların çıkarttığı ses firavunu derin uykusundan uyandırır.\n\nUyanan firavun artık HER blok yerleştirmenden sonra sana ölümcül bir saldırı yapacaktır!",
		"ipucu": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	6: {
		"baslik": "ADIM 5: SAVUŞTURMA (BEKLE)",
		"metin": "Boss sana saldırmak üzere! Suratını ekranda gördüğün an tepki vermeye hazır ol...\n(Saldırıyı bekle)",
		"ipucu": "(Saldırı bekleniyor...)",
		"beklenen_eylem": "bekle" # Oyun akıyor boss vurana kadar
	},
	7: {
		"baslik": "HAZIR OL: PARRY YAP!",
		"metin": "Doğru zamanda PARRY (Savuşturma) yaparak boss atağını bloke edebilirsin!",
		"ipucu": "(SAĞ TIK / [B] tuşuna basarak Savuşturur!)",
		"beklenen_eylem": "parry" # Oyun dondurulur, tıklandığında koddan parry tetiklenir
	},
	8: {
		"baslik": "ADIM 6: HAYALET HAMLE",
		"metin": "Mükemmel! Bir saldırıyı başarıyla savuşturduğunda, 5 saniyelik bir 'HAYALET HAMLE' penceresi kazanırsın.\n\nBu 5 saniye içinde masaya yerleştirdiğin bloklar Boss tarafından GÖRÜLMEZ. Sıranı kullanmadan kombo yapabilirsin!",
		"ipucu": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	9: {
		"baslik": "ADIM 7: HAYALET HAMLEYİ KULLAN",
		"metin": "Şimdi hızlı ol! Devam ettiğinde oyun süresi donacak, 5 saniyen var gibi düşünerek hemen bir blok alıp masaya yerleştir!",
		"ipucu": "(Süre dondu... Hızlıca bir blok alıp masaya koy)",
		"beklenen_eylem": "blok_yerlestirme"
	},
	10: {
		"baslik": "ADIM 8: AYAĞA KALKMA",
		"metin": "Masa başından kalkıp odanın geri kalanını keşfetmen gerekecek.\n\nTekrar [E] / [Y] tuşuna basarak masadan kalkıp odada gezebilirsin.",
		"ipucu": "(Masadan kalkmak için [E] / [Y] tuşuna bas)",
		"beklenen_eylem": "kalkma"
	},
	11: {
		"baslik": "ADIM 9: ÖZEL EŞYALAR",
		"metin": "Yan sehpada beliren Ruh Mantarı'na bak! Üzerine tıklayarak onu eline al.\n\nArdından havaya bakarak [SOL TIK] / [A] tuşuna basıp mantarı tüket!",
		"ipucu": "(Mantarı sol tıkla eline al, tekrar sol tıkla tüket)",
		"beklenen_eylem": "mantar_yeme"
	},
	12: {
		"baslik": "ADIM 10: EFEKTLER GÜZELDİR",
		"metin": "Vuhu! İşte şimdi ortama biraz renk geldi değil mi!\n\nMasaya dönmek için tekrar tabureye [E] ile otur.",
		"ipucu": "(Tabureye tekrar otur)",
		"beklenen_eylem": "oturma"
	},
	13: {
		"baslik": "ADIM 11: RENK KOMBOLARI",
		"metin": "Aynı renk blokları yan yana patlatmak sana ekstra bölüm içi puan (Altın) kazandırır!\n\nAma şunu unutma; marketten alınan ve kullanılan her nesne SADECE o bölüm için geçerlidir. Sonraki katmanlara taşınmaz!",
		"ipucu": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	14: {
		"baslik": "ADIM 12: KAPIDAN GEÇİŞ",
		"metin": "Firavunu ortadan kaldırdığında bölüm biter!\n\nAçık olan kapıdan geçip bir sonraki asansör odasına varırsın. Orada iki yön belirir: SOL'da MARKET çatallanması, SAĞ'da ise CAMPFIRE yer alır. Tercih senin!",
		"ipucu": "(Eğitimi bitirmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	
	# PYRO SAHNESİ EĞİTİMLERİ
	15: {
		"baslik": "PYRO MODU: MERMİ DİKKATİ",
		"metin": "Düşmanlar üzerine akın ederken, tabancanla (Revolver) onları yok edebilirsin.\n\nMermine dikkat et! Sınırlı sayıdalar.",
		"ipucu": "(Ateş etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	},
	16: {
		"baslik": "PYRO MODU: SAĞLIK YENİLEME",
		"metin": "Düşmanlardan düşen et parçaları olacak.\n\nOnları toplayıp [R] / [L1] tuşu ile tüketebilirsin. İşler ters gittiğinde kaybettiğin canını geri doldurmanın tek yolu budur!",
		"ipucu": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)",
		"beklenen_eylem": "tiklama"
	}
}

func _ready():
	process_mode = PROCESS_MODE_ALWAYS # UI durakaltılmadan çalışacak
	hide_tutorial()
	
	if GameManager:
		if not GameManager.blok_yerlestirildi.is_connected(_on_blok_yerlestirildi):
			GameManager.blok_yerlestirildi.connect(_on_blok_yerlestirildi)

func _on_blok_yerlestirildi():
	if tutorial_aktif:
		eylemi_dogrula("blok_yerlestirme")

func start_tutorial():
	print("🎓 Tutorial Modu Başlatıldı.")
	GameManager.verileri_sifirla()
	
	# Tutorial başlar başlamaz odaya (yan sehpaya) bir mantar ver
	var m_data = load("res://Items/Mantar.tres")
	if m_data and not GameManager.envanter.has(m_data):
		GameManager.envanter.append(m_data)
		GameManager.envanter_guncellendi.emit()

	tutorial_aktif = true
	suanki_adim = 1
	_show_step(suanki_adim)

func hide_tutorial():
	visible = false
	if get_tree(): get_tree().paused = false

func _show_step(adim: int):
	if not metinler.has(adim):
		print("🎓 Eğitim Tamamlandı!")
		tutorial_aktif = false
		if GameManager:
			GameManager.tutorial_tamamlandi = true
			GameManager.oyunu_kaydet()
		hide_tutorial()
		return
		
	var veri = metinler[adim]
	suanki_adim = adim
	var beklenen = veri["beklenen_eylem"]
	
	# Mantar artık oyunun en başında verildiği için burada tekrar spawn etmeye gerek yok.
	
	lbl_baslik.text = veri["baslik"]
	lbl_metin.text = veri["metin"]
	lbl_ipucu.text = veri["ipucu"]
	
	visible = true
	var color_rect = get_node_or_null("ColorRect")
	
	if beklenen == "tiklama" or beklenen == "parry":
		# --- OKUMA MODU (OYUN DONAR) ---
		get_tree().paused = true
		if color_rect: color_rect.visible = true
		
		# Paneli Tam Ortaya Al (Büyük)
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -400
		panel.offset_top = -250
		panel.offset_right = 400
		panel.offset_bottom = 250
	else:
		# --- GÖREV MODU (OYUN DEVAM EDER) ---
		get_tree().paused = false
		if color_rect: color_rect.visible = false
		
		# Paneli Üste Yasla (Küçük / Objektif Görünümü)
		panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		panel.offset_left = -400
		panel.offset_top = 20
		panel.offset_right = 400
		panel.offset_bottom = 220
		
		# TUTORIAL BOSS FIX: Adım 6'da Boss'a saldırı emri ver
		if suanki_adim == 6:
			# Küçük bir gecikmeyle saldırıyı başlat ki oyuncu okuyabilsin
			var tree = get_tree()
			if tree:
				var timer = tree.create_timer(1.0)
				timer.timeout.connect(func():
					if LevelManager:
						LevelManager.is_boss_acting = true
						LevelManager.boss_saldirisi_baslat()
						print("⚔️ Tutorial Boss Saldırısı Tetiklendi!")
				)

func eylemi_dogrula(gerceklesecek_eylem: String):
	"""
	Oyuncunun yaptığı eylem (sol tık, e basma, mantar yeme) 
	tutorial_manager'a bildirilir. Beklenen eylemle eşleşirse sonraki adıma geçilir.
	"""
	if not tutorial_aktif: return
	if not metinler.has(suanki_adim): return
	
	var beklenen = metinler[suanki_adim]["beklenen_eylem"]
	
	if gerceklesecek_eylem == beklenen:
		print("🎓 Adım %d başarıyla geçildi: %s" % [suanki_adim, gerceklesecek_eylem])
		tutorial_adimi_tamamlandi.emit(suanki_adim)
		
		# Bir süre bekle ve diğer menüyü göster (Eğer tıklamaya dayalı değilse anında geçmemek için)
		if beklenen == "tiklama":
			_show_step(suanki_adim + 1)
		else:
			# Aksiyon temelli olanlarda UI 1 saniye yeşil kalsın ve sonra geçsin
			lbl_baslik.text = "GÖREV TAMAMLANDI!"
			lbl_baslik.modulate = Color.GREEN
			
			var t = create_tween()
			t.tween_interval(1.5)
			t.tween_callback(func():
				lbl_baslik.modulate = Color.WHITE
				_show_step(suanki_adim + 1)
			)

func ilerlet():
	if tutorial_aktif:
		_show_step(suanki_adim + 1)

func _process(_delta):
	if not tutorial_aktif: return
	
	# Eğer adım 6'daysak (Boss'un saldırmasını bekleme)
	if suanki_adim == 6 and GameManager and GameManager.is_parry_window_open:
		# Glitch yüzü göründü! Hemen oyunu dondurup PARRY YAP ekranını (Adım 7) getir
		_show_step(7)

func _input(event):
	if not visible or not tutorial_aktif: return
	
	# Eğer sadece TIKLAMA ile geçilen bilgilendirme ekranındaysak:
	if metinler.has(suanki_adim) and metinler[suanki_adim]["beklenen_eylem"] == "tiklama":
		if event.is_action_pressed("sol_tik"):
			eylemi_dogrula("tiklama")
			
	# PARRY QTE EKRANI (Oyun Dondurulmuş Halde Sağ Tık Bekleniyor)
	elif metinler.has(suanki_adim) and metinler[suanki_adim]["beklenen_eylem"] == "parry":
		if event.is_action_pressed("sag_tik"):
			print("🛡️ TUTORIAL ESNASINDA PARRY YAPILDI!")
			# Oyuncu donuk olduğu için inputunu biz simüle ediyoruz:
			var boss = get_tree().get_first_node_in_group("Dusman")
			if boss and boss.has_method("glitch_yuzu_kapat"):
				boss.glitch_yuzu_kapat()
			if GameManager:
				GameManager.activate_ghost_move()
				
			eylemi_dogrula("parry")
