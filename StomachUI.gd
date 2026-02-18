extends SubViewportContainer
## MideUI — Mide Sıvı Doluluk UI Parçası
##
## BU SCRİPT SubViewportContainer DÜĞÜMÜNE BAĞLANIR.
## SubViewport + 3D mide sahnesini KENDİSİ oluşturur.
## Sadece bu sahneyi herhangi bir CanvasLayer altına instance et — TAMAM.
##
## KULLANIM:
## 1. MideUI.tscn'i herhangi bir CanvasLayer altına sürükle
## 2. Bitti! Boyut, pozisyon, viewport, mesh, kamera, ışık hepsi otomatik.

# --- AYARLAR ---
@export_group("Boyut & Pozisyon")
@export var panel_boyut: Vector2 = Vector2(180, 180)  ## UI panelinin piksel boyutu
@export var kenar_boslugu: float = 20.0  ## Ekran kenarından mesafe

@export_group("Doluluk")
@export var doluluk_hizi: float = 3.0  ## Fill lerp çarpanı

@export_group("Wobble & Görsel")
@export var wobble_hassasiyet: float = 0.12
@export var idle_wobble: float = 0.015
@export var donus_hizi: float = 0.4  ## Mesh otomatik dönüş (rad/s)

# --- SABİTLER ---
const VIEWPORT_BOYUT: Vector2i = Vector2i(256, 256)

# --- İÇ REFERANSLAR (otomatik oluşturulur) ---
var sub_viewport: SubViewport = null
var mide_mesh: MeshInstance3D = null
var mide_kamera: Camera3D = null
var mide_isik: OmniLight3D = null
var mide_pivot: Node3D = null

# --- DURUM ---
var hedef_doluluk: float = 0.0
var suanki_doluluk: float = 0.0
var wobble_smooth: Vector3 = Vector3.ZERO

func _ready():
	# --- KENDİ BOYUTUNU AYARLA ---
	_boyut_ve_pozisyon_ayarla()
	
	# --- 3D SAHNEYİ İNŞA ET ---
	_viewport_ve_sahne_olustur()
	
	# --- GAMEMANAGER BAĞLANTISI ---
	if GameManager:
		if GameManager.has_signal("mide_guncellendi"):
			GameManager.mide_guncellendi.connect(_on_mide_guncellendi)
		_doluluk_hesapla()
	
	# --- PYRO GÖRÜNÜRLÜK ---
	_pyro_gorunurluk_guncelle()
	
	print("🫁 MideUI hazır. Boyut: %s" % str(panel_boyut))

func _boyut_ve_pozisyon_ayarla():
	"""Container'ı sol-alt köşeye pinle, sabit boyut."""
	# Sabit boyut
	custom_minimum_size = panel_boyut
	size = panel_boyut
	
	# Stretch: viewport'u container'a sığdır
	stretch = true
	
	# Mouse engelle
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Anchor: Sol-Alt köşe
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	
	# Offset: sol-alt köşeye yapış
	offset_left = kenar_boslugu
	offset_top = -panel_boyut.y - kenar_boslugu
	offset_right = panel_boyut.x + kenar_boslugu
	offset_bottom = -kenar_boslugu

