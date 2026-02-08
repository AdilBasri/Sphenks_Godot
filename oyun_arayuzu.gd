extends CanvasLayer

# --- ESKİ BAĞLANTILAR (Parsomen Sistemi) ---
@onready var panel = $ParsomenPanel
@onready var quota_label = $ParsomenPanel/PuanTablosu/QuotaDeger
@onready var score_label = $ParsomenPanel/PuanTablosu/TotalScoreDeger
@onready var liste = $ParsomenPanel/PuanTablosu/Liste

# --- YENİ BAĞLANTILAR (Altın ve Bilgi Sistemi) ---
# Not: Bu düğümler OyunArayuzu sahnesinde olmalı
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
	# 1. Bilgi Label Gizle
	if bilgi_label: bilgi_label.modulate.a = 0.0
	
	# 2. GameManager Bağlantıları
	if GameManager:
		if not GameManager.altin_guncellendi.is_connected(_on_altin_guncellendi):
			GameManager.altin_guncellendi.connect(_on_altin_guncellendi)
		if not GameManager.envanter_guncellendi.is_connected(totem_sayacini_guncelle):
			GameManager.envanter_guncellendi.connect(totem_sayacini_guncelle)
			
		# Arayüz açılır açılmaz eldeki parayı ve totemi yaz
		_on_altin_guncellendi(GameManager.toplam_altin)
		totem_sayacini_guncelle()

	guncelle_ekran()

	# --- KRİTİK DÜZELTME: MANTAR EFEKTİNİ ZORLA KAPAT ---
	# Bir kare bekle ki sahne tam yüklensin, sonra kapat
	await get_tree().process_frame
	mantar_efekti_yonet(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_panel()

# --- TOTEM SAYACI GÜNCELLEME (MARKET İÇİNDEKİ LABEL) ---
func totem_sayacini_guncelle():
	# SayacLabel, Market sahnesinin içinde olduğu için onu "Ara ve Bul" yöntemiyle çekiyoruz.
	var sayac_label = get_tree().current_scene.find_child("SayacLabel", true, false)
	
	if sayac_label:
		var mevcut = GameManager.envanter.size()
		var maks = GameManager.max_totem_sayisi
		
		sayac_label.text = "TOTEM %d/%d" % [mevcut, maks]
		
		if mevcut >= maks:
			sayac_label.modulate = Color(1, 0.5, 0.5) # Kırmızımsı
		else:
			sayac_label.modulate = Color.WHITE
	else:
		pass

# --- ALTIN GÜNCELLEME ---
func _on_altin_guncellendi(miktar: int):
	if altin_label:
		altin_label.text = str(miktar)
		
		# Altın artınca ufak bir zıplama efekti
		var tween = create_tween()
		tween.tween_property(altin_label, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(altin_label, "scale", Vector2(1.0, 1.0), 0.1)

# --- BİLGİ / TOAST MESAJI ---
func bilgi_goster(mesaj: String):
	if not bilgi_label: return
	
	if bilgi_tween: bilgi_tween.kill()
	
	bilgi_label.text = mesaj
	bilgi_label.modulate.a = 1.0 
	bilgi_label.position.y = 100 
	
	bilgi_tween = create_tween()
	bilgi_tween.tween_property(bilgi_label, "position:y", 80.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bilgi_tween.tween_interval(1.0)
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
	
	# İhtimal 1: AnaKontrol altında
	if has_node("AnaKontrol/MantarEfekti"):
		efekt_node = $AnaKontrol/MantarEfekti
	# İhtimal 2: Direkt altında
	elif has_node("MantarEfekti"):
		efekt_node = $MantarEfekti
		
	if efekt_node:
		# 1. Görünürlüğü ayarla
		efekt_node.visible = aktif
		
		# 2. Shader parametresini ZORLA ayarla
		# (Visible kapalı olsa bile shader parametresini sıfırlayalım)
		if efekt_node.material:
			var guc = 0.02 if aktif else 0.0
			efekt_node.material.set_shader_parameter("strength", guc)
			
		print("🍄 Mantar Efekti: ", "AÇIK" if aktif else "KAPALI", " (Node bulundu)")
	else:
		print("🔴 HATA: 'MantarEfekti' sahnede bulunamadı! Lütfen ColorRect ismini kontrol et.")
