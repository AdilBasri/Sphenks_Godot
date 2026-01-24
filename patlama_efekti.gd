extends GPUParticles3D

func _ready() -> void:
	emitting = true # Sahneye girer girmez patla
	
	# İşin bitince (bütün parçalar kaybolunca) kendini yok et
	finished.connect(queue_free)
