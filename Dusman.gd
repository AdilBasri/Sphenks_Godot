extends Node3D

# --- AYARLAR ---
@export var boss_adi: String = "Blob"
@export var max_can: int = 100
var suanki_can: int = 100
var oldu_mu: bool = false

@export_group("Görsel Efektler")
@export var genel_boyut: float = 0.5 
@export var suzulme_hizi : float = 2.0
@export var suzulme_mesafesi : float = 0.15

@export_group("Kaçış Fizigi")
@export var kisisel_alan: float = 6.0   # Oyuncu bu kadar yaklaşırsa kaçar
@export var itme_gucu: float = 10.0     # Kaçış hızı
@export var surtunme: float = 5.0       # Kayma hissi (Yüksekse çabuk durur)
@export var masa_siniri: float = 5.5    # Masanın yarıçapı (Dışarı çıkamaz)
@export var merkeze_donus_hizi: float = 1.0 # Tehdit yoksa merkeze dönsün

@export_group("Zorla Ayarlar")
@export var mermi_zemini_y: float = -1.0 

# --- DEĞİŞKENLER ---
@onready var sprite = get_node_or_null("Sprite3D") 
var grid: GridYonetici
var arayuz: CanvasLayer
var oyuncu_ref: Node3D = null

var baslangic_y : float
var baslangic_pos : Vector3
var zaman : float = 0.0
var velocity : Vector3 = Vector3.ZERO # Hız vektörü

signal saldiri_tamamlandi 

func _ready():
	add_to_group("Dusman") 
	suanki_can = max_can
	
	grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	arayuz = get_tree().get_first_node_in_group("Arayuz")
	
	baslangic_y = global_position.y
	baslangic_pos = global_position # Doğduğu yeri hatırla
	
	scale = Vector3(genel_boyut, genel_boyut, genel_boyut)
	
	if GameManager and not GameManager.boss_oldu.is_connected(_on_boss_oldu_sinyali):
		GameManager.boss_oldu.connect(_on_boss_oldu_sinyali)

func _process(delta):
	if oldu_mu: return
	zaman += delta
	
	# Görsel Süzülme (Sadece Y ekseni görseli)
	var visual_y = baslangic_y + (sin(zaman * suzulme_hizi) * suzulme_mesafesi)
	# Physics ile çakışmaması için sadece child sprite'ı oynatabiliriz ama 
	# şimdilik global Y'yi görsel için, X ve Z'yi fizik için kullanacağız.
	
	_fizik_hareket(delta)
	
	# Yüksekliği görsel efekte sabitle (Fizikten bağımsız)
	global_position.y = lerp(global_position.y, visual_y, 5.0 * delta)

func _fizik_hareket(delta):
	if not is_instance_valid(oyuncu_ref):
		oyuncu_ref = get_tree().get_first_node_in_group("Oyuncu")
		return

	var oyuncu_pos = oyuncu_ref.global_position
	var benim_pos = global_position
	
	# 1. VEKTÖRLERİ HESAPLA
	var oyuncudan_bana = (benim_pos - oyuncu_pos) # Kaçış yönü
	var mesafe = oyuncudan_bana.length()
	
	var kuvvet = Vector3.ZERO
	
	# 2. KAÇIŞ MANTIĞI (İTME)
	if mesafe < kisisel_alan:
		# Ne kadar yakınsa o kadar hızlı kaçsın
		var kacis_baskisi = (1.0 - (mesafe / kisisel_alan)) # 0 ile 1 arası
		
		# Vektörü normalize et ve güçle çarp
		var itis_yonu = oyuncudan_bana.normalized()
		itis_yonu.y = 0 # Havaya uçma
		
		kuvvet += itis_yonu * itme_gucu * kacis_baskisi
	else:
		# 3. MERKEZE DÖNÜŞ (LASTİK ETKİSİ)
		# Eğer tehdit yoksa yavaşça ilk doğduğu yere dönsün
		var merkeze_yon = (baslangic_pos - benim_pos).normalized()
		merkeze_yon.y = 0
		if benim_pos.distance_to(baslangic_pos) > 0.5:
			kuvvet += merkeze_yon * merkeze_donus_hizi

	# 4. FİZİK UYGULAMA (HIZLANMA & SÜRTÜNME)
	velocity += kuvvet * delta # Kuvveti hıza ekle
	
	# Sürtünme (Yavaşlama)
	velocity = velocity.lerp(Vector3.ZERO, surtunme * delta)
	
	# 5. POZİSYONU GÜNCELLE
	global_position += velocity * delta
	
	# 6. DUVAR SINIRLARI (KATI DUVAR)
	# Dışarı çıktıysa zorla içeri al
	# Merkeze (0,0,0) göre sınırları kontrol ediyoruz.
	# Eğer Grid'in merkezi (0,0) değilse, buraya `grid.global_position.x` eklemeliyiz.
	# Basitlik için Grid'in (0,0) merkezli olduğunu varsayıyoruz (Veya başlangıç pozisyonu)
	
	var merkez_x = baslangic_pos.x 
	var merkez_z = baslangic_pos.z
	
	global_position.x = clamp(global_position.x, merkez_x - masa_siniri, merkez_x + masa_siniri)
	global_position.z = clamp(global_position.z, merkez_z - masa_siniri, merkez_z + masa_siniri)
	
	# 7. YÜZÜNÜ OYUNCUYA DÖN
	var bakis_hedefi = Vector3(oyuncu_pos.x, global_position.y, oyuncu_pos.z)
	look_at(bakis_hedefi, Vector3.UP)


