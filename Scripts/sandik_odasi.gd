extends Node3D
## Sandık Odası Yöneticisi
## sandik_odasi.tscn kök düğümüne (Sandik_Odasi) eklenmiştir.

# ─── SAHNELER ────────────────────────────────────────────────────────────────
const KAHIN_GOZU_SAHNE   = preload("res://Perks/kahin_gozu/kahin_gozu.tscn")
const WAND_SAHNE         = preload("res://Perks/wand/wand.tscn")
const DISCOUNT_SAHNE     = preload("res://Perks/discount/discount.tscn")
const BLOODY_NAIL_SAHNE  = preload("res://Perks/bloody_nail/bloody_nail.tscn")
const CROSS_WHITE_SAHNE  = preload("res://cross_white.tscn")

# ─── SANDIK ADI → NODE YOLU ──────────────────────────────────────────────────
const SANDIK_ADLARI = [
	"sandık1", "sandık2", "sandık3", "sandık4", "sandık5", "sandık6"
]

# 4 pozitif perk
const POZITIF_PERKLER = [
	{ "id": "kahin_gozu",  "ad": "Kahin'in Gözü"  },
	{ "id": "curuk_temel", "ad": "Çürük Temel"    },
	{ "id": "discount",    "ad": "Kanlı İndirim"  },
	{ "id": "bloody_nail", "ad": "Kanlı Çivi"     },
]

# ─── DURUM ────────────────────────────────────────────────────────────────────
var sandik_icerikleri: Dictionary = {}   # sandik_adi → perk_dict_veya_null
var acilan_sandiklar: Array = []
var pozitif_acildi_mi: bool = false
var acilan_pozitif_sayisi: int = 0
var chest_key_node: Node3D = null
var door_key_node: Node3D = null
var kapi_node: Node3D = null
var oyuncu_node: CharacterBody3D = null
var items_in_room: Array = []
var sandik_node_map: Dictionary = {}    # sandik_adi → Node3D


var elde_tutulan_anahtar: Node3D = null
var orijinal_y_offset: float = -0.4 
var bob_time: float = 0.0
var anahtar_offset: Vector3 = Vector3(0.5, -0.4, -0.6)  # Aktif anahtarın elde tutma pozisyonu

# ─── ETKİLEŞİM ───────────────────────────────────────────────────────────────
var etkilesim_label: Label = null
var raycast: RayCast3D = null

# ─── ANAHTAR ────────────────────────────────────────────────────────────
var chest_key_offset := Vector3(0.5, -0.4, -0.6)  # Elde tutma açısı (kamerada sağ alt)

func _ready():
	# Oyuncuyu bul
	oyuncu_node = get_tree().get_first_node_in_group("Oyuncu") as CharacterBody3D
	if not oyuncu_node:
		push_warning("SandikOdasi: Oyuncu bulunamadı, bazı özellikler çalışmaz.")
		return

	# Raycast ve label
	var kamera = oyuncu_node.find_child("Camera3D", true, false) as Camera3D
	if kamera:
		raycast = kamera.get_node_or_null("RayCast3D") as RayCast3D
	etkilesim_label = oyuncu_node.get_node_or_null("CanvasLayer/EtkilesimYazisi") as Label

	# Sandıkları bul
	_sandiklari_hazirla()
	# İçerikleri dağıt
	_icerik_dagit()
	# Anahtarları hazırla (artık masada kalacaklar)
	_anahtarlari_hazirla()
	# Kapıyı bul ve kilitle
	_kapiyi_baslangicta_kilitle()

func _process(delta):
	if not oyuncu_node or not raycast: return

	# Elde tutulan anahtar varsa adım sallanması (bobbing) yap
	if elde_tutulan_anahtar and is_instance_valid(elde_tutulan_anahtar):
		var hiz = oyuncu_node.velocity.length()
		if hiz > 0.5:
			bob_time += delta * hiz * 1.5
			var bob_y = sin(bob_time) * 0.03
			var bob_x = cos(bob_time * 0.5) * 0.02
			elde_tutulan_anahtar.position = Vector3(anahtar_offset.x + bob_x, anahtar_offset.y + bob_y, anahtar_offset.z)
		else:
			bob_time = 0.0
			elde_tutulan_anahtar.position = elde_tutulan_anahtar.position.lerp(anahtar_offset, delta * 5.0)

	_etkilesim_kontrol()


