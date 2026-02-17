extends Node3D

signal saldiri_tamamlandi

@onready var anim_player = $AnimationPlayer
@onready var kamera_boss = $Camera3D 

var suanki_durum = "BASLANGIC" # BASLANGIC, UYUKLAMA, AYAKTA
var oldu_mu : bool = false

func _ready():
	add_to_group("Dusman")
	# Bölüm başladıktan 1 saniye sonra otur ve uyu
	await get_tree().create_timer(1.0).timeout
	otura_gec()

func otura_gec():
	if oldu_mu: return
	
	if anim_player.has_animation("CanavarOturma"):
		anim_player.play("CanavarOturma")
		await anim_player.animation_finished
		print("🛋️ Canavar tabureye oturdu.")
	
	uyuklamaya_basla()

func uyuklamaya_basla():
	if oldu_mu: return
	suanki_durum = "UYUKLAMA"
	
	if anim_player.has_animation("CanavarUyuklama"):
		anim_player.play("CanavarUyuklama")
		print("💤 Canavar uyuklamaya başladı.")
	else:
		print("⚠️ UYARI: CanavarUyuklama animasyonu bulunamadı!")

func saldiri_baslat():
	if oldu_mu: 
		saldiri_tamamlandi.emit()
		return

	# 1. Kamera Odağı: Boss kamerasını aktif et
	if kamera_boss:
		kamera_boss.make_current()
		print("🎥 Kamera Boss'a odaklandı.")
	
	# 2. Uyanış: Eğer uyuyorsa ayağa kalk (Oturma animasyonu TERSTEN)
	if suanki_durum == "UYUKLAMA":
		if anim_player.has_animation("CanavarOturma"):
			# Animasyonu -1 hızıyla (tersten) ve sona yakın bir yerden başlatarak ayağa kalkma yapıyoruz
			anim_player.play("CanavarOturma", -1, -1.0, true) 
			await anim_player.animation_finished
			print("🗯️ Canavar uyandı ve ayağa kalktı!")
		else:
			print("⚠️ UYARI: Ayağa kalkmak için CanavarOturma bulunamadı.")
		
	suanki_durum = "AYAKTA"
	await get_tree().create_timer(1.0).timeout # 1 saniye ayakta bekle
	
	# 3. Saldırı Aksiyonu
	_rastgele_atak_yap()

func _rastgele_atak_yap():
	if oldu_mu: 
		_sirayi_bitir_ve_tekrar_otur()
		return
	
	print("⚔️ Boss Saldırısı Seçiliyor...")
	var sans = randf()
	
	if sans < 0.35:
		_asit_veya_tas_at("ASIT")
	elif sans < 0.70:
		_asit_veya_tas_at("TAS")
	else:
		_zar_sekansi()

func _asit_veya_tas_at(tip: String):
	print("🔥 Boss saldırısı: ", tip)
	# Burada mermi fırlatma efektlerini çağırabilirsin
	await get_tree().create_timer(1.5).timeout 
	_sirayi_bitir_ve_tekrar_otur()

func _zar_sekansi():
	if LevelManager.has_method("zar_at_animasyonunu_baslat"):
		LevelManager.zar_at_animasyonunu_baslat()
		# Zar sekansı bittikten sonra LevelManager oyuncu kamerasını geri verecektir.
	else:
		_sirayi_bitir_ve_tekrar_otur()

func _sirayi_bitir_ve_tekrar_otur():
	# Kamerayı oyuncuya iade et
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu:
		var cam = oyuncu.find_child("Camera3D", true, false)
		if cam: cam.make_current()

	# Canavarı geri oturt
	otura_gec()
	saldiri_tamamlandi.emit()
