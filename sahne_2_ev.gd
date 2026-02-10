extends Node3D

# --- BAĞLANTILAR ---
# Kapının önündeki Marker3D (Biletin doğacağı yer)
@onready var kapi_marker = $KapiMarker3D 
# UI (Label)
@onready var alt_yazi = $UI/Label 
# Geçiş efekti (IntroSahnesi'ndeki ColorRect'i kopyalayıp buraya da koymalısın)
@onready var gecis_perdesi = $UI/GecisEkrani

# --- DEĞİŞKENLER ---
var toplanan_malzemeler = 0
var gerekli_malzeme = 3
var bilet_spawnlandi_mi = false

# --- HİKAYE METNİ (Sırayla Akacak) ---
var final_diyaloglari = [
	"Mısır hep ilgimi çekmiştir...",
	"Bu ziyaret aklımda bazı şeyleri toplamama yardım edebilir.",
	"Buralardan bir süreliğine uzaklaşmak... Bunu değerlendirebilirim, evet.",
	"Ve gidersem, eminim kimse benim yokluğumu fark etmeyecektir bile.",
	"İki gün sonra öğlen kalkıyor uçak.",
	"Öyleyse... Mısır'a gidiyoruz demek."
]

func _ready():
	# Başlangıç temizliği
	if alt_yazi: alt_yazi.text = ""
	# Geçiş perdesi varsa tamamen şeffaf yap
	if gecis_perdesi: gecis_perdesi.material.set_shader_parameter("factor", 0.0)

# --- OYUN MANTIĞI ---

func malzeme_topla(isim):
	toplanan_malzemeler += 1
	if alt_yazi:
		alt_yazi.text = isim + " feda edildi. (" + str(toplanan_malzemeler) + "/" + str(gerekli_malzeme) + ")"
		await get_tree().create_timer(2.0).timeout
		alt_yazi.text = ""

func blenderi_calistir():
	if bilet_spawnlandi_mi: 
		if alt_yazi: alt_yazi.text = "Kapının altına bak..."
		return

	if toplanan_malzemeler < gerekli_malzeme:
		if alt_yazi: alt_yazi.text = "Ritüel için daha fazla eşya (3 tane) gerekiyor."
		return

	# --- RİTÜEL TAMAMLANDI ---
	bilet_spawnlandi_mi = true
	
	if alt_yazi: alt_yazi.text = "GEÇMİŞ ÖĞÜTÜLDÜ..."
	
	# Blender sesi, ekran titremesi vs. buraya eklenebilir.
	await get_tree().create_timer(2.0).timeout
	
	# Kapıdan bilet geldi mesajı
	if alt_yazi: alt_yazi.text = "Kapının altından bir şey atıldı..."
	
	# Bileti Oluştur
	bilet_yarat()

func bilet_yarat():
	if not kapi_marker:
		print("HATA: Sahneye 'KapiMarker3D' eklememişsin!")
		return

	# Bileti fiziksel bir nesne olarak yaratıyoruz
	var bilet_govde = StaticBody3D.new()
	
	# 1. Çarpışma Şekli
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.5, 0.05, 0.3) # İnce bir kağıt gibi
	shape.shape = box
	bilet_govde.add_child(shape)
	
	# 2. Görüntüsü (Mesh)
	var mesh_ins = MeshInstance3D.new()
	mesh_ins.mesh = BoxMesh.new()
	mesh_ins.mesh.size = Vector3(0.5, 0.05, 0.3)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.84, 0.0) # Altın Sarısı
	mesh_ins.mesh.surface_set_material(0, mat)
	bilet_govde.add_child(mesh_ins)
	
	# 3. Scripti Bağla ve Ayarla
	# 'etkilesim_nesnesi.gd' dosyasını yükle
	var script = load("res://etkilesim_nesnesi.gd") 
	bilet_govde.set_script(script)
	bilet_govde.nesne_turu = 3 # Enumda 3. sıra BILET (0:Musluk, 1:Blender, 2:Esya, 3:Bilet)
	bilet_govde.esya_ismi = "Mısır Bileti"
	
	# Sahneye Ekle
	add_child(bilet_govde)
	bilet_govde.global_position = kapi_marker.global_position

# --- FİNAL SEQUENCE (ALTYAZI VE BİTİŞ) ---
func bilet_alindi_final():
	print("Bilet alındı, final başlıyor...")
	if alt_yazi: alt_yazi.text = ""
	
	# Monolog döngüsü
	for satir in final_diyaloglari:
		if alt_yazi: alt_yazi.text = satir
		# Okuma süresi (Metin uzunluğuna göre beklenebilir ama sabit 3sn iyidir)
		await get_tree().create_timer(3.5).timeout 
		if alt_yazi: alt_yazi.text = ""
		await get_tree().create_timer(0.5).timeout # İki cümle arası boşluk
	
	# Ekranı Karart ve Bitir
	sahne_gecisi()

func sahne_gecisi():
	if gecis_perdesi:
		var tween = create_tween()
		tween.tween_property(gecis_perdesi.material, "shader_parameter/factor", 1.0, 3.0)
		await tween.finished
	
	# OYUN SONU veya SONRAKİ BÖLÜM
	print("Bölüm Bitti.")
	# get_tree().change_scene_to_file("res://Sahne3_Misir.tscn")
