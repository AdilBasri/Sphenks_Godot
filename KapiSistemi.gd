extends Node3D

# --- SİNYALLER ---
signal kapi_acildi

# --- AYARLAR ---
enum HedefTipi { SADECE_ACIL, SONRAKI_LEVEL, MARKET, CAMPFIRE }
@export var hedef_tipi: HedefTipi = HedefTipi.SADECE_ACIL

@export var kapi_isigi: SpotLight3D 
@export var gecit_efektleri: Node3D 
@export var kilitli_olsun_mu: bool = false 

var kilitli_mi: bool = false
var acik_mi: bool = false

func _ready():
	if kilitli_olsun_mu:
		kilitle()

# --- AKSİYONLAR ---
func etkilesim():
	kapiyi_ac()

func kapiyi_ac():
	if kilitli_mi:
		print("!!! BU KAPI KİLİTLENDİ, AÇILAMAZ !!!")
		return
		
	if acik_mi:
		return 

	print(">>> KAPI AÇILIYOR... HEDEF: ", hedef_tipi)
	acik_mi = true
	kapi_acildi.emit()
	
	if gecit_efektleri:
		gecit_efektleri.visible = true
	
	# Animasyon
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees:y", 95.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if kapi_isigi:
		kapi_isigi.visible = true 
		kapi_isigi.light_energy = 0 
		tween.tween_property(kapi_isigi, "light_energy", 12.0, 2.0)
	
	# --- SAHNE GEÇİŞİ ---
	# Kapı açıldıktan biraz sonra geçiş yapsın (Animasyonu görelim)
	if hedef_tipi != HedefTipi.SADECE_ACIL:
		await get_tree().create_timer(1.5).timeout
		_gecis_yap()

func _gecis_yap():
	match hedef_tipi:
		HedefTipi.SONRAKI_LEVEL:
			LevelManager.sonraki_seviyeye_gec()
		HedefTipi.MARKET:
			LevelManager.markete_git()
		HedefTipi.CAMPFIRE:
			LevelManager.campfire_git()

func kilitle():
	if acik_mi: return 
	kilitli_mi = true
	if kapi_isigi:
		kapi_isigi.visible = false
		kapi_isigi.light_energy = 0

func _on_static_body_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kapiyi_ac()