# ─── SANDIKLARI HAZIRLA ───────────────────────────────────────────────────────
func _sandiklari_hazirla():
	# Masa_Sandik'ı önce direkt çocuk olarak, sonra recursive ara
	var masa = get_node_or_null("Masa_Sandik")
	if not masa:
		masa = find_child("Masa_Sandik", true, false)
	if not masa:
		push_warning("SandikOdasi: Masa_Sandik bulunamadı!")
		return

	for sandik_adi in SANDIK_ADLARI:
		var sandik = masa.get_node_or_null(sandik_adi)
		if sandik:
			sandik_node_map[sandik_adi] = sandik
			# Sandığın tüm CollisionShape3D'lerini SandikGrubu'na ekle
			_collision_gruba_ekle(sandik, "SandikGrubu")
		else:
			push_warning("SandikOdasi: " + sandik_adi + " Masa_Sandik içinde bulunamadı!")

func _collision_gruba_ekle(dugum: Node, grup: String):
	if dugum == null: return
	if dugum is CollisionShape3D or dugum is CollisionPolygon3D:
		if not dugum.is_in_group(grup):
			dugum.add_to_group(grup)
	for child in dugum.get_children():
		_collision_gruba_ekle(child, grup)

# ─── İÇERİK DAGIT ─────────────────────────────────────────────────────────────
func _icerik_dagit():
	var alinmis_perkler: Array = []
	if GameManager:
		if GameManager.get("kahin_gozu_aktif") and GameManager.kahin_gozu_aktif:
			alinmis_perkler.append("kahin_gozu")
		if GameManager.get("curuk_temel_aktif") and GameManager.curuk_temel_aktif:
			alinmis_perkler.append("curuk_temel")
		if GameManager.get("kanli_indirim_aktif") and GameManager.kanli_indirim_aktif:
			alinmis_perkler.append("discount")
		if GameManager.get("kanli_civi_aktif") and GameManager.kanli_civi_aktif:
			alinmis_perkler.append("bloody_nail")

	var musait_perkler: Array = []
	for p in POZITIF_PERKLER:
		if p["id"] not in alinmis_perkler:
			musait_perkler.append(p)

	musait_perkler.shuffle()
	var pozitif_sayisi = mini(2, musait_perkler.size())

	var karisik = SANDIK_ADLARI.duplicate()
	karisik.shuffle()

	sandik_icerikleri.clear()
	for i in range(karisik.size()):
		if i < pozitif_sayisi:
			sandik_icerikleri[karisik[i]] = musait_perkler[i]   # Pozitif
		else:
			sandik_icerikleri[karisik[i]] = null                  # Negatif

	print("🎲 Sandık içerikleri dağıtıldı.")

# ─── ANAHTARLAR ───────────────────────────────────────────────────────────────
func _anahtarlari_hazirla():
	chest_key_node = get_tree().current_scene.find_child("chest_key", true, false)
	door_key_node  = get_tree().current_scene.find_child("door_key",  true, false)

	if door_key_node:
		door_key_node.visible = false

func _kapiyi_baslangicta_kilitle():
	# KapiSistemi adındaki node'u bul (doğrudan veya recursive)
	kapi_node = get_node_or_null("KapiSistemi")
	if not kapi_node:
		kapi_node = find_child("KapiSistemi", true, false)
	if not kapi_node:
		# Sahne kökünden de dene
		kapi_node = get_tree().current_scene.find_child("KapiSistemi", true, false)
	if kapi_node:
		if kapi_node.has_method("kilitle"):
			kapi_node.kilitle()
		else:
			kapi_node.set("kilitli_mi", true)
		print("🔒 Sandık Odası kapısı kilitlendi: ", kapi_node.get_path())
	else:
		push_warning("SandikOdasi: KapiSistemi node bulunamadı!")

