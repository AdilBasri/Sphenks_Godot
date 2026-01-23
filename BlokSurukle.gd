extends Node3D
class_name BlokSurukle

# --- BAĞLANTILAR ---
@export_group("Bağlantılar")
@export var grid: GridYonetici
@export var hayalet: Node3D
@export var hayalet_mat: StandardMaterial3D
@export var tekli_blok_sahnesi: PackedScene # <--- BURAYA block_tek.tscn ATILMALI

# --- AYARLAR ---
@export_group("Ayarlar")
@export var footprint: Array[Vector2i] = [Vector2i(0,0)]
@export var hover_y_offset: float = 0.5 # Elindeyken yerden ne kadar yüksek olsun
@export var kilitlenince_tuket: bool = true

@export_group("Duruş ve Hizalama")
@export var yerlesme_yuksekligi: float = 0.0 # Grid üzerine konduğunda yükseklik farkı
@export var yatma_acisi: Vector3 = Vector3(-90, 0, 0) 

# --- DURUM DEĞİŞKENLERİ ---
var tutuluyor: bool = false
var kilitlendi: bool = false
var son_hucre: Variant = null
var tutma_offseti: Vector3 = Vector3.ZERO # Bloğun neresinden tuttuğunu hatırlar

# --- HAFIZA ---
var orjinal_parent: Node = null
var orjinal_scale: Vector3 = Vector3.ONE
var baslangic_global_pos: Vector3 = Vector3.ZERO
var dik_rotasyon: Quaternion

func _ready() -> void:
	orjinal_parent = get_parent()
	orjinal_scale = scale
	baslangic_global_pos = global_position
	
	# Başlangıç rotasyonunu kaydet (Elde tutarken kullanmak için)
	dik_rotasyon = global_transform.basis.get_rotation_quaternion()
	
	if hayalet: hayalet.visible = false

func _process(_delta: float) -> void:
	if tutuluyor and not kilitlendi:
		_gorsel_mouse_takip()
		_hayalet_guncelle()
		# Tutarken orijinal açıyı ve boyutu koru
		global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)

# --- INPUT (Mouse Tıklama Algılama) ---
func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if kilitlendi: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not tutuluyor:
			# Tıklanan tam noktayı (_position) gönderiyoruz (Dinamik Tutuş)
			_yakala(_position)

func _input(event: InputEvent) -> void:
	if tutuluyor and not kilitlendi and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and (not event.pressed):
			_birak()

# --- YAKALAMA (GRAB) ---
func _yakala(tiklanan_dunya_pos: Vector3) -> void:
	tutuluyor = true
	son_hucre = null
	
	# --- DİNAMİK TUTUŞ HESABI ---
	# Bloğun merkezi ile tıklanan yer arasındaki farkı hesapla
	tutma_offseti = global_position - tiklanan_dunya_pos
	tutma_offseti.y = 0 # Yükseklik farkını yoksay
	
	if grid:
		grid.release_owner(self) # Eski grid kaydını sil (Varsa)

	if hayalet: hayalet.visible = true

	# Sahne ağacında en üste taşı (Diğer objelerin içinden geçmesin)
	var main_scene = get_tree().current_scene
	if main_scene:
		reparent(main_scene, true)
	
	global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)
	_gorsel_mouse_takip() # İlk karede zıplama olmasın

# --- GÖRSEL TAKİP (Matematiksel Düzlem) ---
func _gorsel_mouse_takip() -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var fare_pos = get_viewport().get_mouse_position()
	
	var zemin_yuksekligi = 0.0
	if grid:
		zemin_yuksekligi = grid.global_position.y
	
	# Mouse hareketi için hayali bir düzlem oluştur
	var hareket_duzlemi = Plane(Vector3.UP, zemin_yuksekligi + hover_y_offset)
	
	var from = cam.project_ray_origin(fare_pos)
	var dir = cam.project_ray_normal(fare_pos)
	
	var kesisim = hareket_duzlemi.intersects_ray(from, dir)
	
	if kesisim:
		# Mouse pozisyonuna tutma offsetini ekle
		var hedef_pos = kesisim + tutma_offseti
		# Yumuşak geçiş (Lerp)
		global_position = global_position.lerp(hedef_pos, 0.5)

