extends CanvasLayer

# --- BAĞLANTILAR ---
@onready var panel = $ParsomenPanel

# Level Başlığı
@onready var ana_baslik = $ParsomenPanel/ArkaplanGorseli/ToplamPuanLabel

# Tablo Elemanları
@onready var quota_label = $ParsomenPanel/PuanTablosu/QuotaDeger
@onready var score_label = $ParsomenPanel/PuanTablosu/TotalScoreDeger
@onready var liste = $ParsomenPanel/PuanTablosu/Liste

# --- OYUN DEĞİŞKENLERİ ---
var toplam_puan: int = 0
var hedef_puan: int = 300 # İlk kota
var level: int = 1
var panel_acik: bool = false

func _ready() -> void:
	# Paneli gizle ama verileri yazdır
	panel.visible = false
	guncelle_ekran()
	
	# Başlangıçta Level 1 yazsın
	if ana_baslik:
		ana_baslik.text = "LEVEL 1"

func _input(event: InputEvent) -> void:
	# Q: Paneli Aç/Kapa
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_panel()
		
	# P: Test Puanı Ekle (Geliştirici Hilesi)
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		puan_ekle(50, "Test Puani")

func toggle_panel() -> void:
	panel_acik = !panel_acik
	panel.visible = panel_acik

func puan_ekle(miktar: int, aciklama: String) -> void:
	toplam_puan += miktar
	
	# Kotayı geçince level atlama kontrolü
	if toplam_puan >= hedef_puan:
		level_atla()
	
	# Listeye detaylı yazı ekle
	if liste:
		var satir = Label.new()
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0.1, 0.6, 0.1) # Yeşil renk
		
		liste.add_child(satir)
		liste.move_child(satir, 0) # Yeni gelen en üste
		
		# Liste çok uzamasın (Son 10 işlemi tut)
		if liste.get_child_count() > 10:
			liste.get_child(10).queue_free()

	guncelle_ekran()

func level_atla() -> void:
	level += 1
	hedef_puan = int(hedef_puan * 1.5) # Kotayı zorlaştır
	
	# Level atlayınca başlığı güncelle
	if ana_baslik:
		ana_baslik.text = "LEVEL " + str(level)
		ana_baslik.modulate = Color(1, 0.8, 0) # Altın sarısı (Gold)

func guncelle_ekran() -> void:
	# 1. Kotayı Yaz
	if quota_label:
		quota_label.text = str(hedef_puan)
		
	# 2. Skoru Yaz
	if score_label:
		score_label.text = str(toplam_puan)
		
		# Kotaya yaklaştıkça renk değişsin
		if toplam_puan >= hedef_puan:
			score_label.modulate = Color(0, 1, 0) # Yeşil (Geçti)
		else:
			score_label.modulate = Color(0.2, 0.1, 0.0) # Kahve (Henüz geçmedi)
