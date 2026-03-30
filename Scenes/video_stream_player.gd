extends VideoStreamPlayer

# 1. Video oynatıcıdan 3 kat yukarı çıkıyoruz (SubViewport -> SubViewportContainer -> tv)
# tv düğümünün hemen altındaki AudioStreamPlayer3'e ulaşıyoruz.
@onready var tv_audio_3d = $"AudioStreamPlayer3D" 

# 2. Yine 3 kat yukarı çıkıp tv düğümüne ulaşıyoruz, 
# oradan Sketchfab_model üzerinden ekrana gidiyoruz.
@onready var screen_mesh = $"../../../Sketchfab_model/TV_Textures_fbx/RootNode/Cube_001/Cube_001_tvsimple_0"

# 3. Viewport bir üst katımızda (Burası doğruydu)
@onready var my_viewport = $".."

func _ready():
	# 1. Ses Bağlantısını Yap (Garantiye alalım)
	if tv_audio_3d and is_instance_valid(tv_audio_3d):
		set_audio_track(0) 
		# Bazı sürümlerde bu ses otomatik 3D'ye yönlenmeyebilir, 
		# Eğer hala kulaklıktan geliyorsa sesi kısıp 3D'den 'play' kodları yazabiliriz.
		print("Ses bağlantısı yolları okey.")
	else:
		printerr("HATA: AudioStreamPlayer3 yolu yanlış!")

	# Viewport'u kapla (Tam ekran garantiye alalım)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0

	# 2. Görüntüyü Kod ile Materyale Atama (En önemli kısım)
	if screen_mesh and is_instance_valid(screen_mesh) and my_viewport:
		# Mesh'in materyalini al
		var mat = screen_mesh.get_active_material(0)
		
		# Eğer materyal mevcutsa kopyasını (duplicate) alıyoruz (Unique olması için)
		if mat:
			mat = mat.duplicate()
		else:
			mat = StandardMaterial3D.new()

		# Yeni materyali yüzeye atıyoruz (Zorunlu)
		screen_mesh.set_surface_override_material(0, mat)
			
		# Kod ile ViewportTexture'u çekiyoruz (Godot 4'te en sağlam yöntem budur)
		var viewport_tex = my_viewport.get_texture()
		
		# Doku ve Işıma (Emission) özelliklerini atıyoruz
		if mat is StandardMaterial3D:
			mat.albedo_color = Color.BLACK # Beyaz ekranı engellemek için baz rengi siyah yapalım
			mat.albedo_texture = viewport_tex 
			mat.emission_enabled = true 
			mat.emission = Color.WHITE # Işıma rengi (Bu renk texture ile çarpılır)
			mat.emission_texture = viewport_tex 
			mat.emission_energy_multiplier = 1.2 # Şiddeti biraz daha kısalım parlamasın
			
		print("TEKNİK FIX: ViewportTexture materyale duplicate edilerek atandı!")
	else:
		printerr("HATA: Cube_001_tvsimple_0 yolu yanlış veya Viewport bulunamadı!")

	# 3. Videoyu Oynat
	play()
