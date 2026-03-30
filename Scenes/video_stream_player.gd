extends VideoStreamPlayer

# 1. Video oynatıcıdan 3 kat yukarı çıkıyoruz (SubViewport -> SubViewportContainer -> tv)
# tv düğümünün hemen altındaki AudioStreamPlayer3'e ulaşıyoruz.
@onready var tv_audio_3d = $"../../../AudioStreamPlayer3" 

# 2. Yine 3 kat yukarı çıkıp tv düğümüne ulaşıyoruz, 
# oradan Sketchfab_model üzerinden ekrana gidiyoruz.
@onready var screen_mesh = $"../../../Sketchfab_model/TV_Textures_fbx/RootNode/Cube_001/Cube_001_tvsi"

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

	# 2. Görüntüyü Kod ile Materyale Atama (En önemli kısım)
	if screen_mesh and is_instance_valid(screen_mesh) and my_viewport:
		# Mesh'in materyalini al
		var mat = screen_mesh.get_active_material(0)
		
		# Eğer materyal yoksa yeni bir tane oluştur (Kritik bir ihtimal)
		if not mat:
			mat = StandardMaterial3D.new()
			screen_mesh.set_surface_override_material(0, mat)
			
		# Kod ile bir ViewportTexture oluştur
		var viewport_tex = ViewportTexture.new()
		viewport_tex.viewport_path = my_viewport.get_path()
		
		# Doku ve Işıma (Emission) özelliklerini atıyoruz
		mat.albedo_texture = viewport_tex # Görüntü
		if mat is StandardMaterial3D:
			mat.emission_enabled = true # Işıma aç
			mat.emission_texture = viewport_tex # Işıma dokusu aynı video
			mat.emission_energy_multiplier = 2.0 # Işık şiddeti
			
		print("Görüntü kod ile materyale zorla atandı!")
	else:
		printerr("HATA: Cube_001_tvsi yolu yanlış veya Viewport bulunamadı!")

	# 3. Videoyu Oynat
	play()
