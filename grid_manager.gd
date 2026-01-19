extends Node

# --- 🛠️ AYARLAR VE KALİBRASYON ---
# Masanın genişliği ve derinliği (Kare sayısı olarak)
@export var grid_genislik : int = 8 
@export var grid_derinlik : int = 8 

# Blokların Scale değeri (Senin projende 0.2)
@export var hucre_boyutu : float = 0.2 

# Masanın SOL ÜST köşesinin (0,0 karesinin) tam merkezi
# Senin verdiğin verilere göre hesaplanmış nokta:
@export var baslangic_offset : Vector3 = Vector3(-0.84, 0, -0.85)

# --- 🧠 HAFIZA ---
# Dolu kareleri tutan sözlük. Örnek: {(2,3): BlokObjesi}
var grid_haritasi = {} 

func _ready():
	# ⚡ OTOMATİK GRUP KAYDI ⚡
	# Bunu kodla yapıyoruz ki editörde unutulsa bile çalışsın.
	if not is_in_group("GridManager"):
		add_to_group("GridManager")
		
	gridi_sifirla()
	print("✅ GridManager Hazır! Grup: GridManager | Başlangıç: ", baslangic_offset)

func gridi_sifirla():
	grid_haritasi.clear()

# --- 📐 MATEMATİKSEL DÖNÜŞÜMLER ---

# 1. Dünya Koordinatını (Mouse'un tuttuğu yer) -> Grid Karesine (2, 3) çevirir
func world_to_grid(dunya_pozisyonu: Vector3) -> Vector2i:
	var fark = dunya_pozisyonu - baslangic_offset
	var x = round(fark.x / hucre_boyutu)
	var z = round(fark.z / hucre_boyutu)
	return Vector2i(int(x), int(z))

# 2. Grid Karesini (2, 3) -> Dünya Koordinatına (Masanın üstüne) çevirir
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var x = (grid_pos.x * hucre_boyutu) + baslangic_offset.x
	var z = (grid_pos.y * hucre_boyutu) + baslangic_offset.z
	# Yükseklik (Y) 0 döner, onu blok kendi ayarlar
	return Vector3(x, 0, z)

# --- 🚦 SORGULAMA VE KONTROL ---

# Bir blok buraya konulabilir mi?
func hucre_gecerli_mi(grid_pos: Vector2i) -> bool:
	# A) Sınır Kontrolü: Masa dışına taşıyor mu?
	if grid_pos.x < 0 or grid_pos.x >= grid_genislik:
		return false
	if grid_pos.y < 0 or grid_pos.y >= grid_derinlik:
		return false
	
	# B) Doluluk Kontrolü: Orada zaten taş var mı?
	if grid_haritasi.has(grid_pos):
		return false # Dolu!
		
	return true # Temiz, koyulabilir.

# --- 💾 KAYIT İŞLEMİ ---
# Bloğu sonsuza kadar oraya kaydeder
func hucreyi_doldur(grid_pos: Vector2i, blok_objesi):
	grid_haritasi[grid_pos] = blok_objesi
	print("🔒 Kare Kilitlendi: ", grid_pos)
