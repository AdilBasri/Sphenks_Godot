extends Node

# --- SİNYALLER ---
signal seviye_verisi_guncellendi

const SAVE_PATH = "user://level_data.save"

# level_data formatı:
# {
#   "1": {"unlocked": true, "stars": 0},
#   "2": {"unlocked": false, "stars": 0},
#   ...
# }
var level_data: Dictionary = {}

func _ready():
	# Başlangıçta minimum ilk seviyenin açık olması için varsayılan verileri hazırla.
	if not file_exists():
		_varsayilan_verileri_olustur()
	
	load_game()

func file_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _varsayilan_verileri_olustur():
	level_data.clear()
	# İlk 20 seviye (örneğin) için varsayılanları oluştur. İstediğiniz kadar olabilir.
	for i in range(1, 100):
		level_data[str(i)] = {
			"unlocked": (i == 1), # Sadece 1. Seviye baştan açık
			"stars": 0
		}
	save_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# JSON formatında kaydetmek, ilerde hem parse etmeyi hem de debug okumasını kolaylaştırır.
		var json_string = JSON.stringify(level_data)
		file.store_string(json_string)
		file.close()
		print("💾 SaveManager: Seviye verileri kaydedildi.")
	else:
		print("❌ SaveManager: Kayıt doyası açılamadı!")

func load_game():
	if not file_exists():
		print("📂 SaveManager: Kayıt dosyası bulunamadı, varsayılanlar oluşturuluyor.")
		_varsayilan_verileri_olustur()
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			level_data = json.data
			print("📂 SaveManager: Seviye verileri yüklendi.")
		else:
			print("❌ SaveManager: JSON parse hatası! Varsayılanlara dönülüyor...")
			_varsayilan_verileri_olustur()
		file.close()
	else:
		print("❌ SaveManager: Kayıt doyası okunamadı!")

func get_level_info(level_id: int) -> Dictionary:
	var key = str(level_id)
	if level_data.has(key):
		return level_data[key]
	
	# Eğer veri yoksa varsayılan döndür:
	var def_info = {"unlocked": (level_id == 1), "stars": 0}
	level_data[key] = def_info
	return def_info

func is_level_unlocked(level_id: int) -> bool:
	return get_level_info(level_id).get("unlocked", false)

func get_level_stars(level_id: int) -> int:
	return get_level_info(level_id).get("stars", 0)

func complete_level(level_id: int, stars: int):
	"""
	Bir seviye tamamlandığında çağrılıp o seviyenin yıldızını günceller.
	(Sadece eski yıldızdan yüksekse)
	Aynı zamanda bir sonraki seviyenin kilidini açar.
	"""
	var key = str(level_id)
	var info = get_level_info(level_id)
	
	var current_stars = info.get("stars", 0)
	if stars > current_stars:
		info["stars"] = stars
	
	level_data[key] = info
	
	# Bir sonraki seviyeyi aç
	var next_level_key = str(level_id + 1)
	var next_info = get_level_info(level_id + 1)
	next_info["unlocked"] = true
	level_data[next_level_key] = next_info
	
	emit_signal("seviye_verisi_guncellendi")
	save_game()
	print("🏆 SaveManager: Seviye %d tamamlandı (%d Yıldız). Seviye %d kilidi açıldı!" % [level_id, stars, level_id + 1])

func dosyalari_tamamen_sil():
	"""Bütün progres verilerini sıfırlar."""
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir.file_exists("level_data.save"):
			dir.remove("level_data.save")
	_varsayilan_verileri_olustur()
	emit_signal("seviye_verisi_guncellendi")
	print("🗑️ SaveManager: Bütün bölüm ilerleme verileri silindi.")
