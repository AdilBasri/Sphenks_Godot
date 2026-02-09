extends CanvasLayer

# --- BAĞLANTILAR ---
@onready var panel = $ParsomenPanel
@onready var quota_label = $ParsomenPanel/PuanTablosu/QuotaDeger
@onready var score_label = $ParsomenPanel/PuanTablosu/TotalScoreDeger
@onready var liste = $ParsomenPanel/PuanTablosu/Liste

# --- 🔥 YENİ: PYRO MODU İÇİN UI 🔥 ---
# Bunları Inspector'dan atamayı unutma!
@export var mermi_label: Label 
@export var nisangah: Control
@export var pyro_filtresi: ColorRect

# --- DİĞER UI BAĞLANTILARI ---
@onready var altin_label = $AnaKontrol/MarginContainer/HBoxContainer/AltinSayisi
@onready var bilgi_label = $AnaKontrol/BilgiLabel

# --- DEĞİŞKENLER ---
var katman_label = null
var anim_player = null
var progress_bar = null 
var perde = null 
var bilgi_tween: Tween 

var toplam_puan: int = 0
var hedef_puan: int = 300 
var panel_acik: bool = false

func _ready() -> void:
	add_to_group("Arayuz")
	
	# --- MEVCUT SİSTEMLERİN KURULUMU ---
	if has_node("KatmanLabel"):
		katman_label = $KatmanLabel
		katman_label.visible = false

	if has_node("AnimationPlayer"):
		anim_player = $AnimationPlayer

	if panel and panel.has_node("TextureProgressBar"):
		progress_bar = panel.get_node("TextureProgressBar")
	
	if panel: panel.visible = false
	
	if has_node("Perde"):
		perde = $Perde
		perde.color.a = 1.0 
		perde_ac() 

	if bilgi_label: bilgi_label.modulate.a = 0.0
	
	# --- GAMEMANAGER BAĞLANTILARI ---
	if GameManager:
		if not GameManager.altin_guncellendi.is_connected(_on_altin_guncellendi):
			GameManager.altin_guncellendi.connect(_on_altin_guncellendi)
		if not GameManager.envanter_guncellendi.is_connected(totem_sayacini_guncelle):
			GameManager.envanter_guncellendi.connect(totem_sayacini_guncelle)
		
		# --- 🔥 MERMİ SİNYALİ 🔥 ---
		if not GameManager.mermi_degisti.is_connected(_on_mermi_degisti):
			GameManager.mermi_degisti.connect(_on_mermi_degisti)
			
		_on_altin_guncellendi(GameManager.toplam_altin)
		totem_sayacini_guncelle()
		_on_mermi_degisti(GameManager.mermi_sayisi)

	guncelle_ekran()
	await get_tree().process_frame
	mantar_efekti_yonet(false)

func _process(delta):
	# --- 🔥 UI GÖRÜNÜRLÜK KONTROLÜ (GÜNCELLENDİ) 🔥 ---
	# 1. PYRO Modu Açık MI? ve Silah Çekili Mİ?
	var nisangah_aktif = GameManager.pyro_aktif and GameManager.silah_cekildi
	
	if nisangah: 
		nisangah.visible = nisangah_aktif
	
	# Mermi sayısı da sadece silah çekiliyken görünsün
	if mermi_label:
		mermi_label.visible = nisangah_aktif

	# Kırmızı filtre her zaman Pyro modunda kalsın
	if pyro_filtresi:
		pyro_filtresi.visible = GameManager.pyro_aktif
		if GameManager.pyro_aktif:
			pyro_filtresi.color = Color(1, 0, 0, 0.15)

func _on_mermi_degisti(sayi):
	if mermi_label:
		mermi_label.text = "MERMİ: %d / %d" % [sayi, GameManager.max_mermi]
		
		if sayi == 0:
			mermi_label.modulate = Color.RED
		elif sayi < 5:
			mermi_label.modulate = Color.ORANGE
		else:
			mermi_label.modulate = Color.WHITE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_panel()