# ─── MASA ÜZERİNDEN ANAHTAR AL ────────────────────────────────────────────────
func _anahtar_al(anahtar_node: Node3D):
	if elde_tutulan_anahtar == anahtar_node: return

	var kamera = oyuncu_node.find_child("Camera3D", true, false)
	if not kamera: return

	# Eski anahtar varsa gizle veya bırak
	if elde_tutulan_anahtar and is_instance_valid(elde_tutulan_anahtar):
		elde_tutulan_anahtar.visible = false

	elde_tutulan_anahtar = anahtar_node
	elde_tutulan_anahtar.visible = true

	var old_parent = anahtar_node.get_parent()
	if old_parent:
		old_parent.remove_child(anahtar_node)
	kamera.add_child(anahtar_node)

	if anahtar_node.name == "door_key":
		anahtar_node.rotation_degrees = Vector3(90, 0, 0)
		anahtar_node.scale = Vector3(0.001, 0.001, 0.001)
		anahtar_offset = Vector3(0.4, -0.35, -1.0)
	else:
		# Sandık anahtarı
		anahtar_node.rotation_degrees = Vector3(0, 180, 0)
		anahtar_node.scale = Vector3(0.007, 0.007, 0.007)
		anahtar_offset = Vector3(0.5, -0.4, -0.6)
	anahtar_node.position = anahtar_offset


	# Oyuncuya bildirim
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if anahtar_node.name == "chest_key" and arayuz:
		arayuz.bilgi_goster("🗝️ Sandık Anahtarı alındı!", 2.5)
	elif anahtar_node.name == "door_key" and arayuz:
		arayuz.bilgi_goster("🚪 Çıkış Anahtarı alındı!", 3.0)

# ─── E-TUŞU ETKİLEŞİM KONTROLÜ ────────────────────────────────────────────────
func _etkilesim_kontrol():
	if not raycast or not raycast.is_colliding(): return
	var carpan = raycast.get_collider()
	if not carpan: return

	var ust_node = carpan
	
	# 1. ANAHTARLAR: Yukarı doğru anahtar ara (4 kademe)
	var tmp = carpan
	for i in range(5):
		if not tmp: break
		if (tmp.name == "chest_key" or tmp.name == "door_key"):
			if tmp.name == "door_key" and tmp.visible == false:
				tmp = tmp.get_parent()
				continue
			if tmp != elde_tutulan_anahtar:
				var mesafe_anahtar = oyuncu_node.global_position.distance_to(tmp.global_position)
				if mesafe_anahtar <= 3.0:
					if etkilesim_label: etkilesim_label.text = "(E) Anahtarı Al"
					if Input.is_action_just_pressed("etkilesim"):
						_anahtar_al(tmp)
				return
		tmp = tmp.get_parent()

	# 2. ÇIKIŞ KAPISI KİLİT KONTROLÜ
	# Raycast kapıya ya da içindeki herhangi bir nesneye çarparsa kapi_node'u kullan
	var kapi_carpti = false
	if kapi_node and is_instance_valid(kapi_node):
		var check = carpan
		for i in range(8):
			if not check: break
			if check == kapi_node:
				kapi_carpti = true
				break
			check = check.get_parent()
	
	if kapi_carpti:
		var mesafe = oyuncu_node.global_position.distance_to(kapi_node.global_position)
		if mesafe <= 3.0:
			var kilitli = kapi_node.get("kilitli_mi")
			if kilitli == true:
				if elde_tutulan_anahtar and elde_tutulan_anahtar.name == "door_key":
					if etkilesim_label: etkilesim_label.text = "(E) Kapıyı Aç"
					if Input.is_action_just_pressed("etkilesim"):
						_kapiyi_kilit_ac(kapi_node)
				else:
					if etkilesim_label: etkilesim_label.text = "Kilitli - Kapı Anahtarı Lazım"
			else:
				# Kapı kilitli değil, normal açılır
				if etkilesim_label: etkilesim_label.text = "(E) Kapıyı Aç"
				if Input.is_action_just_pressed("etkilesim"):
					kapi_node.set("hedef_tipi", 1) # HedefTipi.SONRAKI_LEVEL
					if kapi_node.has_method("kapiyi_ac"):
						kapi_node.kapiyi_ac()
		return

	# 3. SANDIK KONTROLÜ (Mesafe ve Anahtar Şartlı)
	var sandik_ana = _sandik_bul(carpan)
	if sandik_ana and not sandik_ana.name in acilan_sandiklar:
		# Sandığa yeterince yakın mıyız? (mesafe kontrolü)
		if oyuncu_node.global_position.distance_to(sandik_ana.global_position) > 3.0:
			return
			
		# Sandık SADECE chest_key elimizdeyken açılabilir
		if elde_tutulan_anahtar and elde_tutulan_anahtar.name == "chest_key":
			if etkilesim_label:
				etkilesim_label.text = "(E) Sandığı Aç"
			if Input.is_action_just_pressed("etkilesim"):
				sandik_ac(sandik_ana)
		else:
			if acilan_pozitif_sayisi < 2:
				if etkilesim_label:
					etkilesim_label.text = "Kilitli - Masadan Anahtarı Al"
		return

