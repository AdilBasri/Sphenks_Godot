extends VideoStreamPlayer

@onready var tv_audio_3d = $"../../AudioStreamPlayer3D" # AudioStreamPlayer3D'nin yolu

func _ready():
	# Videonun sesini 3D hoparlöre yönlendiriyoruz
	# Not: Bazı Godot sürümlerinde bu otomatik bağlanabilir ama garanti yol budur:
	set_audio_track(0) 
	# Eğer video başlar başlamaz ses gelmezse, bus ayarlarını kontrol etmelisin.
