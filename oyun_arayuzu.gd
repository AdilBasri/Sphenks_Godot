extends CanvasLayer

# --- BAĞLANTILAR ---
@onready var panel = $ParsomenPanel
@onready var ana_baslik = $ParsomenPanel/ArkaplanGorseli/ToplamPuanLabel
@onready var quota_label = $ParsomenPanel/PuanTablosu/QuotaDeger
@onready var score_label = $ParsomenPanel/PuanTablosu/TotalScoreDeger
@onready var liste = $ParsomenPanel/PuanTablosu/Liste

# Bu arkadaş hata veriyordu, onu güvenli hale getirdik:
var progress_bar = null 

# --- OYUN DEĞİŞKENLERİ ---
var toplam_puan: int = 0
var hedef_puan: int = 300 # Varsayılanı düşürdük
var panel_acik: bool = false

func _ready() -> void:
	add_to_group("Arayuz")
	
	# Progress bar var mı diye nazikçe bakıyoruz, yoksa hata verip oyunu çökertmiyoruz
	if panel and panel.has_node("TextureProgressBar"):
		progress_bar = panel.get_node("TextureProgressBar")
	
	if panel:
		panel.visible = false
	
	guncelle_ekran()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_panel()
	# Hile tuşu (P)
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		puan_ekle(200, "Hile")

func toggle_panel() -> void:
	panel_acik = !panel_acik
	if panel:
		panel.visible = panel_acik

func bolum_kurulumu(yeni_hedef: int) -> void:
	toplam_puan = 0
	hedef_puan = yeni_hedef
	
	if liste:
		for child in liste.get_children():
			child.queue_free()
			
	guncelle_ekran()
	print("ARAYÜZ: Yeni hedef belirlendi -> ", hedef_puan)

func puan_ekle(miktar: int, aciklama: String) -> void:
	toplam_puan += miktar
	
	if liste:
		var satir = Label.new()
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0.1, 0.6, 0.1) 
		liste.add_child(satir)
		liste.move_child(satir, 0)
		if liste.get_child_count() > 10:
			liste.get_child(10).queue_free()

	guncelle_ekran()

func guncelle_ekran() -> void:
	if quota_label: quota_label.text = str(hedef_puan)
	if score_label: 
		score_label.text = str(toplam_puan)
		if toplam_puan >= hedef_puan:
			score_label.modulate = Color.GREEN
		else:
			score_label.modulate = Color(1, 1, 1)
			
	if progress_bar:
		progress_bar.max_value = hedef_puan
		progress_bar.value = toplam_puan
