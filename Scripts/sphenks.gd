extends Node3D

# --- SAHNE REFERANSLARI ---
# GÜNCELLEME: Grid artık "TumMasaSistemi" içinde olduğu için yolunu düzelttik.
# Eğer sahnedeki kutunun adı farklıysa (örn: MasaGrubu), aşağıdaki "TumMasaSistemi" ismini ona göre değiştir.
@onready var grid: GridYonetici = $TumMasaSistemi/GridYoneticisi
@onready var spawner: Node3D = $TumMasaSistemi/BlokDagiticisi
@onready var oyuncu: CharacterBody3D = $Oyuncu 

# --- DEĞİŞKENLER ---
var oyun_modu: bool = false # False = Yürüme Modu, True = Oyun (Grid) Modu

func _ready() -> void:
	# Güvenlik Kontrolü: Grid bulundu mu?
	if not grid:
		print("!!! HATA: GridYoneticisi bulunamadı! Yolunu kontrol et: $TumMasaSistemi/GridYoneticisi")
		return

	# Oyun başlarken Yürüyüş modundayız
	print("Oyun Başladı: Yürüyüş Modu")
	
	# Blokları gizle (Void içinde beklesinler)
	if spawner and spawner.has_method("bloklari_gizle"):
		spawner.bloklari_gizle()
	
	# Oyuncu yürüyebilsinn
	if oyuncu:
		oyuncu.set_physics_process(true)

#func _input(event: InputEvent) -> void:
#	# SPACE tuşuna basınca mod değiştir
#	if event.is_action_pressed("ui_accept"): 
#		state_degistir()

func state_degistir() -> void:
	# Güvenlik: Eğer gerekli parçalar yoksa modu değiştirme
	if not grid or not spawner or not oyuncu:
		print("!!! HATA: Sahne bağlantıları eksik, mod değiştirilemiyor.")
		return

	oyun_modu = !oyun_modu
	
	if oyun_modu:
		# --- OYUN MODUNA GEÇİŞ (MASAYA OTURMA) ---
		print("Mod Değişti: OYUN (Grid)")
		
		# 1. Oyuncuyu dondur (Yürüyemesin)
		oyuncu.set_physics_process(false)
		
		# 2. Spawner'ı Oyuncunun olduğu açıya taşı ve döndür
		_spawneri_hizala()
		
		# 3. Blokları Animasyonla Çıkar
		if spawner.has_method("bloklari_goster"):
			spawner.bloklari_goster()
		
	else:
		# --- YÜRÜYÜŞ MODUNA GEÇİŞ ---
		print("Mod Değişti: YÜRÜYÜŞ")
		
		# 1. Blokları Sakla (Void'e geri dönsünler)
		if spawner.has_method("bloklari_gizle"):
			spawner.bloklari_gizle()
		
		# 2. Oyuncuyu çöz (Yürüyebilsin)
		oyuncu.set_physics_process(true)

func _spawneri_hizala() -> void:
	# CRASH ENGELLEYİCİ: Grid yoksa işlemi durdur
	if not grid:
		print("HATA: Grid yok, hizalama yapılamadı!")
		return
		
	var merkez = grid.global_position
	var oyuncu_pos = oyuncu.global_position
	oyuncu_pos.y = merkez.y
	
	spawner.global_position = merkez
	spawner.look_at(oyuncu_pos, Vector3.UP)
	
	# --- HİZALAMA ---
	# Blokların yüzü oyuncuya dönsün diye 180 derece çeviriyoruz.
	spawner.rotate_y(deg_to_rad(180)) 
	
	# Açıyı 90 derecelik ızgaraya oturt (Snap)
	var rot_y = spawner.rotation_degrees.y
	spawner.rotation_degrees.y = round(rot_y / 90.0) * 90.0