func _viewport_ve_sahne_olustur():
	"""SubViewport + 3D mide sahnesini programatik olarak oluştur."""
	
	# --- SUBVIEWPORT ---
	sub_viewport = SubViewport.new()
	sub_viewport.name = "MideViewport"
	sub_viewport.size = VIEWPORT_BOYUT
	sub_viewport.transparent_bg = true
	sub_viewport.own_world_3d = true
	# MSAA (güzel kenarlar)
	sub_viewport.msaa_3d = SubViewport.MSAA_2X
	add_child(sub_viewport)
	
	# --- PIVOT (döndürme merkezi) ---
	mide_pivot = Node3D.new()
	mide_pivot.name = "MidePivot"
	sub_viewport.add_child(mide_pivot)
	
	# --- MİDE MESH (Gerçek model veya fallback küre) ---
	var mide_sahne = load("res://Mide.tscn")
	if mide_sahne:
		# Gerçek 3D mide modelini yükle
		var mide_instance = mide_sahne.instantiate()
		mide_instance.name = "MideModel"
		mide_pivot.add_child(mide_instance)
		
		# Mesh node'u bul (Mide.tscn'de "Mesh_0" veya ilk MeshInstance3D)
		mide_mesh = mide_instance.get_node_or_null("Mesh_0")
		if not mide_mesh:
			# Recursive arama
			mide_mesh = _mesh_bul(mide_instance)
		
		if mide_mesh:
			# Shader material ata
			var shader_mat = ShaderMaterial.new()
			var shader = load("res://stomach_liquid.gdshader")
			if shader:
				shader_mat.shader = shader
				shader_mat.set_shader_parameter("fill_amount", 0.0)
				shader_mat.set_shader_parameter("liquid_color", Color(0.4, 0.02, 0.02, 1.0))
				shader_mat.set_shader_parameter("liquid_highlight", Color(0.7, 0.1, 0.05, 1.0))
				shader_mat.set_shader_parameter("wall_color", Color(0.15, 0.06, 0.06, 0.6))
				shader_mat.set_shader_parameter("wobble", Vector3.ZERO)
				mide_mesh.material_override = shader_mat
			else:
				push_warning("⚠️ stomach_liquid.gdshader bulunamadı!")
		else:
			push_warning("⚠️ Mide.tscn içinde MeshInstance3D bulunamadı!")
	else:
		# Fallback: basit küre
		push_warning("⚠️ Mide.tscn bulunamadı, fallback küre kullanılıyor.")
		mide_mesh = MeshInstance3D.new()
		mide_mesh.name = "MideMesh"
		var sphere = SphereMesh.new()
		sphere.radius = 0.45
		sphere.height = 0.8
		mide_mesh.mesh = sphere
		
		var shader_mat = ShaderMaterial.new()
		var shader = load("res://stomach_liquid.gdshader")
		if shader:
			shader_mat.shader = shader
			shader_mat.set_shader_parameter("fill_amount", 0.0)
			shader_mat.set_shader_parameter("liquid_color", Color(0.4, 0.02, 0.02, 1.0))
			shader_mat.set_shader_parameter("liquid_highlight", Color(0.7, 0.1, 0.05, 1.0))
			shader_mat.set_shader_parameter("wall_color", Color(0.15, 0.06, 0.06, 0.6))
			mide_mesh.material_override = shader_mat
		
		mide_pivot.add_child(mide_mesh)
	
	# --- KAMERA ---
	mide_kamera = Camera3D.new()
	mide_kamera.name = "MideKamera"
	mide_kamera.position = Vector3(0, 0.15, 1.3)
	mide_kamera.fov = 40
	mide_kamera.current = true
	sub_viewport.add_child(mide_kamera)
	
	# --- IŞIK ---
	mide_isik = OmniLight3D.new()
	mide_isik.name = "MideIsik"
	mide_isik.position = Vector3(0.5, 0.5, 1.0)
	mide_isik.light_color = Color(1.0, 0.3, 0.2)
	mide_isik.light_energy = 2.0
	mide_isik.omni_range = 4.0
	sub_viewport.add_child(mide_isik)
	
	# İkinci ışık (alt dolgu)
	var alt_isik = OmniLight3D.new()
	alt_isik.name = "AltIsik"
	alt_isik.position = Vector3(-0.3, -0.5, 0.8)
	alt_isik.light_color = Color(0.3, 0.05, 0.05)
	alt_isik.light_energy = 1.0
	alt_isik.omni_range = 3.0
	sub_viewport.add_child(alt_isik)

func _process(delta):
	# Görünmüyorsa işlem yapma
	if not visible:
		_pyro_gorunurluk_guncelle()
		return
	
	_pyro_gorunurluk_guncelle()
	
	# --- DOLULUK ANİMASYONU ---
	if abs(suanki_doluluk - hedef_doluluk) > 0.001:
		suanki_doluluk = lerp(suanki_doluluk, hedef_doluluk, delta * doluluk_hizi)
		_shader_fill_guncelle(suanki_doluluk)
	
	# --- WOBBLE ---
	_wobble_guncelle(delta)
	
	# --- OTO DÖNDÜRME ---
	if mide_pivot:
		mide_pivot.rotate_y(donus_hizi * delta)

# --- DOLULUK ---

func _doluluk_hesapla():
	if not GameManager: return
	var kapasite = GameManager.get("mide_kapasite")
	var doluluk = GameManager.get("mide_doluluk")
	if kapasite != null and doluluk != null and kapasite > 0:
		hedef_doluluk = clamp(float(doluluk) / float(kapasite), 0.0, 1.0)
	else:
		hedef_doluluk = 0.0

func _on_mide_guncellendi(_doluluk: int, _kapasite: int):
	_doluluk_hesapla()
	print("🫁 Mide: %d/%d → Fill: %.0f%%" % [_doluluk, _kapasite, hedef_doluluk * 100.0])

func _shader_fill_guncelle(fill: float):
	if not mide_mesh: return
	var mat = mide_mesh.material_override
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("fill_amount", fill)

# --- WOBBLE ---

func _wobble_guncelle(delta):
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	var hiz = oyuncu.velocity if oyuncu and oyuncu is CharacterBody3D else Vector3.ZERO
	
	var hedef_wobble = hiz * wobble_hassasiyet
	var zaman = Time.get_ticks_msec() / 1000.0
	hedef_wobble += Vector3(
		sin(zaman * 1.5) * idle_wobble, 0.0,
		cos(zaman * 1.2) * idle_wobble
	)
	wobble_smooth = wobble_smooth.lerp(hedef_wobble, delta * 5.0)
	
	if not mide_mesh: return
	var mat = mide_mesh.material_override
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("wobble", wobble_smooth)

# --- PYRO GÖRÜNÜRLÜK ---

func _pyro_gorunurluk_guncelle():
	if not GameManager: return
	var goster = GameManager.pyro_aktif
	if visible != goster:
		visible = goster

# --- YARDIMCI ---

func _mesh_bul(node: Node) -> MeshInstance3D:
	"""Node ağacında ilk MeshInstance3D'yi recursive olarak bul."""
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var sonuc = _mesh_bul(child)
		if sonuc:
			return sonuc
	return null

