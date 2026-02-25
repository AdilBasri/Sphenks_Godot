extends Node3D

# --- AYARLAR (Inspector'dan değiştirebilirsin) ---
@export var suruklenme_hizi : float = 10.0  # Blok ne kadar hızlı takip etsin? (Yüksek = Sert, Düşük = Sakız gibi)
@export var tilt_miktari : float = 0.3      # Hareket ederken ne kadar yatsın?
@export var masa_yuksekligi : float = 1.0   # Blok masanın ne kadar üstünde süzülsün?

# --- DEĞİŞKENLER ---
var hedef_pozisyon : Vector3
var kamera : Camera3D
var tutuluyor : bool = true # Şimdilik test için hep tutuyoruz varsayalım

func _ready():
	# Sahnedeki aktif kamerayı bul
	kamera = get_viewport().get_camera_3d()
	
	# Başlangıçta hedef olduğumuz yer olsun ki uçmayalım
	hedef_pozisyon = global_position

func _process(delta):
	if tutuluyor:
		mouse_takip_et()
		hareket_ve_tilt(delta)

func mouse_takip_et():
	# 1. Mouse'un ekrandaki 2D yerini al
	var mouse_pos = get_viewport().get_mouse_position()
	
	# 2. Kameradan o noktaya bir ışın (Ray) oluştur
	var from = kamera.project_ray_origin(mouse_pos)
	var to = from + kamera.project_ray_normal(mouse_pos) * 1000.0
	
	# 3. Matematiksel bir Düzlem (Plane) oluştur (Masa yüzeyi)
	# Vector3.UP (0,1,0) yukarı bakan, masanın zemininde bir düzlem
	var masa_duzlemi = Plane(Vector3.UP, masa_yuksekligi)
	
	# 4. Işın masaya nerede değdi?
	var carpisma_noktasi = masa_duzlemi.intersects_ray(from, to)
	
	if carpisma_noktasi:
		# Hedef pozisyonu güncelle (Yüksekliği koruyarak)
		hedef_pozisyon = carpisma_noktasi
		hedef_pozisyon.y = masa_yuksekligi

func hareket_ve_tilt(delta):
	# --- POZİSYON SÜZÜLMESİ (LERP) ---
	# Mevcut pozisyondan hedefe doğru yumuşakça kay
	global_position = global_position.lerp(hedef_pozisyon, suruklenme_hizi * delta)
	
	# --- TILT EFEKTİ (DİNAMİK YATMA) ---
	# Hedef ile aramızdaki farka göre bir "hız vektörü" buluyoruz
	var fark = hedef_pozisyon - global_position
	
	# Sağa gidiyorsak (fark.x > 0), Z ekseninde eksi yöne yatmalı
	var hedef_rotasyon_z = -fark.x * tilt_miktari
	# İleri gidiyorsak (fark.z > 0), X ekseninde artı yöne yatmalı
	var hedef_rotasyon_x = fark.z * tilt_miktari
	
	# Rotasyonu da yumuşakça (Lerp) uygula
	rotation.z = lerp_angle(rotation.z, hedef_rotasyon_z, 10 * delta)
	rotation.x = lerp_angle(rotation.x, hedef_rotasyon_x, 10 * delta)
