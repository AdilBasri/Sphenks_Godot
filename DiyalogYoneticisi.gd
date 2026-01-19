extends CanvasLayer

@onready var metin_kutusu = $Panel/KonusmaMetni
@onready var buton_kutusu = $Panel/VBoxContainer
@onready var panel = $Panel

# Diyalog Verileri
var diyaloglar = [
	{
		"id": 0,
		"text": "[shake rate=20 level=10]Seni aptal insan![/shake] Buraya gelmemeliydin.",
		"choices": ["Neden?", "Seni ilgilendirmez."]
	},
	{
		"id": 1,
		"text": "Sayamadığım kadar çok yıldır bu tünellerde iğrenç yaratıklar arasında geziyorum...",
		"choices": ["Devam Et"] 
	},
	{
		"id": 2,
		"text": "Merak etme, firavunun hazinesi için buradasın değil mi? Hehe...",
		"choices": ["Öyle bir şey mi var?", "Elbette!"]
	},
	{
		"id": 3,
		"text": "Para benim için çöp! Ama şanslısın, BANA sahipsin. Beni besle, ben de seni yaşatayım.",
		"choices": ["Tamam (Eğitimi Başlat)"]
	}
]

# İŞTE DÜZELTİLEN SATIR:
var su_anki_adim = 0

func _ready():
	panel.visible = false
	# buton_lari_gizle fonksiyonu olmadığı için sildim, zaten panel gizli başlıyor.

func diyalog_baslat():
	panel.visible = true
	adim_goster(0)

func adim_goster(index):
	su_anki_adim = index
	var veri = diyaloglar[index]
	
	metin_kutusu.text = veri["text"]
	metin_kutusu.visible_ratio = 0.0
	
	var tween = create_tween()
	tween.tween_property(metin_kutusu, "visible_ratio", 1.0, 2.0)
	
	tween.finished.connect(func(): secenekleri_goster(veri["choices"]))

func secenekleri_goster(secenekler):
	for child in buton_kutusu.get_children():
		child.queue_free()
		
	for secenek in secenekler:
		var btn = Button.new()
		btn.text = secenek
		buton_kutusu.add_child(btn)
		# Button sinyalini lambda fonksiyonla bağlıyoruz
		btn.pressed.connect(func(): secim_yapildi(secenek))

func secim_yapildi(secim):
	print("Seçilen: ", secim)
	
	if su_anki_adim < diyaloglar.size() - 1:
		adim_goster(su_anki_adim + 1)
	else:
		egitimi_baslat()

func egitimi_baslat():
	panel.visible = false
	print("MASA YÜKSELİYOR... OYUN BAŞLIYOR!")
	# Animasyon kodları buraya gelecek
