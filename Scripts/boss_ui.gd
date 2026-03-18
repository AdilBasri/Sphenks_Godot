extends Control
# boss_ui.gd
# Optimize edilmiş Boss UI — Kalıcı node'lar kullanılarak performans artırıldı.

# ──────────────────────────────────────────────────────────────────────────────
# AJUSTABLE CONSTANTS (DEĞİŞTİRİLEBİLİR AYARLAR)
# ──────────────────────────────────────────────────────────────────────────────
const BOSS_OFFSET_Y   : float = 80.0           # Bosslar arası dikey mesafe
const BOSS_MARGIN_RIGHT: float = 40.0          # Ekranın sağından olan genel boşluk
const BOSS_TOP_MARGIN : float = 40.0           # Ekranın üstünden olan boşluk

const HEX_BUYUK_R    : float = 18.0            # Boss kafa (büyük hex) yarıçapı
const HEX_ORTA_R     : float = 14.0            # İkincil boss kafa yarıçapı (orta boy)
const HEX_KUCUK_R    : float = 9.0             # Atak (küçük hex) yarıçapı
const KAFA_ATAK_ARASI: float = 72.0            # Kafa ile ilk atak arası boşluk
const ATAK_ARASI     : float = 50.0             # Atak hexleri kendi arası boşluk

const CANBAR_H       : float = 8.0             # Can barı kalınlığı
const CANBAR_OFFSET_Y : float = 45.0           # Can barı hexin ne kadar altında (artırıldı)
# ──────────────────────────────────────────────────────────────────────────────

# Boss renklerine göre renk tablosu
const BOSS_RENKLER := {
	"asit": Color(0.18, 0.8, 0.44), # Zümrüt yeşili
	"tas":  Color(0.6, 0.6, 0.6),   # Gri (Taş)
	"zar":  Color(0.9, 0.1, 0.1),   # Kırmızı (Zar)
	"placeholder": Color.GRAY
}

# Atak ikon texture path'leri — asset path'leri ile güncellendi
# ── STATE ─────────────────────────────────────────────────────────────────────
var _totem_gruplari: Dictionary = {} # { "asit": Node3D, "zar": Node3D, "golem": Node3D }
var _son_aktif_tip: String = ""
var _last_hp_values: Dictionary = {} # { "asit": int, "zar": int ... }
var _is_animating: bool = false

# ── HAZIRLIK ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_ui")
	_bul_ve_hazirla()

func _process(_delta: float) -> void:
	# Sahnede görünür olan boss'u bul
	var aktif_boss = null
	var bosslar = get_tree().get_nodes_in_group("boss")
	
	for b in bosslar:
		if is_instance_valid(b) and b.is_visible_in_tree():
			aktif_boss = b
			break
	
	if aktif_boss:
		var tip = aktif_boss.get("boss_tipi")
		var hp = aktif_boss.get("boss_hp")
		if tip and hp != null:
			_totemleri_guncelle_v4(tip, int(hp))
			_son_aktif_tip = tip
	else:
		if _son_aktif_tip != "":
			_tum_totemleri_gizle()
			_son_aktif_tip = ""

func _bul_ve_hazirla() -> bool:
	if not _totem_gruplari.is_empty(): return true
	
	var boss_h = get_tree().current_scene.find_child("boss_h", true, false)
	if not boss_h: boss_h = get_tree().root.find_child("boss_h", true, false)
	
	if boss_h:
		_totem_gruplari["asit"] = boss_h.get_node_or_null("asit")
		_totem_gruplari["zar"] = boss_h.get_node_or_null("zar")
		_totem_gruplari["golem"] = boss_h.get_node_or_null("golem")
		
		# --- PIVOT FIX (YENİ) ---
		# Tüm totemleri gez ve pivotlarını taban noktasına (bottom) çek
		for tip in _totem_gruplari.keys():
			var grup = _totem_gruplari[tip]
			if grup:
				# Gruptaki tüm totemleri (root ve çocukları) düzelt
				var tum_dugumler = [grup]
				tum_dugumler.append_array(grup.find_children("*", "Node3D", true))
				
				for node in tum_dugumler:
					# Eğer totem adı boss tipini içeriyorsa (zar, zar2, golem vb.)
					if tip.to_lower() in node.name.to_lower():
						_fix_pivot(node)
		
		# --- REPARENT (YENİ) ---
		# Totemleri kardeş (sibling) yap ki bağımsız devrilebilsinler
		for tip in _totem_gruplari.keys():
			var grup = _totem_gruplari[tip]
			if grup:
				var children = grup.get_children()
				for child in children:
					if tip.to_lower() in child.name.to_lower():
						child.reparent(boss_h, true)
						print("👪 Reparented: ", child.name, " to boss_h")
		
		_tum_totemleri_gizle()
		return true
	return false

