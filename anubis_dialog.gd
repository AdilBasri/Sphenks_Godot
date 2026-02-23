extends StaticBody3D

# OYUNCU İLE ETKİLEŞİM İÇİN DEĞİŞKENLER
var sinematik_aktif: bool = false
var orjinal_kamera = null
var oyuncu_node = null

# SİNEMATİK AYARLARI
@export var klavye_hizi: float = 0.05
@export var yazi_bekleme: float = 2.5
var metin_sayaci: int = 0

# UI ELEMANLARI
var canvas: CanvasLayer = null
var shader_rect: ColorRect = null
var yazi_label: Label = null
var etkilesim_yazi: Label3D = null

# KAMERA SALLANMASI
var kamera_sallanma_gucu: float = 0.003
var kamera_sallaniyor_mu: bool = false

var anubis_metinleri = [
	"anubis_diyalog_1",
	"anubis_diyalog_2",
	"anubis_diyalog_3",
	"anubis_diyalog_4",
	"anubis_diyalog_5",
	"anubis_diyalog_6",
	"anubis_diyalog_7",
	"anubis_diyalog_8",
	"anubis_diyalog_9",
	"anubis_diyalog_10"
]

func _ready():
	# Root düğümdeki [E] Konuş yazısını bul
	etkilesim_yazi = get_parent().get_node_or_null("EtkilesimYazisi")
	if etkilesim_yazi:
		etkilesim_yazi.visible = false
		if DilYoneticisi:
			etkilesim_yazi.text = DilYoneticisi.metin_al("anubis_konus_etkilesim")
		
	# Sinyalleri bağla
	pass

func _process(_delta):
	# Kamera sallama efekti
	if kamera_sallaniyor_mu and orjinal_kamera:
		# Oyuncu kamerasının offset değerlerini rastgele değiştir
		orjinal_kamera.h_offset = randf_range(-kamera_sallanma_gucu, kamera_sallanma_gucu)
		orjinal_kamera.v_offset = randf_range(-kamera_sallanma_gucu, kamera_sallanma_gucu)

func _on_bakis_basladi():
	if not sinematik_aktif and etkilesim_yazi:
		etkilesim_yazi.visible = true

func _on_bakis_bitti():
	if etkilesim_yazi:
		etkilesim_yazi.visible = false

# RAYCAST İLE ETKİLEŞİM İÇİN (OyuncuBus.gd bu fonksiyonu çağırıyor)
func etkilesim_baslat():
	if not sinematik_aktif:
		sinematik_baslat()

# Ayrıca "E" tuşuna basmasalar bile Raycast ile bakıldığında "[E] Konuş" görünsün diye 
# Inceleme modulune benzer "odaklanma" fonksiyonlarına ihtiyacımız olabilir.
# Oyununuzda genelde RayCast odaklanmayı nasıl yapıyor bilmiyoruz ama 
# "E" tuşuna bastığında zaten "etkilesim_baslat" çalışacaktır.
# Etkileşim yazısını oyuncu üzerine geldiğinde göstermek için (opsiyonel):
func _on_mouse_entered():
	_on_bakis_basladi()

func _on_mouse_exited():
	_on_bakis_bitti()


func sinematik_baslat():
	sinematik_aktif = true
	if etkilesim_yazi:
		etkilesim_yazi.visible = false
	
	# 1. Oyuncunun kontrolünü dondur
	oyuncu_node = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu_node:
		oyuncu_node.set_process(false)
		oyuncu_node.set_physics_process(false)
		
		# Kamerayı bul
		for child in oyuncu_node.get_children():
			if child is Camera3D:
				orjinal_kamera = child
				break
	
	# 2. Kamerayı Anubis'e yaklaştırma şöleni (Tween)
	var sinematik_kamera = get_parent().get_node_or_null("SinematikKamera")
	if orjinal_kamera and sinematik_kamera:
		var end_transform = sinematik_kamera.global_transform
		
		# Oyuncuyu fiziksel olarak dondurduk, kamerayı dünyadan söküp köke takıyoruz ki 
		# hareketleri oyuncunun lokal eksenine bağlı kalmasın. Geçici bir kamera da yapabiliriz.
		# Daha güvenli olan, kameranın fov veya global transformunu tweenlemektir.
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(orjinal_kamera, "global_transform", end_transform, 2.0)
	
	# 3. Ekran Shader ve UI Katmanını oluştur
	await get_tree().create_timer(1.0).timeout
	ui_katmanini_kur()
	
	# 4. Kamera hafifçe sallanmaya başlasın
	kamera_sallaniyor_mu = true
	
	# 5. Yazılar akmaya başlasın
	metin_sayaci = 0
	_siradaki_metni_yaz()

