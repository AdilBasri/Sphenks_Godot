extends Resource
class_name ItemData

enum TotemTuru {
	KEDI_MAMASI,   # Save
	REVIVE_IKSIR,  # Canlanma
	GUC_IKSIRI,    # Puan artışı
	ASIT_SISESI,   # Sütun silme
	KILIC,         # Tek blok kırma
	MIKNATIS,      # Yerçekimi düzeltme
	ZAR,           # Renk karıştırma
	PELERIN,       # Hasar almama
	KUMSAATI,      # Zaman durdurma
	FIRCA,         # Wildcard yapma
	KAZMA,         # Para kazanma
	FENER          # İpucu gösterme
}

@export var esya_adi: String = "Eşya İsmi"
@export_multiline var aciklama: String = "Açıklama"
@export var fiyat: int = 10
@export var ikon: Texture2D 
@export var tur: TotemTuru = TotemTuru.KEDI_MAMASI
