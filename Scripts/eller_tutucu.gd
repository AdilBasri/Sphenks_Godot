extends Node3D

var hassasiyet = 0.005 # Dönüş hızı

func _input(event):
	# Eğer fare hareket ediyorsa ve sol tuşa basılıysa (veya inceleme modundaysak)
	# Şimdilik sadece fare hareketine bağlıyorum, duruma göre tuş şartı ekleriz.
	if event is InputEventMouseMotion:
		# Y ekseninde dönüş (Sağa sola bakma)
		rotate_y(event.relative.x * hassasiyet)
		# X ekseninde dönüş (Yukarı aşağı bakma)
		# Kolların ters dönmemesi için açıyı kısıtlayabiliriz (clamp)
		rotate_x(event.relative.y * hassasiyet)

		# Açıyı biraz kısıtlayalım ki eller 360 derece dönüp kırılmasın
		rotation.x = clamp(rotation.x, deg_to_rad(-45), deg_to_rad(45))
		rotation.y = clamp(rotation.y, deg_to_rad(-60), deg_to_rad(60))