func _fix_pivot(totem_node: Node3D):
	# TotemMesh'i bul ve Y ekseninde yukarı taşı. 
	# Genelde GLB/FBX importlarında mesh merkezi origin'dedir.
	# Onu yukarı taşıyarak, parent (totem_node) pivotunu tabanda bırakıyoruz.
	for child in totem_node.get_children():
		if child is MeshInstance3D or "Mesh" in child.name:
			# Eğer mesh zaten yukarıda değilse (Basit bir kontrol)
			if child.position.y == 0:
				# Tahmini yükseklik (veya AABB kullanabiliriz)
				var aabb = child.get_aabb() if child.has_method("get_aabb") else AABB(Vector3.ZERO, Vector3(0.5, 1.0, 0.5))
				var h = aabb.size.y
				# Mesh'i yukarı offsetle
				child.position.y = h * 0.5
				print("🛠️ Fixed Pivot for: ", totem_node.name, " (Mesh offset: ", child.position.y, ")")

# ── PUBLIC API (Legacy support, though no longer needed) ──────────────────────

func boss_ekle(_boss_ref: Node, _tip: String, _max_hp: int) -> void: pass
func boss_hasar_guncelle(_boss_ref: Node, _yeni_hp: int) -> void: pass
func boss_kaldir(_boss_ref: Node) -> void: pass
func atak_guncelle(_boss_ref: Node, _ataklar: Array) -> void: pass

# ── İÇ YARDIMCILAR ───────────────────────────────────────────────────────────

func _tum_totemleri_gizle():
	for tip in _totem_gruplari.keys():
		var grup = _totem_gruplari[tip]
		if grup:
			var boss_h = grup.get_parent()
			if boss_h:
				for child in boss_h.get_children():
					if tip.to_lower() in child.name.to_lower():
						child.visible = false

func _totemleri_guncelle_v4(tip: String, current_hp: int):
	_bul_ve_hazirla()
	
	# Tüm totemleri gizle (aktif tip hariç)
	for t_tip in _totem_gruplari.keys():
		if t_tip != tip:
			var grup = _totem_gruplari[t_tip]
			if grup:
				var boss_h = grup.get_parent()
				if boss_h:
					for child in boss_h.get_children():
						if t_tip.to_lower() in child.name.to_lower():
							child.visible = false
	
	var aktif_grup = _totem_gruplari.get(tip)
	if aktif_grup:
		var boss_h = aktif_grup.get_parent()
		var totemler = []
		
		# Kardeş olan tüm totemleri bul (isimlerine göre)
		for child in boss_h.get_children():
			if tip.to_lower() in child.name.to_lower():
				totemler.append(child)
		
		# İsim sırasına göre diz (zar, zar2, zar3...)
		totemler.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
		
		# --- HP DEĞİŞİM KONTROLÜ (YENİ) ---
		var last_hp = _last_hp_values.get(tip, current_hp)
		
		if current_hp < last_hp and not _is_animating:
			# Can kaybı oldu! En azından bir totem devrilmeli.
			var devrilecek_index = current_hp # Eğer 3 candan 2'ye düştüyse, 2. indexteki (zar3) totem devrilir
			if devrilecek_index >= 0 and devrilecek_index < totemler.size():
				var t_node = totemler[devrilecek_index]
				var cam = get_viewport().get_camera_3d()
				if cam:
					_can_kaybi_sekans(t_node, cam)
		
		_last_hp_values[tip] = current_hp
		
		# --- GÖRÜNÜRLÜK AYARLA ---
		if current_hp > 0:
			aktif_grup.visible = true
			for i in range(totemler.size()):
				var t_node = totemler[i]
				var should_be_visible = (i < current_hp)
				
				# Eğer can bittiyse ve animasyon yoksa direkt gizle
				# Ama eğer can azaldıysa ve biz o totemi deviriyorsak, 
				# görünürlüğünü sekans içinde yöneteceğiz veya devrik bırakacağız.
				if not _is_animating:
					t_node.visible = should_be_visible
					if should_be_visible:
						_recursive_visible(t_node, true)
		else:
			aktif_grup.visible = false
	else:
		if tip != "":
			push_warning("DEBUG: Totem grubu bulunamadı: " + tip)

