extends CanvasLayer

# --- ESKİ BAĞLANTILAR (Parsomen Sistemi) ---
@onready var panel = $ParsomenPanel
@onready var quota_label = $ParsomenPanel/PuanTablosu/QuotaDeger
@onready var score_label = $ParsomenPanel/PuanTablosu/TotalScoreDeger
@onready var liste = $ParsomenPanel/PuanTablosu/Liste

# --- YENİ BAĞLANTILAR (Altın ve Bilgi Sistemi) ---
# DİKKAT: Bu düğümleri sahnede oluşturduğunu varsayıyoruz.
# Eğer "AnaKontrol" ismini farklı yaptıysan burayı düzeltmelisin.
@onready var altin_label = $AnaKontrol/MarginContainer/HBoxContainer/AltinSayisi
@onready var bilgi_label = $AnaKontrol/BilgiLabel

# --- DİĞER DEĞİŞKENLER ---
var katman_label = null
var anim_player = null
var progress_bar = null 
var perde = null 

var bilgi_tween: Tween # Bilgi mesajı animasyonu için

# --- OYUN DEĞİŞKENLERİ ---
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
	
	if panel:
		panel.visible = false
	
	# PERDEYİ BAĞLA
	if has_node("Perde"):
		perde = $Perde
		perde.color.a = 1.0 
		perde_ac() 
	else:
		print("UYARI: 'Perde' bulunamadı!")

	# --- YENİ SİSTEMLERİN KURULUMU (GAMEMANAGER) ---
	if GameManager:
		# Altın güncellemelerini dinle
		if not GameManager.altin_guncellendi.is_connected(_on_altin_guncellendi):
			GameManager.altin_guncellendi.connect(_on_altin_guncellendi)
		
		# Başlangıç altınını yazdır
		_on_altin_guncellendi(GameManager.toplam_altin)
	
	# Bilgi etiketini başlangıçta gizle
	if bilgi_label:
		bilgi_label.modulate.a = 0.0

	guncelle_ekran()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_panel()

# --- ALTIN GÜNCELLEME (YENİ) ---
func _on_altin_guncellendi(miktar: int):
	if altin_label:
		altin_label.text = str(miktar)
		
		# Altın artınca ufak bir zıplama efekti
		var tween = create_tween()
		tween.tween_property(altin_label, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(altin_label, "scale", Vector2(1.0, 1.0), 0.1)

# --- BİLGİ / TOAST MESAJI (YENİ - Hata Çözümü) ---
func bilgi_goster(mesaj: String):
	if not bilgi_label: return
	
	# Önceki animasyon varsa durdur
	if bilgi_tween: bilgi_tween.kill()
	
	bilgi_label.text = mesaj
	bilgi_label.modulate.a = 1.0 # Görünür yap
	bilgi_label.position.y = 100 # Başlangıç yüksekliği (Ayarlayabilirsin)
	
	bilgi_tween = create_tween()
	
	# 1. Yukarı kayarak belirme
	bilgi_tween.tween_property(bilgi_label, "position:y", 80.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2. Bekleme
	bilgi_tween.tween_interval(1.0)
	# 3. Silinme
	bilgi_tween.tween_property(bilgi_label, "modulate:a", 0.0, 0.5)

# --- PERDE SİSTEMİ ---
func perde_ac():
	if not perde: return
	var tween = create_tween()
	tween.tween_property(perde, "color:a", 0.0, 1.0) 

func perde_kapat(sure: float = 1.0):
	if not perde: return
	var tween = create_tween()
	tween.tween_property(perde, "color:a", 1.0, sure) 
	await tween.finished 

# --- KATMAN YAZISI ---
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

# --- DİĞER UI İŞLEVLERİ ---
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
	
	# 1. Listeye Ekle (Eski Sistem)
	if liste:
		var satir = Label.new()
		satir.text = "+%d %s" % [miktar, aciklama]
		satir.modulate = Color(0.1, 0.6, 0.1) 
		liste.add_child(satir)
		liste.move_child(satir, 0)
		if liste.get_child_count() > 10: liste.get_child(10).queue_free()
	
	# 2. Ekrana Bilgi Mesajı Olarak Bas (Yeni Sistem)
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
