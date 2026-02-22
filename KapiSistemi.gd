extends Node3D

# --- SİNYALLER ---
signal kapi_acildi

# --- AYARLAR ---
# MARKET ve CAMPFIRE sadece kilitleme mantığı için var, ışınlanma için değil.
enum HedefTipi { SADECE_ACIL, SONRAKI_LEVEL, MARKET, CAMPFIRE }
@export var hedef_tipi: HedefTipi = HedefTipi.SADECE_ACIL

@export var kapi_isigi: SpotLight3D 
@export var gecit_efektleri: Node3D 
@export var kilitli_olsun_mu: bool = false 

var kilitli_mi: bool = false
var acik_mi: bool = false
var oyuncu_gecti_mi: bool = false

func _ready():
	if kilitli_olsun_mu:
		kilitle()
	# Body Entered sinyalini bağla (varsa)
	_gecisin_sensorunu_bagla()

func _gecisin_sensorunu_bagla():
	# Eğer bu kapı sisteminde Area3D varsa body_entered bağla
	for child in get_children():
		if child is StaticBody3D:
			# StaticBody3D'ye input event alan versiyonu zaten var
			pass
	# Geciş algılama için kapı önünde Area3D oluştur
	var gecis_area = Area3D.new()
	gecis_area.name = "GecisAlgila"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 3.0, 1.5)
	col.shape = shape
	# Z ofsetini odanın bayağı içine taşıyoruz ki kapıya değince hemen kapanmasın
	col.position = Vector3(0, 0, -2.5)
	gecis_area.add_child(col)
	gecis_area.collision_layer = 0
	gecis_area.collision_mask = 1  # Oyuncu layerı
	add_child(gecis_area)
	gecis_area.body_entered.connect(_oyuncu_gecti)

# --- AKSİYONLAR ---
func interact(_oyuncu):
	etkilesim()

func etkilesim():
	kapiyi_ac()

func kapiyi_ac():
	# 1. Kilit veya Açıklık Kontrolü
	if kilitli_mi:
		print("!!! BU KAPI KİLİTLENDİ !!!")
		return
	if acik_mi:
		return 

	# 2. Kapıyı Aç
	print(">>> KAPI AÇILIYOR... TİP: ", hedef_tipi)
	acik_mi = true
	kapi_acildi.emit() # Odaya haber ver (Diğer kapıyı kilitlesin diye)
	
	if gecit_efektleri:
		gecit_efektleri.visible = true
	
	# 3. Animasyon (Fiziksel Açılma)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees:y", 95.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if kapi_isigi:
		kapi_isigi.visible = true 
		tween.tween_property(kapi_isigi, "light_energy", 12.0, 1.0)
	
	# 4. ÖZEL DURUM: Sadece "SONRAKI LEVEL" kapısıysa sahneyi resetle
	if hedef_tipi == HedefTipi.SONRAKI_LEVEL:
		await get_tree().create_timer(1.0).timeout
		LevelManager.odaya_don_ve_level_atla()
	
	# DİKKAT: Market ve Campfire için hiçbir şey yapmıyoruz. 
	# Kapı açıldı, oyuncu yürüyerek içeri girecek.

func _oyuncu_gecti(body):
	# Oyuncu kapıdan geçince kapıyı kapat ve kilitle
	if oyuncu_gecti_mi: return
	if not body.is_in_group("Oyuncu"): return
	if not acik_mi: return
	oyuncu_gecti_mi = true
	# Kapıyı geri kapat (y=0 konumuna dön)
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if kapi_isigi:
		tween.tween_property(kapi_isigi, "light_energy", 0.0, 0.5)
		tween.tween_callback(func(): kapi_isigi.visible = false)
	tween.tween_callback(func():
		acik_mi = false
		kilitli_mi = true  # Artık açılamaz
		print("🔐 Kapı geçiş sonra kilitlendi.")
	)

func kilitle():
	if acik_mi: return 
	kilitli_mi = true
	if kapi_isigi:
		kapi_isigi.visible = false
		kapi_isigi.light_energy = 0

func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kapiyi_ac()
