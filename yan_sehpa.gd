extends Node3D

@onready var slotlar_node = $Slotlar
var dolu_slot_sayisi = 0

func _ready():
	# 1. Başlangıçta ne varsa yükle
	envanteri_yukle(GameManager.envanter)
	
	# 2. GameManager'ı dinlemeye başla (CANLI BAĞLANTI)
	# Eğer GameManager "envanter_guncellendi" derse, "tazele" fonksiyonunu çalıştır.
	GameManager.envanter_guncellendi.connect(tazele)

# Sinyal gelince çalışacak fonksiyon
func tazele():
	print("Sehpa güncelleniyor...")
	envanteri_yukle(GameManager.envanter)

# (Geri kalan kodlar: temizle, esya_ekle_gorsel, envanteri_yukle vs. AYNEN KALSIN)
# Sadece envanteri_yukl

func temizle():
	dolu_slot_sayisi = 0
	if slotlar_node:
		for marker in slotlar_node.get_children():
			for cocuk in marker.get_children():
				cocuk.queue_free()

func esya_ekle_gorsel(item_data: ItemData):
	if not slotlar_node: return
	var slotlar = slotlar_node.get_children()
	
	if dolu_slot_sayisi < slotlar.size():
		var hedef_marker = slotlar[dolu_slot_sayisi]
		gorseli_olustur(hedef_marker, item_data)
		dolu_slot_sayisi += 1
	else:
		print("Sehpa doldu!")

func envanteri_yukle(liste: Array):
	temizle()
	if not slotlar_node: return
	var slotlar = slotlar_node.get_children()
	
	for i in range(min(liste.size(), slotlar.size())):
		gorseli_olustur(slotlar[i], liste[i])
		dolu_slot_sayisi += 1

func gorseli_olustur(marker, data):
	var sprite = Sprite3D.new()
	sprite.texture = data.ikon 
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED 
	sprite.pixel_size = 0.005 
	
	marker.add_child(sprite)
	
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector3(1, 1, 1), 0.3).set_trans(Tween.TRANS_BACK)
