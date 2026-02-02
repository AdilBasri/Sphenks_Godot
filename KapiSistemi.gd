extends Node3D

# --- SİNYALLER ---
# Bu sinyal, Odanın (CatalOdasi) duyması için var.
signal kapi_acildi

# --- DEĞİŞKENLER ---
@export var kapi_isigi: SpotLight3D 
@export var gecit_efektleri: Node3D # Level 1'deki o özel efektler için
@export var kilitli_olsun_mu: bool = false # Editörden "True" yaparsan kapı baştan kilitli başlar

var kilitli_mi: bool = false
var acik_mi: bool = false

func _ready():
	# Eğer editörden kilitli işaretlediysek, kilidi aktif et
	if kilitli_olsun_mu:
		kilitle()

# --- AKSİYONLAR ---

# Bu fonksiyonu Raycast veya Mouse Tıklaması çağıracak
func etkilesim():
	kapiyi_ac()

func kapiyi_ac():
	# 1. KONTROL: Kapı kilitli mi veya zaten açık mı?
	if kilitli_mi:
		print("!!! BU KAPI KİLİTLENDİ, AÇILAMAZ !!!")
		# Buraya "Zincir Sesi" veya "Kilit Zorlama Sesi" ekleyebilirsin
		return
		
	if acik_mi:
		return # Zaten açık, tekrar animasyon oynatma

	# 2. DURUMU GÜNCELLE
	print(">>> KAPI SİSTEMİ ÇALIŞTI: AÇILIYOR <<<")
	acik_mi = true
	
	# Odaya haber ver: "Hey, ben açıldım! Diğerini kilitle!"
	kapi_acildi.emit()
	
	# 3. LEVEL 1 EFEKTLERİ (Varsa çalışır, yoksa hata vermez)
	if gecit_efektleri:
		gecit_efektleri.visible = true
	
	# 4. ANİMASYON (Senin yazdığın kodun aynısı)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Kapıyı Döndür
	tween.tween_property(self, "rotation_degrees:y", 95.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Işığı Yak (Eğer ışık takılıysa)
	if kapi_isigi:
		kapi_isigi.visible = true 
		kapi_isigi.light_energy = 0 
		tween.tween_property(kapi_isigi, "light_energy", 12.0, 2.0)

# --- YENİ ÖZELLİK: KİLİTLEME ---
func kilitle():
	if acik_mi: return # Açık kapıyı kilitleyemeyiz
	
	kilitli_mi = true
	print(name + " KİLİTLENDİ! Artık açılamaz.")
	
	# Görsel Geri Bildirim: Işığı varsa söndürelim ki oyuncu anlasın
	if kapi_isigi:
		kapi_isigi.visible = false
		kapi_isigi.light_energy = 0


# Bu fonksiyon ismini Godot otomatik oluşturmuş olabilir,
# önemli olan içeriğindeki kontrol ve "kapiyi_ac()" çağrısıdır.
func _on_static_body_3d_input_event(camera, event, position, normal, shape_idx):
	# Sadece SOL TIK basıldığında çalışsın (Mouse üzerine gelince değil)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kapiyi_ac()
