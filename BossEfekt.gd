extends Node3D

# --- GÖRSEL AYARLAR ---
@export_group("Görsel Efektler")
@export var suzulme_hizi : float = 2.0
@export var suzulme_mesafesi : float = 0.15
@export var nefes_hizi : float = 1.5
@export var nefes_miktari : float = 0.05 

# --- YAPAY ZEKA AYARLARI ---
@export_group("Utangaç Yapay Zeka")
@export var oyuncu: Node3D        
@export var masa_merkezi: Node3D  
@export var kacma_mesafesi: float = 2.5 
@export var kacma_hizi: float = 2.0      

var baslangic_y : float
var zaman : float = 0.0

# DÜZELTME: Tek bir float yerine, Vector3 olarak saklıyoruz.
var baslangic_scale : Vector3 

func _ready():
	baslangic_y = global_position.y
	
	# Editörde ayarladığın boyutu "Asıl Boyut" olarak hafızaya alıyoruz.
	baslangic_scale = scale 
	
	zaman = randf() * 10.0 

func _process(delta):
	zaman += delta
	
	# --- 1. UTANGAÇ HAREKET MANTIĞI ---
	if oyuncu and masa_merkezi:
		var merkez_pos = masa_merkezi.global_position
		var oyuncu_pos = oyuncu.global_position
		# Y eksenini sıfırlıyoruz ki havaya kalkmasın veya yere girmesin
		merkez_pos.y = 0
		oyuncu_pos.y = 0
		
		var oyuncu_yonu = (oyuncu_pos - merkez_pos).normalized()
		var kacis_yonu = -oyuncu_yonu # Oyuncunun tam tersi yön
		var hedef_nokta = masa_merkezi.global_position + (kacis_yonu * kacma_mesafesi)
		
		# Yumuşak geçiş (Lerp)
		var anlik_x = lerp(global_position.x, hedef_nokta.x, kacma_hizi * delta)
		var anlik_z = lerp(global_position.z, hedef_nokta.z, kacma_hizi * delta)
		
		global_position.x = anlik_x
		global_position.z = anlik_z
		
		# Her zaman masanın ortasına bak
		look_at(masa_merkezi.global_position, Vector3.UP)

	# --- 2. GÖRSEL EFEKTLER ---
	
	# Süzülme (Y ekseni)
	var yeni_y = baslangic_y + (sin(zaman * suzulme_hizi) * suzulme_mesafesi)
	global_position.y = lerp(global_position.y, yeni_y, 5.0 * delta)
	
	# Nefes Alma (Scale)
	var scale_degisimi = sin(zaman * nefes_hizi) * nefes_miktari
	
	scale = Vector3(
		baslangic_scale.x + scale_degisimi, 
		baslangic_scale.y - (scale_degisimi * 0.2), 
		baslangic_scale.z + scale_degisimi 
	)
