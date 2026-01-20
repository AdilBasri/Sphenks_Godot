extends CanvasLayer

@onready var metin_kutusu = $Panel/KonusmaMetni
@onready var buton_kutusu = $Panel/VBoxContainer
@onready var panel = $Panel

# Fontu Inspector'dan atamayı unutma!
@export var ozel_font : Font 

# Kedi referansı
var aktif_kedi = null

var diyaloglar = [
	{ "id": 0, "text": "[shake rate=20 level=10]Seni aptal insan![/shake] Buraya gelmemeliydin.", "choices": ["Neden?", "Seni ilgilendirmez."] },
	{ "id": 1, "text": "Sayamadığım kadar çok yıldır bu tünellerde iğrenç yaratıklar arasında geziyorum...", "choices": ["Devam Et"] },
	{ "id": 2, "text": "Merak etme, firavunun hazinesi için buradasın değil mi? Hehe...", "choices": ["Öyle bir şey mi var?", "Elbette!"] },
	{ "id": 3, "text": "Para benim için çöp! Ama şanslısın, BANA sahipsin. Beni besle, ben de seni yaşatayım.", "choices": ["Tamam (Eğitimi Başlat)"] }
]

var su_anki_adim = 0

func _ready():
	panel.visible = false
	
	# --- 1. PANELİ GENİŞLET (ELİN HİZASINA ÇEK) ---
	var ekran_boyutu = get_viewport().get_visible_rect().size
	var ekran_genislik = ekran_boyutu.x
	var ekran_yukseklik = ekran_boyutu.y
	
	# Paneli %40'tan %60'a çıkardık (Daha geniş alan)
	var panel_genislik = ekran_genislik * 0.60 
	
	panel.size = Vector2(panel_genislik, ekran_yukseklik)
	panel.position = Vector2(ekran_genislik - panel_genislik, 0)
	
	# --- 2. ADAPTİF DÜZEN (VBoxContainer) ---
	# Elle konum hesaplamak yerine her şeyi dikey bir kutuya koyuyoruz.
	var ana_duzen = VBoxContainer.new()
	panel.add_child(ana_duzen)
	
	# Kenar Boşlukları (Margin)
	var yan_bosluk = 50.0
	var ust_bosluk = 100.0 # Tepeden biraz aşağıda başlasın
	
	ana_duzen.position = Vector2(yan_bosluk, ust_bosluk)
	# Genişlikten yan boşlukları (sağ+sol) düşüyoruz
	ana_duzen.size = Vector2(panel_genislik - (yan_bosluk * 2), ekran_yukseklik - ust_bosluk)
	
	# Yazı ve Butonları bu yeni akıllı kutunun içine taşı (Reparent)
	metin_kutusu.reparent(ana_duzen)
	buton_kutusu.reparent(ana_duzen)
	
	# Elemanlar arası boşluk (Yazı ile Buton arası mesafe)
	ana_duzen.add_theme_constant_override("separation", 50) 
	
	# --- 3. METİN AYARLARI ---
	metin_kutusu.bbcode_enabled = true
	# ÖNEMLİ: Fit Content'i açıyoruz ki yazı ne kadar yer kaplarsa kutu o kadar uzasın
	metin_kutusu.fit_content = true 
	metin_kutusu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	metin_kutusu.add_theme_font_size_override("normal_font_size", 50) # Font boyutu
	metin_kutusu.modulate = Color(1, 1, 1, 1) 
	
	if ozel_font:
		metin_kutusu.add_theme_font_override("normal_font", ozel_font)
		
	# --- 4. BUTON KUTUSU AYARLARI ---
	# Buton kutusu genişliği otomatik üstteki kutuya uyacak
	buton_kutusu.alignment = BoxContainer.ALIGNMENT_CENTER # Butonları ortala

func diyalog_baslat(kedi_referansi):
	aktif_kedi = kedi_referansi
	panel.visible = true
	adim_goster(0)

func adim_goster(index):
	su_anki_adim = index
	var veri = diyaloglar[index]
	
	metin_kutusu.text = veri["text"]
	metin_kutusu.visible_ratio = 0.0
	
	var tween = create_tween()
	tween.tween_property(metin_kutusu, "visible_ratio", 1.0, 2.0)
	
	tween.finished.connect(func(): secenekleri_goster(veri["choices"]))

func secenekleri_goster(secenekler):
	for child in buton_kutusu.get_children():
		child.queue_free()
		
	for secenek in secenekler:
		var btn = Button.new()
		btn.text = secenek
		
		# Buton Font Ayarları
		btn.add_theme_font_size_override("font_size", 40)
		if ozel_font:
			btn.add_theme_font_override("font", ozel_font)
			
		btn.custom_minimum_size = Vector2(0, 90) # Yükseklik
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # Uzun cevaplar sığsın
		
		buton_kutusu.add_child(btn)
		btn.pressed.connect(func(): secim_yapildi(secenek))

func secim_yapildi(secim):
	if su_anki_adim < diyaloglar.size() - 1:
		adim_goster(su_anki_adim + 1)
	else:
		egitimi_baslat()

func egitimi_baslat():
	panel.visible = false
	if aktif_kedi:
		aktif_kedi.oyun_moduna_gec()
