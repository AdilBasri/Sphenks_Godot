extends Node3D

# --- SAHNE REFERANSLARI ---
# Bu isimlerin sahnedeki düğüm isimleriyle BİREBİR aynı olduğundan emin ol.
@onready var grid: GridYonetici = $GridYoneticisi
@onready var spawner: Node3D = $BlokDagiticisi
@onready var oyuncu: CharacterBody3D = $Oyuncu 

# --- DEĞİŞKENLER ---
var oyun_modu: bool = false # False = Yürüme Modu, True = Oyun (Grid) Modu

func _ready() -> void:
	# Oyun başlarken Yürüyüş modundayız
	print("Oyun Başladı: Yürüyüş Modu")
	
	# Blokları gizle (Void içinde beklesinler)
	if spawner.has_method("bloklari_gizle"):
		spawner.bloklari_gizle()
	
	# Oyuncu yürüyebilsin
	oyuncu.set_physics_process(true)

func _input(event: InputEvent) -> void:
	# SPACE tuşuna basınca mod değiştir
	if event.is_action_pressed("ui_accept"): 
		state_degistir()

func state_degistir() -> void:
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
	var merkez = grid.global_position
	var oyuncu_pos = oyuncu.global_position
	oyuncu_pos.y = merkez.y
	
	spawner.global_position = merkez
	spawner.look_at(oyuncu_pos, Vector3.UP)
	
	# --- DÜZELTME ---
	# Eğer blokların "arkası" dönükse veya hitbox tutmuyorsa, 
	# bu 180 derece dönüşü İPTAL ET veya EKLE.
	# Önceki kodda eklemiştik, şimdi KALDIRIYORUZ (veya tam tersi).
	# Deneme-Yanılma ile doğrusunu bulacağız ama mantıken look_at
	# -Z eksenini çevirir. Blokların önü +Z ise, arkası sana döner.
	# O yüzden 180 derece dönüş ŞARTTIR. Ama belki de "daha önce" tersti.
	
	# ŞU ANKİ ÖNERİM: Bu satırı KULLAN (Aktif et).
	spawner.rotate_y(deg_to_rad(180)) 
	
	# EĞER HALA TERS İSE: Yukarıdaki satırı silip yerine şunu yaz:
	# spawner.rotation.y = spawner.rotation.y # (Yani hiçbir şey yapma)
	
	var rot_y = spawner.rotation_degrees.y
	spawner.rotation_degrees.y = round(rot_y / 90.0) * 90.0
