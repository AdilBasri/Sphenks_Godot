extends Node3D

@export var kapi_isigi: SpotLight3D 
@export var gecit_efektleri: Node3D # <--- YENİ: Gizlediğimiz o grup

func kapiyi_ac():
	print(">>> KAPI SİSTEMİ ÇALIŞTI <<<")
	
	# 1. ÖNCE EFEKTLERİ GÖRÜNÜR YAP (Sürpriz!)
	if gecit_efektleri:
		gecit_efektleri.visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 2. Kapıyı Döndür (Menteşeden)
	# (Senin ayarına göre 95 veya -95)
	tween.tween_property(self, "rotation_degrees:y", 95.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 3. Işığı Yak
	if kapi_isigi:
		kapi_isigi.visible = true # Işığı da burada açıyoruz
		kapi_isigi.light_energy = 0 
		tween.tween_property(kapi_isigi, "light_energy", 12.0, 2.0)
