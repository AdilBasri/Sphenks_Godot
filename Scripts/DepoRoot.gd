extends Node3D

func _ready() -> void:
	# Depo sahnesi yüklendiğinde çalışacak kodlar
	var dog = $dog
	if dog:
		# 1. Animasyonu Döngüye Al ve Oynat
		var anim_player = dog.get_node_or_null("AnimationPlayer")
		if anim_player:
			if anim_player.has_animation("barking"):
				var anim = anim_player.get_animation("barking")
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				anim_player.play("barking")
			else:
				anim_player.play("barking") # Belki uzantısı farklıdır, şansımızı deneyelim
				print("Uyarı: 'barking' animasyonu bulunamadı. Mevcut animasyonlar: ", anim_player.get_animation_list())
		
		# 2. 3D Ses Oynatıcı Oluştur ve Köpeğe Ekle
		var audio = AudioStreamPlayer3D.new()
		var stream_audio = load("res://Sesler/dog.mp3")
		if stream_audio is AudioStreamMP3:
			stream_audio.loop = true
		audio.stream = stream_audio
		
		audio.unit_size = 5.0 # Sesin duyulma şiddeti/yarıçapı
		audio.max_distance = 40.0 # Sesin ulaşabileceği max mesafe
		audio.autoplay = true
		audio.bus = "Master"
		
		# Sesi köpeğin içine ekliyoruz ki konumu köpeğin konumu olsun
		dog.add_child(audio)
		audio.play()
