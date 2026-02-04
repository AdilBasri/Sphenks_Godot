extends RigidBody3D

signal zar_durdu(sonuc) # Zar durunca bu sinyali yayacak

var atildi_mi: bool = false
var durdu_mu: bool = false
var hareket_hizi_limiti = 0.1 # Zarın hızı bunun altına düşerse durmuş sayacağız

func _ready():
	# --- TEST AMAÇLI OTOMATİK FIRLATMA ---
	# Boss mekaniğini yapınca burayı sileriz.
	print("Zar sahnede! 3 saniye sonra test için fırlatılacak...")
	await get_tree().create_timer(3.0).timeout
	
	# Rastgele bir yöne fırlat
	var firlatma_yonu = Vector3(0, 10, -5) 
	var donme_torku = Vector3(randf()*20, randf()*20, randf()*20) 
	
	firlat(firlatma_yonu, donme_torku)

func firlat(yon_ve_guc: Vector3, tork: Vector3):
	print("🎲 Zar Fırlatıldı!")
	atildi_mi = true
	durdu_mu = false
	sleeping = false # Fiziği uyandır
	freeze = false   # Donmuşsa çöz
	
	linear_velocity = yon_ve_guc
	angular_velocity = tork # Dönme hareketi

func _physics_process(delta):
	if not atildi_mi or durdu_mu: return
	
	# Hızımız çok azaldıysa ve dönmemiz bittiyse "Durduk" diyelim
	if linear_velocity.length() < hareket_hizi_limiti and angular_velocity.length() < hareket_hizi_limiti:
		durdu_mu = true
		sleeping = true # Fiziği uyut (Performans için)
		
		var gelen_sayi = sonucu_hesapla()
		print("✅ Zar Durdu! Gelen Sayı: ", gelen_sayi)
		
		# Sinyali gönder (Oyun mantığı bunu dinleyecek)
		zar_durdu.emit(gelen_sayi)

func sonucu_hesapla() -> int:
	# Zarın o anki yerel yön vektörlerini alıyoruz
	var yukarı_vektor = transform.basis.y 
	var on_vektor = transform.basis.z
	var sag_vektor = transform.basis.x
	
	var en_buyuk_dot = -1.0
	var sonuc = 1 
	
	# SENİN KALİBRASYONUNA GÖRE AYARLANMIŞ HARİTA:
	# Anahtar (Sol taraf) = Zarın üzerindeki sayı
	# Değer (Sağ taraf) = O sayı yukarıdayken hangi eksenin yukarı baktığı
	var yuzler = {
		4: yukarı_vektor,   # Tavan (+Y) yukarıdayken 4
		3: -yukarı_vektor,  # Taban (-Y) yukarıdayken 3
		2: on_vektor,       # Ön (+Z) yukarıdayken 2
		5: -on_vektor,      # Arka (-Z) yukarıdayken 5
		6: sag_vektor,      # Sağ (+X) yukarıdayken 6
		1: -sag_vektor      # Sol (-X) yukarıdayken 1
	}
	
	# Hangi yüzey Dünya'nın YUKARI (Gökyüzü) yönüne bakıyor?
	for sayi in yuzler:
		var vektor = yuzler[sayi]
		# Vektörlerin hizasını kontrol et (1.0 = Tam yukarı bakıyor demek)
		var dot = vektor.dot(Vector3.UP) 
		
		if dot > en_buyuk_dot:
			en_buyuk_dot = dot
			sonuc = sayi
			
	return sonuc
