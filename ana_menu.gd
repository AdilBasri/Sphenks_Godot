extends Control

# DÜZELTME: Dosya yolunu tırnak içine aldık.
# Sphenks.tscn dosyasının tam olarak nerede olduğuna dikkat et (res:// veya res://Scenes/ altında mı?)
# Eğer direkt ana klasördeyse bu çalışır:
var oyun_sahnesi_yolu = "res://Sphenks.tscn" 

func _ready():
	# Butonları kodla bağlıyoruz.
	# Eğer senin sahne ağacında butonların yeri farklıysa (örneğin VBoxContainer yoksa)
	# $VBoxContainer kısmını silip direkt $OynaButonu yazabilirsin.
	
	if has_node("VBoxContainer/OynaButonu"):
		$VBoxContainer/OynaButonu.pressed.connect(_on_oyna_pressed)
	
	if has_node("VBoxContainer/CikisButonu"):
		$VBoxContainer/CikisButonu.pressed.connect(_on_cikis_pressed)

func _on_oyna_pressed():
	print("Oyun Başlıyor...")
	
	# Sahne değiştirme kodu (Değişkene atadığımız yolu kullanıyoruz)
	get_tree().change_scene_to_file(oyun_sahnesi_yolu)

func _on_cikis_pressed():
	print("Çıkılıyor...")
	get_tree().quit()
