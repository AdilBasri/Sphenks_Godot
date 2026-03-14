extends Node3D

# --- DEĞİŞKENLER ---
var kamera = null
var altyazi_label = null
var gecis_perdesi = null
var oyuncu = null

var etkilesim_aktif = true 
var varsayilan_fov = 90.0
var toplam_yolcu_sayisi = 0
var yok_edilen_yolcu_sayisi = 0

var diyalog_anahtarlari = [
	"intro_diyalog_1",
	"intro_diyalog_2",
	"intro_diyalog_3",
	"intro_diyalog_4",
	"intro_diyalog_5",
	"intro_diyalog_6",
	"intro_diyalog_7",
	"intro_diyalog_8"
]
var kullanilabilir_diyaloglar = []

func _ready():
	# Sahne başladığında fareyi hapset
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# --- 0. DİNAMİK YOLCU SAYIMI ---
	toplam_yolcu_sayisi = 0
	for child in get_children():
		if child.has_method("etkilesim_baslat"):
			toplam_yolcu_sayisi += 1
	print("Sahne Başladı. Tespit edilen interactable yolcu sayısı: ", toplam_yolcu_sayisi)

	# --- 1. OYUNCUYU VE KAMERAYI BUL (DEDEKTİF YÖNTEMİ) ---
	# Sahne içindeki ismi "Oyuncu" olan düğümü ara (Recursive: True)
	oyuncu = find_child("Oyuncu", true, false)
	
	if oyuncu:
		# Oyuncunun içindeki Kamerayı ara
		kamera = oyuncu.find_child("Camera3D", true, false)
		if kamera:
			varsayilan_fov = kamera.fov
	
	# --- 2. UI ELEMANLARINI BUL ---
	# İsmi tam olarak "Label" olanı bul
	altyazi_label = find_child("Label", true, false)
	if altyazi_label: altyazi_label.text = "" 

	# İsmi "GecisEkrani" olanı bul
	gecis_perdesi = find_child("GecisEkrani", true, false)
	
	if gecis_perdesi:
		if gecis_perdesi.material:
			gecis_perdesi.material.set_shader_parameter("factor", 0.0)
	else:
		print("⚠️ 'GecisEkrani' bulunamadı! (İsmini kontrol et veya sahneyi kaydet)")

	# --- 3. TALİMAT YAZISINI EKLE ---
	_set_up_instruction_label("inst_yolcular")
	if DilYoneticisi:
		DilYoneticisi.dil_degisti.connect(func(): _set_up_instruction_label("inst_yolcular"))

func _set_up_instruction_label(key: String):
	# Sahne içindeki "UI" CanvasLayer'ı bulalım
	var ui_layer = find_child("UI", true, false)
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		add_child(ui_layer)

	var label = ui_layer.get_node_or_null("InstructionLabel")
	if not label:
		label = Label.new()
		label.name = "InstructionLabel"
		ui_layer.add_child(label)

	label.text = DilYoneticisi.metin_al(key) if DilYoneticisi else key

	# Styling (Retro fontu kullanıyoruz)
	var font = load("res://Assets/Fonts/PressStart2P-Regular.ttf")
	if font: label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18) # Slightly smaller
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)

	# Layout (Orta Üst - Tam Ortalamak için Preset ve Anchors)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position.y = 40
	# Reset horizontal offsets to ensure it stays centered
	label.offset_left = -label.size.x / 2.0
	label.offset_right = label.size.x / 2.0

# --- YOLCU TETİKLEYİCİSİ ---
func yolcuya_tiklandi(yolcu_node, yok_olacak_mi):
	if not etkilesim_aktif: return 
	
	etkilesim_aktif = false 
	
	if altyazi_label:
		if kullanilabilir_diyaloglar.is_empty():
			kullanilabilir_diyaloglar = diyalog_anahtarlari.duplicate()
			kullanilabilir_diyaloglar.shuffle()
		
		var secili_anahtar = kullanilabilir_diyaloglar.pop_back()
		altyazi_label.text = DilYoneticisi.metin_al(secili_anahtar)
	
	if kamera:
		var tween = create_tween()
		tween.tween_property(kamera, "fov", 110.0, 0.05).set_trans(Tween.TRANS_BOUNCE)
		tween.parallel().tween_property(kamera, "h_offset", 0.05, 0.05)
		tween.tween_property(kamera, "fov", 60.0, 0.05)
		tween.parallel().tween_property(kamera, "h_offset", -0.05, 0.05)
		tween.tween_property(kamera, "fov", varsayilan_fov, 0.1)
		tween.parallel().tween_property(kamera, "h_offset", 0.0, 0.1)

	if yok_olacak_mi:
		if not yolcu_node.visible:
			etkilesim_aktif = true
			return

		yolcu_node.visible = false
		
		# Recursive collision disable to catch all internal StaticBodies
		_disable_collisions_recursive(yolcu_node)
		
		yok_edilen_yolcu_sayisi += 1 
		print("Yolcu yok edildi. İlerleme: ", yok_edilen_yolcu_sayisi, "/", toplam_yolcu_sayisi)
		
		if yok_edilen_yolcu_sayisi >= toplam_yolcu_sayisi:
			bolum_sonu_gecisi_yap()
			return 
	else:
		var y_tween = create_tween()
		var org_pos = yolcu_node.position
		y_tween.tween_property(yolcu_node, "position", org_pos + Vector3(0.05, 0.05, 0), 0.05)
		y_tween.tween_property(yolcu_node, "position", org_pos, 0.05)

	await get_tree().create_timer(2.0).timeout
	
	if altyazi_label:
		altyazi_label.text = ""
	etkilesim_aktif = true

func bolum_sonu_gecisi_yap():
	print("Sahne kararıyor...")
	if altyazi_label: altyazi_label.text = "" 
	
	if oyuncu and "titreme_aktif" in oyuncu:
		oyuncu.titreme_aktif = false 
	
	if gecis_perdesi and gecis_perdesi.material:
		var tween = create_tween()
		tween.tween_property(gecis_perdesi.material, "shader_parameter/factor", 1.0, 3.0)
		await tween.finished
	else:
		await get_tree().create_timer(3.0).timeout

	get_tree().change_scene_to_file("res://Scenes/yenisahne.tscn")

func _disable_collisions_recursive(node: Node):
	if node is CollisionShape3D:
		node.disabled = true
	for child in node.get_children():
		_disable_collisions_recursive(child)