func _kapiyi_kilit_ac(hedef_kapi):
	hedef_kapi.set("kilitli_mi", false)
	hedef_kapi.set("hedef_tipi", 1) # HedefTipi.SONRAKI_LEVEL
	if hedef_kapi.has_method("kapiyi_ac"):
		hedef_kapi.kapiyi_ac()
	
	# door_key'i elimizden al (kırıldı)
	if elde_tutulan_anahtar and elde_tutulan_anahtar.name == "door_key":
		elde_tutulan_anahtar.queue_free()
		elde_tutulan_anahtar = null
		door_key_node = null


# Raycast'in çarptığı collider'dan sandığın ana node'unu bul (yukarı tara)
func _sandik_bul(node: Node) -> Variant:
	var suanki = node
	for _i in range(8):
		if not suanki: break
		for adi in sandik_node_map.keys():
			if suanki == sandik_node_map[adi]:
				return suanki
		suanki = suanki.get_parent()
	return null

# ─── SANDIK AÇ ────────────────────────────────────────────────────────────────
func sandik_ac(sandik: Node3D):
	if not is_instance_valid(sandik): return
	if sandik.name in acilan_sandiklar: return
	acilan_sandiklar.append(sandik.name)

	# Ses
	var sfx = AudioStreamPlayer.new()
	var ses = load("res://Sesler/buy.mp3")
	if ses:
		sfx.stream = ses
		sfx.bus = "Master"
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

	var icerik = sandik_icerikleri.get(sandik.name, null)   # null → negatif
	var perk_id: String = ""

	if icerik != null:
		perk_id = icerik["id"]

	# İlgili sahneyi seç
	var icerik_sahne: PackedScene = null
	if icerik == null:
		icerik_sahne = CROSS_WHITE_SAHNE
	else:
		match perk_id:
			"kahin_gozu":  icerik_sahne = KAHIN_GOZU_SAHNE
			"curuk_temel": icerik_sahne = WAND_SAHNE
			"discount":    icerik_sahne = DISCOUNT_SAHNE
			"bloody_nail": icerik_sahne = BLOODY_NAIL_SAHNE

	# Modeli sandıktan yukarı çıkar
	if icerik_sahne:
		var model = icerik_sahne.instantiate()
		get_tree().current_scene.add_child(model)
		model.set_as_top_level(true)
		model.global_position = sandik.global_position + Vector3(0, 0.3, 0)
		model.scale = Vector3.ONE * 0.8
		
		# Animasyon varsa oynat (özellikle kahin_gozu için)
		var anim_player = model.find_child("AnimationPlayer", true, false)
		if anim_player:
			var anim_list = anim_player.get_animation_list()
			for ani in anim_list:
				if ani != "RESET":
					anim_player.play(ani)
					# Döngüye al
					var cur_anim = anim_player.get_animation(ani)
					if cur_anim:
						cur_anim.loop_mode = Animation.LOOP_LINEAR
					break
		
		# Çarparak itmesini/oyuncuyu ittirmesini engellemek için collision kapat:
		_collision_kapat_model(model)
		
		# --- IŞIK EKLEME ---
		var isik = OmniLight3D.new()
		if icerik != null:
			# Pozitif: Sarı ışık - Sadece objeyi sarsın, etrafı parlatmasın
			isik.light_color = Color(1.0, 0.9, 0.2)
			isik.light_energy = 1.0     
			isik.omni_range = 1.5       
		else:
			# Negatif (cross_white): Kırmızı ışık
			isik.light_color = Color(1.0, 0.1, 0.1)
			isik.light_energy = 1.5     
			isik.omni_range = 2.0       

			
		model.add_child(isik)
		# Işığı modelin merkezine al
		isik.position = Vector3.ZERO
		
		var rot_ek = 0.0
		if sandik.name in ["sandık2", "sandık3", "sandık4"]:
			rot_ek = deg_to_rad(90) # Y eksenine sadece 90 derece ekliyoruz
			
		model.rotation.y = rot_ek
		var rot_hedef = rot_ek + TAU
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(model, "global_position:y",
			sandik.global_position.y + 1.8, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(model, "rotation:y", rot_hedef, 0.8).set_trans(Tween.TRANS_SINE)
		items_in_room.append(model)


	# Sonucu uygula
	if icerik != null:
		_perk_ver(icerik)
		acilan_pozitif_sayisi += 1
		
		# 2 pozitif sandık açıldıysa: Anahtarı Kır / Yok Et
		if acilan_pozitif_sayisi >= 2:
			_chest_key_kir()
	else:
		_negatif_sonuc()

func _chest_key_kir():
	if chest_key_node and is_instance_valid(chest_key_node):
		chest_key_node.queue_free()
	chest_key_node = null
	if elde_tutulan_anahtar and is_instance_valid(elde_tutulan_anahtar) and elde_tutulan_anahtar.name == "chest_key":
		elde_tutulan_anahtar.queue_free()
		elde_tutulan_anahtar = null
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz: arayuz.bilgi_goster("💥 Sandık Anahtarı Kırıldı! Daha fazla sandık açılamaz.", 4.0)
	print("💥 2 pozitif açıldı, sandık anahtarı kırıldı.")

func _perk_ver(perk: Dictionary):
	var perk_id: String = perk["id"]
	var arayuz = get_tree().get_first_node_in_group("Arayuz")

	match perk_id:
		"kahin_gozu":
			if GameManager:
				GameManager.kahin_gozu_aktif = true
			if arayuz: arayuz.bilgi_goster("👁️ Kahin'in Gözü: Boss'un sıradaki hamlesini göreceksin!", 4.0)
		"curuk_temel":
			if GameManager:
				GameManager.curuk_temel_aktif = true
			var item_veri = _wand_item_verisi_olustur()
			if item_veri and GameManager and GameManager.envanter.size() < GameManager.max_totem_sayisi:
				GameManager.envanter.append(item_veri)
				GameManager.envanter_guncellendi.emit()
			if arayuz: arayuz.bilgi_goster("🪄 Çürük Temel: Envanterinde! Grid'i temizler.", 4.0)
		"discount":
			if GameManager:
				GameManager.kanli_indirim_aktif = true
			if arayuz: arayuz.bilgi_goster("💀 Kanlı İndirim: Market %50 indirimli ama -3 HP!", 4.0)
		"bloody_nail":
			if GameManager:
				GameManager.kanli_civi_aktif = true
			if arayuz: arayuz.bilgi_goster("🩸 Kanlı Çivi: Çapraz hareketler artık patlıyor!", 4.0)

	pozitif_acildi_mi = true
	_door_key_ac()

func _negatif_sonuc():
	var oyuncu = get_tree().get_first_node_in_group("Oyuncu")
	if oyuncu and oyuncu.has_method("hasar_al"):
		oyuncu.hasar_al(3)
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz: arayuz.bilgi_goster("💀 Boş sandık! -3 HP!", 2.5)
	print("💀 Negatif sandık. Oyuncu 3 HP kaybetti.")

func _door_key_ac():
	if not is_instance_valid(door_key_node): return
	door_key_node.visible = true
	var arayuz = get_tree().get_first_node_in_group("Arayuz")
	if arayuz: arayuz.bilgi_goster("🗝️ Anahtar hazır! Artık çıkabilirsin.", 4.0)

func _wand_item_verisi_olustur() -> ItemData:
	var item = ItemData.new()
	item.esya_adi = "Çürük Temel"
	item.etki_id = "curuk_temel"
	item.animasyon_tipi = "kirma"
	item.fiyat = 0
	return item

func _collision_kapat_model(dugum: Node):
	if dugum is CollisionShape3D or dugum is CollisionPolygon3D:
		dugum.disabled = true
	if dugum is RigidBody3D or dugum is StaticBody3D:
		dugum.collision_layer = 0
		dugum.collision_mask = 0
	for child in dugum.get_children():
		_collision_kapat_model(child)

# Tüm alt node'ları görünür yap (door_key gibi multi-mesh nesneler için)
func _make_visible_recursive(dugum: Node):
	if dugum is VisualInstance3D or dugum is MeshInstance3D:
		dugum.visible = true
	if dugum.has_method("set_visible"):
		dugum.set_visible(true)
	for child in dugum.get_children():
		_make_visible_recursive(child)

func _notification(what):

	if what == NOTIFICATION_EXIT_TREE:
		for item in items_in_room:
			if is_instance_valid(item):
				item.queue_free()
		items_in_room.clear()