func totem_sayacini_guncelle():
	if not is_inside_tree(): return
	var tree = get_tree()
	if not tree or not tree.current_scene: return

	var sayac_label = tree.current_scene.find_child("SayacLabel", true, false)
	if sayac_label:
		var mevcut = GameManager.envanter.size()
		var maks = GameManager.max_totem_sayisi
		sayac_label.text = "TOTEM %d/%d" % [mevcut, maks]
		sayac_label.modulate = Color(1, 0.5, 0.5) if mevcut >= maks else Color.WHITE

func _on_altin_guncellendi(miktar: int):
	if altin_label:
		altin_label.text = str(miktar)
		var tween = create_tween()
		tween.tween_property(altin_label, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(altin_label, "scale", Vector2(1.0, 1.0), 0.1)

func bilgi_goster(mesaj: String, sure: float = 2.0):
	if not bilgi_label: return
	if bilgi_tween: bilgi_tween.kill()
	
	bilgi_label.text = mesaj
	bilgi_label.modulate.a = 1.0 
	bilgi_label.position.y = 100 
	
	bilgi_tween = create_tween()
	bilgi_tween.tween_property(bilgi_label, "position:y", 80.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bilgi_tween.tween_interval(sure) 
	bilgi_tween.tween_property(bilgi_label, "modulate:a", 0.0, 0.5)

func perde_ac():
	if not perde: return
	var tween = create_tween()
	tween.tween_property(perde, "color:a", 0.0, 1.0) 

func perde_kapat(sure: float = 1.0):
	if not perde: return
	var tween = create_tween()
	tween.tween_property(perde, "color:a", 1.0, sure) 
	await tween.finished 

func katman_yazisi_goster(kat_no: int):
	if katman_label:
		katman_label.text = "KATMAN " + str(kat_no)
		katman_label.visible = true
		if anim_player and anim_player.has_animation("katman_giris"):
			anim_player.play("katman_giris")
		else:
			var tween = create_tween()
			katman_label.modulate.a = 0
			katman_label.scale = Vector2(2, 2)
			tween.tween_property(katman_label, "modulate:a", 1.0, 0.5)
			tween.parallel().tween_property(katman_label, "scale", Vector2(1, 1), 0.5)
			tween.tween_interval(2.0)
			tween.tween_property(katman_label, "modulate:a", 0.0, 0.5)

func toggle_panel() -> void:
	panel_acik = !panel_acik
	if panel: panel.visible = panel_acik

func bolum_kurulumu(yeni_hedef: int) -> void:
	toplam_puan = 0
	hedef_puan = yeni_hedef
	if liste:
		for child in liste.get_children(): child.queue_free()
	guncelle_ekran()

func puan_ekle(miktar: int, aciklama: String) -> void:
	toplam_puan += miktar
	if liste:
		var satir = Label.new()
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0.1, 0.6, 0.1) 
		liste.add_child(satir)
		liste.move_child(satir, 0)
		if liste.get_child_count() > 10: liste.get_child(10).queue_free()
	
	bilgi_goster("+%d %s" % [miktar, aciklama])
	guncelle_ekran()

func guncelle_ekran() -> void:
	if quota_label: quota_label.text = str(hedef_puan)
	if score_label: 
		score_label.text = str(toplam_puan)
		score_label.modulate = Color.GREEN if toplam_puan >= hedef_puan else Color.WHITE
	if progress_bar:
		progress_bar.max_value = hedef_puan
		progress_bar.value = toplam_puan
		
		
func mantar_efekti_yonet(aktif: bool):
	var efekt_node = null
	if has_node("AnaKontrol/MantarEfekti"): efekt_node = $AnaKontrol/MantarEfekti
	elif has_node("MantarEfekti"): efekt_node = $MantarEfekti
		
	if efekt_node:
		efekt_node.visible = aktif
		if efekt_node.material:
			var guc = 0.02 if aktif else 0.0
			efekt_node.material.set_shader_parameter("strength", guc)
	else:
		pass
