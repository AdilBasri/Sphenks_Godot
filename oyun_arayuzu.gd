extends CanvasLayer

@onready var panel = $ParsomenPanel
@onready var liste = $ParsomenPanel/Liste
@onready var toplam_label = $ParsomenPanel/ToplamPuanLabel

var puan: int = 0
var hedef_puan: int = 150
var panel_acik: bool = true # Başlangıçta TRUE yaptık ki görelim

func _ready() -> void:
	print(">>> ARAYÜZ YÜKLENDİ! Ekranda kahverengi kutu görmelisin.")
	# Paneli zorla görünür yapıyoruz
	panel.visible = true 
	guncelle_label()

func _input(event: InputEvent) -> void:
	# Input Map yerine direkt TUŞ KODU kullanıyoruz (Test için)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			print(">>> Q TUŞUNA BASILDI! Panel aç/kapa yapılıyor.")
			toggle_panel()

func toggle_panel() -> void:
	panel_acik = !panel_acik
	panel.visible = panel_acik

func puan_ekle(miktar: int, aciklama: String) -> void:
	puan += miktar
	guncelle_label()
	
	var satir = Label.new()
	if miktar > 0:
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0, 1, 0)
	else:
		satir.text = "%d %s" % [miktar, aciklama]
		satir.modulate = Color(1, 0, 0)
		
	liste.add_child(satir)
	liste.move_child(satir, 0) 

func guncelle_label() -> void:
	toplam_label.text = "PUAN: %d / %d" % [puan, hedef_puan]
