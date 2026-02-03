extends StaticBody3D

@export var esya_verisi: ItemData 

# Sahnedeki düğümü bulmaya çalışıyoruz
@onready var gorsel_sprite = $Gorsel 

func _ready():
	# Gorsel düğümü var mı diye kontrol et (Çökmemesi için)
	if not gorsel_sprite:
		print("HATA: '" + name + "' sahnesinde 'Gorsel' isminde bir Sprite3D bulunamadı!")
		return # İşlemi durdur
	
	if esya_verisi:
		veriyi_yukle()
	else:
		print("UYARI: " + name + " üzerinde ItemData (esya_verisi) atanmamış!")

func veriyi_yukle():
	# Verideki resmi alıp sahnedeki Sprite3D'ye yapıştır
	if esya_verisi.ikon:
		gorsel_sprite.texture = esya_verisi.ikon
		# Şeffaflık ayarı (Bazen resimler bulanık veya hatalı görünebilir, bunu fixler)
		gorsel_sprite.transparent = true 
	
	print(esya_verisi.esya_adi + " hazır. Fiyat: " + str(esya_verisi.fiyat))

func etkilesime_gir():
	if esya_verisi:
		print("Oyuncu tıkladı: " + esya_verisi.esya_adi)
		# Buraya satın alma sinyali gelecek
