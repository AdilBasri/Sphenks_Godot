extends Node3D

# --- BAĞLANTILAR ---
@onready var kapi_marker = $KapiMarker3D 
@onready var alt_yazi = $UI/Label 
@onready var gecis_perdesi = $UI/GecisEkrani
@onready var oyuncu = $Oyuncu # Oyuncuya erişmemiz lazım
@onready var oyuncu_eli = $Oyuncu/Camera3D/El_Konumu # Az önce oluşturduğun el noktası

# Bilet Sahnesini Yükle
var bilet_sahnesi = preload("res://Scenes/Items/Bilet.tscn") 

# --- DEĞİŞKENLER ---
var toplanan_malzemeler = 0
var gerekli_malzeme = 3
var bilet_spawnlandi_mi = false
var bilet_inceleme_modu = false # Şu an bileti inceliyor muyuz?
var tutulan_bilet_nesnesi = null # Elimizdeki biletin referansı

var final_diyaloglari = [
	"ev_diyalog_1",
	"ev_diyalog_2",
	"ev_diyalog_3",
	"ev_diyalog_4",
	"ev_diyalog_5",
	"ev_diyalog_6",
	"ev_diyalog_7"
]

func _ready():
	if alt_yazi: alt_yazi.text = ""
	if gecis_perdesi: gecis_perdesi.material.set_shader_parameter("factor", 0.0)

# --- GİRİŞ KONTROLÜ (MOUSE İLE ÇEVİRME) ---
func _input(event):
	# Eğer bilet inceleme modundaysak, mouse hareketi KAMERAYI DEĞİL, BİLETİ çevirmeli
	if bilet_inceleme_modu and tutulan_bilet_nesnesi:
		if event is InputEventMouseMotion:
			# Bileti sağa sola ve yukarı aşağı çevir
			tutulan_bilet_nesnesi.rotate_y(event.relative.x * 0.01)
			tutulan_bilet_nesnesi.rotate_x(event.relative.y * 0.01)

# --- OYUN MANTIĞI ---

func malzeme_topla(isim):
	toplanan_malzemeler += 1
	if alt_yazi:
		var txt = DilYoneticisi.metin_al("feda_edildi") % [DilYoneticisi.metin_al(isim), toplanan_malzemeler, gerekli_malzeme]
		alt_yazi.text = txt
		await get_tree().create_timer(2.0).timeout
		alt_yazi.text = ""

func blenderi_calistir():
	if bilet_spawnlandi_mi: return

	if toplanan_malzemeler < gerekli_malzeme:
		if alt_yazi: alt_yazi.text = DilYoneticisi.metin_al("rituel_eksik")
		return

	# --- RİTÜEL ---
	bilet_spawnlandi_mi = true
	if alt_yazi: alt_yazi.text = DilYoneticisi.metin_al("rituel_tamamlandi")
	
	# Blender sesi vs buraya...
	await get_tree().create_timer(2.0).timeout
	
	if alt_yazi: alt_yazi.text = DilYoneticisi.metin_al("kapi_altindan_bilet")
	bilet_yarat()

func bilet_yarat():
	if not kapi_marker:
		print("HATA: KapiMarker3D yok!")
		return

	# Bileti sahneye koy
	var yeni_bilet = bilet_sahnesi.instantiate()
	add_child(yeni_bilet)
	yeni_bilet.global_position = kapi_marker.global_position
	
	# Kırmızı ok dışarı bakıyorsa, içeri girmek için EKSİ X (-1.5) kullanıyoruz.
	# (X, Y, Z) sıralamasına dikkat: X en baştaki sayıdır.
	var hedef_pos = kapi_marker.global_position + Vector3(-1.5, 0, 0) 
	
	# Kayma efektini başlat
	var tween = create_tween()
	tween.tween_property(yeni_bilet, "global_position", hedef_pos, 2.0)

# --- FİNAL SEQUENCE (BİLETİ ELİNE ALINCA) ---
func bilet_alindi_final(bilet_nesnesi): # Parametre olarak bileti alıyoruz
	print("Bilet alındı, inceleme modu başlıyor...")
	
	# 1. BİLETİ ELE GEÇİRME
	# Bileti sahneden koparıp oyuncunun eline yapıştıracağız ama önce yerini tutalım
	tutulan_bilet_nesnesi = bilet_nesnesi
	
	# Fiziğini kapat ki elindeyken sağa sola çarpmasın
	if tutulan_bilet_nesnesi.has_node("CollisionShape3D"):
		tutulan_bilet_nesnesi.get_node("CollisionShape3D").disabled = true
	
	# Ebeveyn değiştir (Sahneden al, Ele tak)
	tutulan_bilet_nesnesi.get_parent().remove_child(tutulan_bilet_nesnesi)
	oyuncu_eli.add_child(tutulan_bilet_nesnesi)
	
	# Pozisyonunu sıfırla (Elin tam ortasına gelsin)
	tutulan_bilet_nesnesi.position = Vector3.ZERO
	tutulan_bilet_nesnesi.rotation = Vector3(0, deg_to_rad(90), deg_to_rad(45)) # Güzel bir açıyla tutsun
	
	# 2. OYUNCU KONTROLÜNÜ KİLİTLE
	bilet_inceleme_modu = true
	# Oyuncu scriptindeki mouse hareketini durdurmak için bir değişken set etmeliyiz
	# (Bunu aşağıda Oyuncu scriptinde ayarlayacağız)
	if oyuncu:
		oyuncu.inceleme_modu_aktif = true 
	
	if alt_yazi: alt_yazi.text = ""
	
	# 3. MONOLOG
	for satir_key in final_diyaloglari:
		if alt_yazi: alt_yazi.text = DilYoneticisi.metin_al(satir_key)
		await get_tree().create_timer(3.5).timeout 
		if alt_yazi: alt_yazi.text = ""
		await get_tree().create_timer(0.5).timeout
	
	sahne_gecisi()

func sahne_gecisi():
	# 1. Ekranı Karart
	if gecis_perdesi:
		var tween = create_tween()
		# Perdeyi 3 saniyede simsiyah yap (Factor 1.0)
		tween.tween_property(gecis_perdesi.material, "shader_parameter/factor", 1.0, 3.0)
		await tween.finished
	
	print("Bölüm Bitti. Mısır'a gidiliyor...")
	
	# 2. SAHNEYİ DEĞİŞTİR (Zincirin son halkası burası!)
	# Dosya isminin "Sahne3_Misir.tscn" olduğundan emin ol. 
	# Eğer dosya adın farklıysa (örn: sphenks.tscn) burayı düzelt.
	get_tree().change_scene_to_file("res://Scenes/Sahne3_Misir.tscn")
