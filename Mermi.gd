extends Area3D

var hiz = 40.0 
var yon = Vector3.ZERO
var omur = 3.0 

func baslat(yeni_yon: Vector3):
	yon = yeni_yon.normalized()
	look_at(global_position + yon) 

func _ready():
	# --- SİNYAL HATASI ÇÖZÜMÜ ---
	# Eğer sinyal zaten bağlıysa tekrar bağlamaya çalışma.
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# 3 saniye sonra yok olsun
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	global_position += yon * hiz * delta

# --- DUVALARA ÇARPMA ---
func _on_body_entered(body):
	if body is StaticBody3D or body is CSGShape3D:
		queue_free()

# --- DÜŞMAN UZUVLARINA ÇARPMA ---
func _on_area_entered(area):
	print("🎯 Çarpışma: ", area.name)
	
	# 1. Meta Verisi Kontrolü
	if area.has_meta("Bolge"): 
		var bolge_adi = area.get_meta("Bolge")
		print("   -> Bölge Tespit Edildi: ", bolge_adi)
		
		# 2. Düşman Scriptini Bulma (Garanti Yöntem)
		var dusman = _dusman_scriptini_bul(area)
		
		if dusman:
			print("   ✅ Düşman Bulundu! Hasar Veriliyor...")
			dusman.hasar_al_bolgesel(bolge_adi)
			queue_free() # Mermiyi yok et
		else:
			print("   ❌ HATA: Area'nın bağlı olduğu 'PyroDusman' scripti bulunamadı!")

# --- Mermi.gd İÇİNDEKİ FONKSİYONU BUNA GÜNCELLE ---

func _dusman_scriptini_bul(baslangic_node):
	var aday = baslangic_node
	# "root"a gelene kadar veya 15 kademe yukarı çıkana kadar ara
	var deneme_sayisi = 0
	
	while aday and deneme_sayisi < 15:
		# Scripti var mı ve doğru fonksiyonu taşıyor mu?
		if aday.has_method("hasar_al_bolgesel"):
			return aday
		
		# Bir üst ebeveyne geç
		aday = aday.get_parent()
		deneme_sayisi += 1
		
	return null
