extends CanvasLayer

# --- BAĞLANTILAR (Hiyerarşine %100 Uyumlu) ---
@onready var panel = $ParsomenPanel

# Level Başlığı (Resmin içinde olduğu için)
@onready var ana_baslik = $ParsomenPanel/ArkaplanGorseli/ToplamPuanLabel

# Tablo Elemanları (PuanTablosu'nun içinde)
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

func _input(event: InputEvent) -> void:
	# Q: Paneli Aç/Kapa
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_panel()
		
	# --- TEST İÇİN (Bunu sonra silersin) ---
	# P Tuşuna basınca 50 puan ekler. Tablonun çalıştığını böyle anlarsın.
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		puan_ekle(50, "Test Puani")

func toggle_panel() -> void:
	panel_acik = !panel_acik
	panel.visible = panel_acik

# --- PUAN EKLEME FONKSİYONU ---
# Bu fonksiyonu diğer scriptlerden çağıracaksın!
# Örnek: OyunArayuzu.puan_ekle(100, "Tekli Sıra")
func puan_ekle(miktar: int, aciklama: String) -> void:
	toplam_puan += miktar
	
	# Kotayı geçince ne olsun? (Balatro stili level atlama)
	if toplam_puan >= hedef_puan:
		level_atla()
	
	# Listeye detaylı yazı ekle (Log)
	if liste:
		var satir = Label.new()
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0.1, 0.6, 0.1) # Yeşil renk
		# Yeni gelen en üste
		liste.add_child(satir)
		liste.move_child(satir, 0)
		
		# Liste çok uzamasın (Son 10 işlemi tut)
		if liste.get_child_count() > 10:
			liste.get_child(10).queue_free()

	guncelle_ekran()

func level_atla() -> void:
	level += 1
	hedef_puan = int(hedef_puan * 1.5) # Kotayı zorlaştır
	
	# Level atlama efekti veya sesi buraya eklenebilir
	if ana_baslik:
		ana_baslik.text = "LEVEL " + str(level)
		ana_baslik.modulate = Color.GOLD # Rengi parlat

func guncelle_ekran() -> void:
	# 1. Kotayı Yaz
	if quota_label:
		quota_label.text = str(hedef_puan)
		
	# 2. Skoru Yaz
	if score_label:
		score_label.text = str(toplam_puan)
		
		# Kotaya yaklaştıkça renk değişsin mi?
		if toplam_puan >= hedef_puan:
			score_label.modulate = Color.GREEN # Geçti!
		else:
			score_label.modulate = Color(0.2, 0.1, 0.0) # Henüz geçmedi (Kahve)