func ui_katmanini_kur():
	canvas = CanvasLayer.new()
	canvas.layer = 90
	get_tree().current_scene.add_child(canvas)
	
	# B&W Matrix Screen Shader
	var shader = load("res://ghost_shader.gdshader")
	if shader:
		shader_rect = ColorRect.new()
		shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var mat = ShaderMaterial.new()
		mat.shader = shader
		shader_rect.material = mat
		
		# Efectin alfa (saydamlık) değerini yavaşça artır
		shader_rect.modulate.a = 0.0
		canvas.add_child(shader_rect)
		
		var tween = get_tree().create_tween()
		tween.tween_property(shader_rect, "modulate:a", 1.0, 1.5)
	
	# Yazı Label'ı
	yazi_label = Label.new()
	yazi_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	
	# Merkeze ve alt kısıma konumlandır
	var screen_size = get_viewport().get_visible_rect().size
	yazi_label.position = Vector2(0, screen_size.y - 300)
	yazi_label.size = Vector2(screen_size.x, 200)
	
	yazi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yazi_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	yazi_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	yazi_label.add_theme_font_size_override("font_size", 42)
	# Kırmızı Font - İsteğe uygun olarak.
	yazi_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 1.0))
	yazi_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	yazi_label.add_theme_constant_override("outline_size", 8)
	
	yazi_label.text = ""
	canvas.add_child(yazi_label)

func _siradaki_metni_yaz():
	if metin_sayaci >= anubis_metinleri.size():
		sinematigi_bitir()
		return
		
	var anahtar = anubis_metinleri[metin_sayaci]
	var suanki_metin = DilYoneticisi.metin_al(anahtar) if DilYoneticisi else anahtar
	yazi_label.text = suanki_metin
	yazi_label.visible_ratio = 0.0
	
	var metin_uzunlugu = suanki_metin.length()
	var yazma_suresi = metin_uzunlugu * klavye_hizi
	
	var tween = get_tree().create_tween()
	tween.tween_property(yazi_label, "visible_ratio", 1.0, yazma_suresi)
	
	# Yazım bittikten sonra ekranda kalma süresi
	tween.tween_interval(yazi_bekleme)
	tween.tween_callback(_metin_bitti)

func _metin_bitti():
	metin_sayaci += 1
	var tween = get_tree().create_tween()
	tween.tween_property(yazi_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		yazi_label.modulate.a = 1.0
		_siradaki_metni_yaz()
	)

func sinematigi_bitir():
	kamera_sallaniyor_mu = false
	
	# Shader'ı yavaşça kaldır
	var tween = get_tree().create_tween()
	if shader_rect:
		tween.tween_property(shader_rect, "modulate:a", 0.0, 1.5)
	if yazi_label:
		tween.parallel().tween_property(yazi_label, "modulate:a", 0.0, 0.5)
		
	# Kamerayı eski yerine götürmeye gerek var mı? 'Evine git' dediği için oyuncunun yolculuğu biter.
	# Ama bozmamak için oyunu geri verelim
	if oyuncu_node and orjinal_kamera:
		orjinal_kamera.h_offset = 0
		orjinal_kamera.v_offset = 0
		
		# Kameranın dönüşünü de sıfırlayalım ki çarpılmasın. (Tween bittiğinde düzelsin)
		# Sadece oyuncu kontrolünü yeniden açalım.
		oyuncu_node.set_process(true)
		oyuncu_node.set_physics_process(true)
		
	tween.tween_callback(func():
		if canvas:
			canvas.queue_free()
		# Eğer sadece 1 kere tetiklensin istersek:
		queue_free()
	)
