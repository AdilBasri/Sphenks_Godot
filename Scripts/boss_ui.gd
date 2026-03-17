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
		_tum_totemleri_gizle()
		return true
	return false

# ── PUBLIC API (Legacy support, though no longer needed) ──────────────────────

func boss_ekle(_boss_ref: Node, _tip: String, _max_hp: int) -> void: pass
func boss_hasar_guncelle(_boss_ref: Node, _yeni_hp: int) -> void: pass
func boss_kaldir(_boss_ref: Node) -> void: pass
func atak_guncelle(_boss_ref: Node, _ataklar: Array) -> void: pass

# ── İÇ YARDIMCILAR ───────────────────────────────────────────────────────────

func _tum_totemleri_gizle():
	for grup in _totem_gruplari.values():
		if grup:
			grup.visible = false
			for child in grup.get_children():
				if child is Node3D: child.visible = false

func _totemleri_guncelle_v4(tip: String, current_hp: int):
	_bul_ve_hazirla()
	
	for t_tip in _totem_gruplari.keys():
		if t_tip != tip:
			var grup = _totem_gruplari[t_tip]
			if grup and grup.visible: 
				grup.visible = false
	
	var aktif_grup = _totem_gruplari.get(tip)
	if aktif_grup:
		var totemler = []
		totemler.append(aktif_grup) # 1. Can (Parent Root)
		
		var tip_l = tip.to_lower()
		var children = aktif_grup.get_children()
		var ek_totemler = []
		
		for child in children:
			var cname = child.name.to_lower()
			var is_extra_totem = false
			for suffix in ["2", "3", "4"]:
				if cname == tip_l + suffix:
					is_extra_totem = true
					break
			
			if is_extra_totem:
				ek_totemler.append(child)
		
		ek_totemler.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
		totemler.append_array(ek_totemler)
		
		# --- GÖRÜNÜRLÜK AYARLA ---
		if current_hp > 0:
			aktif_grup.visible = true
			for i in range(totemler.size()):
				var t_node = totemler[i]
				var should_be_visible = (i < current_hp)
				t_node.visible = should_be_visible
				
				# REKÜRSİF GÜVENLİK: Eğer görünmesi gerekiyorsa tüm çocuklarını da aç
				if should_be_visible:
					_recursive_visible(t_node, true)
				
				# DEBUG: Detaylı log
				if i < 3: # Sadece ilk 3 için log bas ki spam olmasın
					print("DEBUG: Totem[%d] %s | Visible: %s | GlobalPos: %s" % [i, t_node.name, t_node.visible, t_node.global_position])
		else:
			aktif_grup.visible = false
	else:
		if tip != "":
			push_warning("DEBUG: Totem grubu bulunamadı: " + tip)

func _recursive_visible(node: Node, val: bool):
	if node is Node3D:
		node.visible = val
	for child in node.get_children():
		_recursive_visible(child, val)