# --- HAYALET GÜNCELLEME ---
func _hayalet_guncelle() -> void:
	if not grid or not hayalet: return

	hayalet.scale = Vector3.ONE 

	# Hayaletin yerini, bloğun şu anki (offsetli) konumuna göre hesapla
	var current_pos_for_grid = global_position 
	current_pos_for_grid.y = grid.global_position.y # Yüksekliği sıfırla
	
	var vcell = grid.world_to_cell(current_pos_for_grid)
	
	# Hayaleti grid ile aynı hizaya getir (Düz dursun)
	hayalet.global_rotation = grid.global_rotation
	
	# Görsel olarak yatırmak gerekiyorsa (Blok görseline göre değişir)
	hayalet.rotate_object_local(Vector3.RIGHT, deg_to_rad(yatma_acisi.x))
	hayalet.rotate_object_local(Vector3.UP, deg_to_rad(yatma_acisi.y))
	hayalet.rotate_object_local(Vector3.FORWARD, deg_to_rad(yatma_acisi.z))
	
	var kaldirma_vektoru = Vector3.UP * yerlesme_yuksekligi

	if vcell == null:
		son_hucre = null
		_set_hayalet_color(false)
		# Grid dışında da mouse'u takip etsin
		hayalet.global_position = global_position 
		hayalet.global_position.y = grid.global_position.y + 0.1
		return

	var cell = vcell as Vector2i
	son_hucre = cell
	var uygun = grid.can_place(cell, footprint)
	_set_hayalet_color(uygun)

	var center = grid.cell_center_world(cell)
	hayalet.global_position = center + kaldirma_vektoru

func _set_hayalet_color(ok: bool) -> void:
	if not hayalet_mat: return
	if ok:
		hayalet_mat.albedo_color = Color(0, 1, 0, 0.5) # Yeşil
	else:
		hayalet_mat.albedo_color = Color(1, 0, 0, 0.5) # Kırmızı

# --- BIRAKMA (STAMP / DAMGALAMA SİSTEMİ) ---
func _birak() -> void:
	tutuluyor = false
	
	# --- INPUT SYNC FIX ---
	# Bırakma anındaki konumu son bir kez kesinleştir
	if grid:
		var anlik_blok_merkezi = global_position
		anlik_blok_merkezi.y = grid.global_position.y 
		var anlik_hucre = grid.world_to_cell(anlik_blok_merkezi)
		if anlik_hucre != null:
			son_hucre = anlik_hucre
	# ----------------------

	var basarili = false
	
	if grid and son_hucre != null:
		var origin_cell = son_hucre as Vector2i
		
		# 1. Grid'e yerleştirmek mümkün mü?
		if grid.can_place(origin_cell, footprint):
			basarili = true
			
			# 2. DAMGALAMA: Şekli parçala ve tekli bloklara dönüştür
			if tekli_blok_sahnesi:
				for offset in footprint:
					var hedef_hucre = origin_cell + offset
					
					# Yeni tekli blok yarat
					var yeni_blok = tekli_blok_sahnesi.instantiate()
					grid.add_child(yeni_blok)
					
					# Pozisyonu ayarla (Grid hücresinin tam ortasına)
					var pos = grid.cell_center_world(hedef_hucre)
					pos.y += yerlesme_yuksekligi
					
					yeni_blok.global_position = pos
					yeni_blok.scale = orjinal_scale # Boyutu koru
					
					# --- DÜZELTME: Açıyı Grid ile aynı yap (Dümdüz olsun) ---
					# Bu sayede eldeki eğik duruş gride yansımaz.
					yeni_blok.global_rotation = grid.global_rotation 
					# --------------------------------------------------------

					# Grid'e kaydet
					grid.tek_hucre_doldur(hedef_hucre, yeni_blok)
			
			# 3. PATLATMA KONTROLÜ
			grid.satirlari_kontrol_et()
			
			# 4. Kendi işimiz bitti, hayaleti gizle ve bu ana bloğu yok et
			if hayalet: hayalet.visible = false
			queue_free() # Kendini yok et (Çünkü artık gridde parçaların var)

	if not basarili:
		_eve_don()

# --- EVE DÖNÜŞ (Başarısız Olursa) ---
func _eve_don() -> void:
	if hayalet: hayalet.visible = false
	if orjinal_parent:
		reparent(orjinal_parent, false)
	
	# Başlangıç pozisyonuna ve rotasyonuna dön
	global_position = baslangic_global_pos
	global_transform.basis = Basis(dik_rotasyon).scaled(orjinal_scale)