# ==========================================
# SALDIRI (AYNI KALDI)
# ==========================================

func saldiri_baslat():
	if oldu_mu: saldiri_tamamlandi.emit(); return

	var sans = randf()
	if sans < 0.35: _telegraph_baslat("TAS")
	elif sans < 0.70: _telegraph_baslat("ASIT")
	else: _telegraph_baslat("ZAR")

func _telegraph_baslat(tip: String):
	if sprite: 
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector3(1.3, 1.3, 1.3) * genel_boyut, 0.5)

	var mesaj = ""
	match tip:
		"TAS": mesaj = "KAYA FIRLATIYOR!"
		"ASIT": mesaj = "ASİT TÜKÜRÜYOR!"
		"ZAR": mesaj = "ZAR ATIYOR!"
	
	if arayuz: arayuz.bilgi_goster(boss_adi + ": " + mesaj, 2.0)
	
	await get_tree().create_timer(1.5).timeout
	
	if sprite: 
		sprite.modulate = Color.WHITE
		sprite.scale = Vector3(genel_boyut, genel_boyut, genel_boyut)
	
	if oldu_mu: saldiri_tamamlandi.emit(); return
		
	match tip:
		"TAS", "ASIT":
			if grid: await _manuel_firlat(tip); saldiri_tamamlandi.emit()
			else: _zar_at()
		"ZAR": _zar_at()

func _zar_at():
	if LevelManager and LevelManager.has_method("zar_at_animasyonunu_baslat"):
		LevelManager.zar_at_animasyonunu_baslat()
	else: saldiri_tamamlandi.emit()

func _manuel_firlat(tip: String):
	var rx = randi_range(0, grid.grid_boyutu.x - 1)
	var ry = randi_range(0, grid.grid_boyutu.y - 1)
	var hedef_hucre = Vector2i(rx, ry)
	var grid_pos = grid.cell_center_world(hedef_hucre)
	
	var hedef_y = mermi_zemini_y
	if "engel_yuksekligi" in grid:
		hedef_y = grid.global_position.y + grid.engel_yuksekligi
	
	var final_pos = Vector3(grid_pos.x, hedef_y, grid_pos.z)
	
	var mermi = MeshInstance3D.new()
	mermi.set_as_top_level(true)
	var mesh = SphereMesh.new()
	var renk = Color.GRAY
	
	if tip == "TAS": mermi.mesh = BoxMesh.new(); mermi.mesh.size = Vector3(0.5, 0.5, 0.5); renk = Color.GRAY
	else: mermi.mesh = SphereMesh.new(); mermi.mesh.radius = 0.3; mermi.mesh.height = 0.6; renk = Color.GREEN
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = renk; mat.emission_enabled = true; mat.emission = renk
	mermi.material_override = mat
	
	get_tree().current_scene.add_child(mermi)
	mermi.global_position = global_position + Vector3(0, 1.5, 0)
	
	var tween = create_tween()
	tween.tween_property(mermi, "global_position", final_pos, 0.5).set_ease(Tween.EASE_IN)
	
	await tween.finished
	mermi.queue_free()
	if grid: grid.hucreyi_kilitle(hedef_hucre, tip)

func _on_boss_oldu_sinyali():
	oldu_mu = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(queue_free)

func hasar_al(miktar: int):
	suanki_can -= miktar
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if suanki_can <= 0:
		oldu_mu = true
		GameManager.boss_oldu.emit()
		queue_free()
