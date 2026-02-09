extends Node3D

# --- AYARLAR ---
@export var boss_adi: String = "Blob"
@export var max_can: int = 100
var suanki_can: int = 100
var oldu_mu: bool = false

@export_group("Kaçış Ayarları")
@export var kacma_mesafesi: float = 6.0 # Mesafe arttırıldı
@export var kacma_hizi: float = 4.0

# --- REFERANSLAR ---
@onready var sprite = get_node_or_null("Sprite3D") 
var grid: GridYonetici
var arayuz: CanvasLayer
var oyuncu_ref: Node3D = null

var baslangic_y : float
var zaman : float = 0.0
signal saldiri_tamamlandi 

func _ready():
	add_to_group("Dusman") 
	suanki_can = max_can
	grid = get_tree().current_scene.find_child("GridYoneticisi", true, false)
	arayuz = get_tree().get_first_node_in_group("Arayuz")
	baslangic_y = global_position.y
	
	if GameManager and not GameManager.boss_oldu.is_connected(_on_boss_oldu_sinyali):
		GameManager.boss_oldu.connect(_on_boss_oldu_sinyali)

func _process(delta):
	if oldu_mu: return
	zaman += delta
	
	# Süzülme
	global_position.y = lerp(global_position.y, baslangic_y + (sin(zaman * 2.0) * 0.2), 5.0 * delta)
	
	# Kaçış
	_kacis_kontrol(delta)

func _kacis_kontrol(delta):
	if not is_instance_valid(oyuncu_ref):
		oyuncu_ref = get_tree().get_first_node_in_group("Oyuncu")
		return

	var oyuncu_pos = oyuncu_ref.global_position
	var mesafe = global_position.distance_to(oyuncu_pos)
	
	# Çok yaklaştıysa kaç
	if mesafe < kacma_mesafesi:
		var kacis_yonu = (global_position - oyuncu_pos).normalized()
		kacis_yonu.y = 0 
		
		# Boss'u geriye doğru it
		global_position += kacis_yonu * kacma_hizi * delta
		
		# Masadan düşmesin (Clamp)
		global_position.x = clamp(global_position.x, -7, 7)
		global_position.z = clamp(global_position.z, -7, 7)
		
		# Oyuncuya bak
		look_at(Vector3(oyuncu_pos.x, global_position.y, oyuncu_pos.z), Vector3.UP)

# --- SALDIRI MEKANİKLERİ ---
func saldiri_baslat():
	# Eğer öldüyse saldırma
	if oldu_mu or suanki_can <= 0:
		saldiri_tamamlandi.emit()
		return

	print("🦁 Boss Karar Veriyor... (Rastgele)")
	
	var sans = randf()
	
	if sans < 0.35:
		_telegraph_baslat("TAS")
	elif sans < 0.70:
		_telegraph_baslat("ASIT")
	else:
		_telegraph_baslat("ZAR")

func _telegraph_baslat(tip: String):
	if sprite: 
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector3(1.3, 1.3, 1.3), 0.5)

	var mesaj = ""
	match tip:
		"TAS": mesaj = "KAYA FIRLATIYOR!"
		"ASIT": mesaj = "ASİT TÜKÜRÜYOR!"
		"ZAR": mesaj = "ZAR ATIYOR!"
	
	if arayuz: arayuz.bilgi_goster(boss_adi + ": " + mesaj, 2.0)
	print("⚠️ UYARI: ", mesaj)
	
	await get_tree().create_timer(1.5).timeout
	
	if sprite: 
		sprite.modulate = Color.WHITE
		sprite.scale = Vector3.ONE
	
	if oldu_mu: 
		saldiri_tamamlandi.emit(); return
		
	if tip == "ZAR": 
		_zar_at()
	else: 
		if grid: 
			await _firlat(tip)
			saldiri_tamamlandi.emit()
		else: 
			_zar_at()

func _zar_at():
	if LevelManager and LevelManager.has_method("zar_at_animasyonunu_baslat"):
		LevelManager.zar_at_animasyonunu_baslat()
	else: 
		saldiri_tamamlandi.emit()

func _firlat(tip: String):
	var rx = randi_range(0, grid.grid_boyutu.x - 1)
	var ry = randi_range(0, grid.grid_boyutu.y - 1)
	var hedef = Vector2i(rx, ry)
	var pos = grid.cell_center_world(hedef)
	
	# --- YÜKSEKLİK SENKRONİZASYONU ---
	# GridYonetici'deki 'engel_yuksekligi' ayarını okuyoruz
	# Ayrıca Grid'in kendi Y pozisyonunu da ekliyoruz.
	var hedef_y = grid.global_position.y + grid.engel_yuksekligi
	pos.y = hedef_y
	
	# Mermi
	var mermi = MeshInstance3D.new()
	mermi.set_as_top_level(true) # Önemli: Bağımsız hareket etsin
	
	var mesh = SphereMesh.new()
	if tip == "TAS": 
		mermi.mesh = BoxMesh.new(); mermi.mesh.size = Vector3(0.5, 0.5, 0.5)
	else: 
		mermi.mesh = SphereMesh.new(); mermi.mesh.radius = 0.3; mermi.mesh.height = 0.6
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.GRAY if tip == "TAS" else Color.GREEN
	mat.emission_enabled = true; mat.emission = mat.albedo_color
	mermi.material_override = mat
	
	get_tree().current_scene.add_child(mermi)
	mermi.global_position = global_position + Vector3(0, 1.5, 0)
	
	var tween = create_tween()
	tween.tween_property(mermi, "global_position", pos, 0.5).set_ease(Tween.EASE_IN)
	
	await tween.finished
	mermi.queue_free()
	
	if grid: grid.hucreyi_kilitle(hedef, tip)

func _on_boss_oldu_sinyali():
	oldu_mu = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(queue_free)

func hasar_al(m):
	suanki_can -= m
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	if suanki_can <= 0:
		oldu_mu = true
		GameManager.boss_oldu.emit()
		queue_free()
