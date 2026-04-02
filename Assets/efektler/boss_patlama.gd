extends GPUParticles3D

func _ready():
	# Sahneye girer girmez patla
	emitting = true
	
	# İşin bitince (bütün parçalar kaybolunca) kendini yok et
	finished.connect(queue_free)

func ayarla_renk(_renk: Color):
	# User wanted default colors (same as blocks), so we ignore the color assignment
	pass
