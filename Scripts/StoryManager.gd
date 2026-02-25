extends Node

# --- KAYITLI VERİLER ---
var sleep_count: int = 0
var total_limbs_eaten: int = 0

# --- SABİTLER ---
const ENDING_ENDLESS_CANNIBAL = "Cannibal"
const ENDING_TRUE_ATONEMENT = "Atonement"
const CANNIBAL_THRESHOLD = 5 # Kaç uzuv yerse kötü son?

func _ready():
	print("📜 StoryManager Başlatıldı.")

func get_next_dream_scene() -> String:
	"""Uyku sayısına göre sıradaki rüya sahnesini döndürür."""
	match sleep_count:
		0: return "res://Dream_TreasureChase.tscn"
		1: return "res://Dream_GoreHallway.tscn" # Henüz yoksa placeholder dönebilir
		_: 
			# Varsayılan: Sonraki level veya rastgele rüya
			return "res://Sphenks_Lvl_2.tscn" # Örnek

func check_ending_condition() -> String:
	"""Oyun sonu geldiğinde hangi sonun oynayacağını belirler."""
	if total_limbs_eaten >= CANNIBAL_THRESHOLD:
		return ENDING_ENDLESS_CANNIBAL
	return ENDING_TRUE_ATONEMENT

func record_sleep():
	sleep_count += 1
	print("💤 Uyku Sayısı Arttı: %d" % sleep_count)

func record_limb_eaten():
	total_limbs_eaten += 1
	print("🍖 Toplam Yenen Uzuv: %d" % total_limbs_eaten)
