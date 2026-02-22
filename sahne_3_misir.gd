extends Node3D

@onready var oyuncu = $Oyuncu
@onready var alt_yazi = $UI/Label 
# EKLENEN 1: Geçiş Ekranına ulaşıyoruz
@onready var gecis_perdesi = $UI/GecisEkrani

# Kapı Alanları 
@onready var kapilar = [$Kapi_On, $Kapi_Arka, $Kapi_Sag, $Kapi_Sol]

var diyaloglar = [
	"Buraya kadar gelebileceğimi düşünmemiştim.",
	"Bunu tarikat için filan yapmıyorum, hayır.",
	"Zaten pek inançlı da sayılmam...",
	"Ama beni bu dünyadan biraz koparabilecek her şeye razıyım şuanda.",
	"Bu ziyaret de tam olarak bunu sağlıyor işte!",
	"İçeride nelerle karşılaşacağımı bilmiyorum.",
	"İnsanlar bunun tehlikeli olabileceğini söylüyor, uzaylı zırvaları filan!",
	"Görevimi tamamladıktan sonra belki...",
	"Bir süre daha buralarda vakit geçirebilirim..."
]

func _ready():
	# EKLENEN 2: SİYAH EKRANI YAVAŞÇA KALDIR (GÖZÜNÜ AÇMA EFEKTİ)
	acilis_efekti_yap()

	# Kapıların sinyallerini bağla
	for kapi in kapilar:
		if kapi: # Hata almamak için var mı diye kontrol et
			kapi.body_entered.connect(kapidan_giris)
	
	# Monoloğu başlat
	monolog_oynat()

func acilis_efekti_yap():
	if gecis_perdesi:
		# Önce ekranı simsiyah yap (Factor 1.0)
		gecis_perdesi.material.set_shader_parameter("factor", 1.0)
		
		# Sonra 3 saniye içinde yavaşça şeffaflaştır (Factor 0.0)
		var tween = create_tween()
		tween.tween_property(gecis_perdesi.material, "shader_parameter/factor", 0.0, 3.0)

func monolog_oynat():
	if not alt_yazi: return
	
	# Ekran açılana kadar bekle (3 saniye)
	await get_tree().create_timer(3.0).timeout
	
	for satir in diyaloglar:
		alt_yazi.text = satir
		var sure = clamp(satir.length() * 0.08, 2.0, 5.0)
		await get_tree().create_timer(sure).timeout
		alt_yazi.text = ""
		await get_tree().create_timer(0.5).timeout

func kapidan_giris(body):
	if body.name == "Oyuncu" or body.is_in_group("Oyuncu"):
		print("Piramite giriliyor... Geçiş ekranı başlıyor.")
		# Hemen ekrana beyaz flash
		if gecis_perdesi:
			# Parıldayıp kararma: önce beyaza çek, sonra siyaha al
			gecis_perdesi.color = Color(1, 1, 1, 0)
			var t = create_tween()
			t.tween_property(gecis_perdesi, "color", Color(1, 1, 1, 1), 0.3)
			t.tween_property(gecis_perdesi.material, "shader_parameter/factor", 1.0, 0.5)
		ozel_gecis_yap()

func ozel_gecis_yap():
	# ... (Ekran karartma tween kodların varsa burada kalsın) ...
	
	# --- YENİ EKLENECEK KISIM ---
	print("Hikaye modu tamamlandı. Kaydediliyor...")
	GameManager.intro_tamamlandi = true
	GameManager.oyunu_kaydet() # Durumu dosyaya yaz
	# ----------------------------
	
	# Biraz bekle ve asıl oyuna geç
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://sphenks.tscn")