# --- 🪵 TOTEM DEVRİLME VE KAMERA PAN SEKANSI (YENİ) ---

func _totem_devir(totem_node: Node3D):
	# Totemi devirirken Pivot noktasına dikkat! (Base'den dönecek)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# 90 derece devril (Z ekseninde)
	tween.tween_property(totem_node, "rotation_degrees:z", 90.0, 0.4)
	
	# Ses Çal (Eğer dosya varsa fall.mp3 kullanıyoruz yoksa tahta_dus)
	var sound_path = "res://Assets/Audio/fall.mp3"
	# Kullanıcının istediği path: res://Assets/Audio/tahta_dus.mp3
	# Dosya sisteminde fall.mp3 bulmuştum, onu kullanalım yedekli.
	
	var ses = AudioStreamPlayer3D.new()
	ses.stream = load(sound_path)
	totem_node.add_child(ses)
	
	tween.tween_callback(func():
		ses.play()
		print("🔊 Totem devrildi: ", totem_node.name)
	)
	
	# Belli bir süre sonra tamamen yok et veya gizle
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(totem_node):
		totem_node.visible = false

func _can_kaybi_sekans(totem_node: Node3D, kamera: Camera3D):
	if _is_animating: return
	_is_animating = true
	
	var eski_pos = kamera.global_position
	var eski_rot = kamera.quaternion # Rotation'ı quaternion ile saklamak daha güvenli
	
	# Oyuncu kamerasını kilitle (active_tween set ederek)
	# Bu, oyuncunun pan esnasında fareyle kamerayı sarsmasını engeller.
	var oyuncu = get_tree().get_first_node_in_group("oyuncu")
	
	# 1 — Kamera pan git (Toteme doğru odakla)
	var tween = create_tween()
	if oyuncu:
		# oyuncu.gd içindeki _input'ta: if active_tween and active_tween.is_running(): return
		oyuncu.set("active_tween", tween)
		# SİLAHLARI GİZLE (User isteği)
		if oyuncu.has_method("hide_weapon"): oyuncu.hide_weapon()
	
	tween.set_parallel(true)
	
	# Süre artırıldı: 1.0 -> 1.5
	var hedef_pos = totem_node.global_position + Vector3(0.5, 0.4, 0.8)
	tween.tween_property(kamera, "global_position", hedef_pos, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Toteme bak
	# look_at yerine tweenable bir yöntem kullanalım
	var offset = totem_node.global_position - hedef_pos
	var target_basis = Basis.looking_at(offset, Vector3.UP)
	# basis'ten quaternion'a çevirip tweenleyelim
	tween.tween_property(kamera, "quaternion", target_basis.get_rotation_quaternion(), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2 — Pan biterken totem devril
	tween.set_parallel(false)
	tween.tween_callback(func(): _totem_devir(totem_node))
	# Bekleme süresi artırıldı: 1.5 -> 2.0
	tween.tween_interval(1.0)
	
	# 3 — Kamera geri dön
	tween.set_parallel(true)
	# Dönüş süresi artırıldı: 1.0 -> 1.5
	tween.tween_property(kamera, "global_position", eski_pos, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(kamera, "quaternion", eski_rot, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.set_parallel(false)
	tween.tween_callback(func(): 
		_is_animating = false
		if oyuncu and oyuncu.has_method("show_weapon"): oyuncu.show_weapon()
		print("🎥 Kamera ve Totem sekansı tamamlandı.")
	)

func _recursive_visible(node: Node, val: bool):
	if node is Node3D:
		node.visible = val
	for child in node.get_children():
		_recursive_visible(child, val)
