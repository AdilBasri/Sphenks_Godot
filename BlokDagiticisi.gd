extends Node3D

# --- AYARLAR ---
@export var grid: GridYonetici # Grid'i buraya sürükle
@export var spawn_noktalari: Array[Marker3D] # Pos1, Pos2, Pos3 buraya
@export var blok_sahneleri: Array[PackedScene] # Block_L, Block_T vb. buraya

# --- DEĞİŞKENLER ---
var aktif_blok_sayisi: int = 0

func _ready() -> void:
	# Oyun başlar başlamaz ilk partiyi dağıt
	# Biraz bekleyelim ki diğer sistemler (Grid vb.) hazır olsun
	await get_tree().create_timer(0.1).timeout
	yeni_parti_dagit()

func yeni_parti_dagit() -> void:
	if blok_sahneleri.size() == 0 or spawn_noktalari.size() == 0:
		print("HATA: Blok Sahneleri veya Spawn Noktaları atanmamış!")
		return

	aktif_blok_sayisi = 3
	
	for i in range(3):
		var spawn_point = spawn_noktalari[i]
		
		# 1. Rastgele blok seç ve yarat
		var random_scene = blok_sahneleri.pick_random()
		var yeni_blok = random_scene.instantiate()
		
		# 2. Sahneye ekle (Spawner'ın çocuğu olmasın, Marker'ın olsun ki konumu basit olsun)
		spawn_point.add_child(yeni_blok)
		yeni_blok.position = Vector3.ZERO # Marker'ın tam üstüne otursun
		
		# 3. Bloğa Grid'i tanıt ve Sinyalini dinle
		if yeni_blok is BlokSurukle:
			yeni_blok.grid = grid
			# Blok yerleştiğinde haberdar olmak için sinyale bağlan
			yeni_blok.blok_yerlesti.connect(_on_blok_yerlesti)

func _on_blok_yerlesti() -> void:
	aktif_blok_sayisi -= 1
	print("Kalan Blok: ", aktif_blok_sayisi)
	
	# Hepsi bittiyse yenilerini getir
	if aktif_blok_sayisi <= 0:
		await get_tree().create_timer(0.5).timeout # Yarım saniye nefes payı
		yeni_parti_dagit()
