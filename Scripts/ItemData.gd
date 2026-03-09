extends Resource
class_name ItemData

# String ID sistemi esneklik sağlar.
# ID Listesi: "asit", "kilic", "firca", "mantar", "serbet", "canlan", "mama", "kumsaati", "miknatis"
@export var etki_id: String = "" 

# Animasyon Tipi: "icme", "yeme", "kirma", "buyume", "cokme", "giyinme"
@export var animasyon_tipi: String = "icme"

@export var esya_adi: String = "Item Name"
@export_multiline var aciklama: String = "Description"
@export var fiyat: int = 10
@export var ikon: Texture2D 
@export var model_sahnesi: PackedScene
