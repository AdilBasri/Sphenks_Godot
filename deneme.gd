extends Node3D

@onready var arayuz = get_node_or_null("Revolver")
@onready var silah = get_node_or_null("Oyuncu/Camera3D/Sketchfab_Scene")

var mermi_label: Label = null

func _ready() -> void:
	# Ekranda istenmeyen UI parçalarını gizle
	if arayuz:
		var gizlenecekler = ["KatmanLabel", "AnaKontrol", "ParsomenPanel", "PyroFiltresi"]
		for ism in gizlenecekler:
			var n = arayuz.get_node_or_null(ism)
			if n:
				n.hide()
		
		# Mermi Label'ini bul ve bağla
		mermi_label = arayuz.get_node_or_null("MermiKonteyner/HBoxContainer/MermiSayisi")
		if mermi_label:
			if not GameManager.mermi_degisti.is_connected(_on_mermi_degisti):
				GameManager.mermi_degisti.connect(_on_mermi_degisti)
			_on_mermi_degisti(GameManager.mermi_sayisi)

func _on_mermi_degisti(yeni_sayi: int) -> void:
	if is_instance_valid(mermi_label):
		mermi_label.text = str(yeni_sayi) + "/" + str(GameManager.max_mermi)
