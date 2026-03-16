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
const ATAK_IKONLAR := {
	"asit":  "res://Assets/acid.png",
	"tas":   "res://Assets/stone.png",
	"kaya":  "res://Assets/stone.png",
	"zar":   "res://Assets/dice.png",
}

# ── STATE ─────────────────────────────────────────────────────────────────────
#{ "boss_ref": Node, "tip": String, "max_hp": int, "current_hp": int,
#   "gelecek_ataklar": Array, "container": Control }
var aktif_bosslar: Array = []

# ── HAZIRLIK ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_ui")
	# Anchor sağ üst köşe
	anchor_left   = 1.0
	anchor_right  = 1.0
	anchor_top    = 0.0
	anchor_bottom = 0.0
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	size = Vector2(0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Sadece görünürlük yönetimi ve pozisyon güncelleme için timer
	var timer: Timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_periyodik_kontrol)
	add_child(timer)

# ── PUBLIC API ────────────────────────────────────────────────────────────────

func boss_ekle(boss_ref: Node, tip: String, max_hp: int) -> void:
	for b in aktif_bosslar:
		if b.boss_ref == boss_ref: return

	var veri: Dictionary = {
		"boss_ref":       boss_ref,
		"tip":            tip,
		"max_hp":         max_hp,
		"current_hp":     max_hp,
		"gelecek_ataklar": _varsayilan_ataklar(tip),
		"container":      null,
	}
	aktif_bosslar.append(veri)
	_ui_yenile()

func boss_hasar_guncelle(boss_ref: Node, yeni_hp: int) -> void:
	for veri in aktif_bosslar:
		if veri.boss_ref == boss_ref:
			veri.current_hp = max(yeni_hp, 0)
			_canbari_guncelle(veri)
			return

func boss_kaldir(boss_ref: Node) -> void:
	for i: int in aktif_bosslar.size():
		var veri: Dictionary = aktif_bosslar[i]
		if veri.boss_ref == boss_ref:
			if veri.container:
				veri.container.queue_free()
			aktif_bosslar.remove_at(i)
			_ui_yenile()
			return

func atak_guncelle(boss_ref: Node, ataklar: Array) -> void:
	for veri in aktif_bosslar:
		if veri.boss_ref == boss_ref:
			veri.gelecek_ataklar = ataklar
			# Atak değişince container'ı silip baştan oluşturmak en basiti (nadirdir)
			if veri.container:
				veri.container.queue_free()
				veri.container = null
			_ui_yenile()
			return

# ── İÇ YARDIMCILAR ───────────────────────────────────────────────────────────

func _varsayilan_ataklar(tip: String) -> Array:
	return [tip, tip, tip]

func _periyodik_kontrol() -> void:
	# Görünürlük durumuna göre pozisyonları ayarla
	_ui_yenile()

func _ui_yenile() -> void:
	# Kartların toplam boyutlarını hesapla
	var ataklar_toplam_w: float = KAFA_ATAK_ARASI + (3.0 * (HEX_KUCUK_R * 2.0 + ATAK_ARASI)) + (HEX_KUCUK_R * 2.0)
	var kart_toplam_w: float = (HEX_BUYUK_R * 2.0) + ataklar_toplam_w

	var visible_count: int = 0
	for i: int in aktif_bosslar.size():
		var veri: Dictionary = aktif_bosslar[i]
		
		var is_visible: bool = false
		if is_instance_valid(veri.boss_ref):
			if "visible" in veri.boss_ref:
				is_visible = veri.boss_ref.visible
			else:
				is_visible = true
		
		if not is_visible:
			if veri.container:
				veri.container.visible = false
			continue

		var x_pos: float
		var y_pos: float = BOSS_TOP_MARGIN + (visible_count * BOSS_OFFSET_Y)
		var is_birincil: bool = (visible_count == 0)

		if is_birincil:
			x_pos = -BOSS_MARGIN_RIGHT - kart_toplam_w
		else:
			x_pos = -BOSS_MARGIN_RIGHT - kart_toplam_w + (HEX_BUYUK_R * 2.0) + KAFA_ATAK_ARASI

		# Container yoksa veya birincillik durumu değiştiyse oluştur/yenile
		if not veri.container or veri.get("birincil") != is_birincil:
			if veri.container: veri.container.queue_free()
			veri.container = _boss_kart_olustur(veri, Vector2(x_pos, y_pos), is_birincil)
			veri["birincil"] = is_birincil
			add_child(veri.container)
		else:
			# Sadece pozisyon ve görünürlük güncelle
			veri.container.position = Vector2(x_pos, y_pos)
			veri.container.visible = true
		
		visible_count += 1

func _boss_kart_olustur(veri: Dictionary, offset: Vector2, birincil: bool) -> Control:
	var c: Control = Control.new()
	c.position = offset
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if birincil:
		# 1 — Büyük boss kafa hexagonu (x=0)
		var kafa = _hex_ciz(Vector2(0, 0), HEX_BUYUK_R, BOSS_RENKLER.get(veri.tip, Color.WHITE), veri.tip)
		c.add_child(kafa)

		# 2 — Atak önizleme hexleri
		var atak_baslangic_x: float = (HEX_BUYUK_R * 2.0) + KAFA_ATAK_ARASI
		for j: int in 3:
			var atak_x: float = atak_baslangic_x + j * (HEX_KUCUK_R * 2.0 + ATAK_ARASI)
			var atak_hex = _atak_hex_ciz(Vector2(atak_x, (HEX_BUYUK_R - HEX_KUCUK_R)), HEX_KUCUK_R, veri.gelecek_ataklar[j] if j < veri.gelecek_ataklar.size() else "")
			c.add_child(atak_hex)

		# ... hex
		var nokta_x: float = atak_baslangic_x + 3 * (HEX_KUCUK_R * 2.0 + ATAK_ARASI)
		var nokta_hex = _nokta_hex_ciz(Vector2(nokta_x, (HEX_BUYUK_R - HEX_KUCUK_R)), HEX_KUCUK_R)
		c.add_child(nokta_hex)

		# 3 — Can barı (ALTTA)
		var canbar = _canbar_olustur(veri, HEX_BUYUK_R)
		canbar.name = "CanBarı"
		canbar.position = Vector2(0, HEX_BUYUK_R * 2.0 + CANBAR_OFFSET_Y)
		c.add_child(canbar)
	else:
		# Küçük kafa + sağda can barı
		var r_orta: float = HEX_ORTA_R
		var kafa = _hex_ciz(Vector2(0, 0), r_orta, BOSS_RENKLER.get(veri.tip, Color.WHITE), veri.tip)
		c.add_child(kafa)
		
		var canbar = _canbar_olustur(veri, HEX_BUYUK_R)
		canbar.name = "CanBarı"
		canbar.position = Vector2(r_orta * 2.0 + 8.0, r_orta - (CANBAR_H / 2.0))
		c.add_child(canbar)

	return c

func _canbari_guncelle(veri: Dictionary) -> void:
	if not veri.container: return
	
	var canbar = veri.container.get_node_or_null("CanBarı")
	if not canbar: return
	
	var parca_sayisi = veri.max_hp
	var renk = BOSS_RENKLER.get(veri.tip, Color.WHITE)
	var sönük_renk = Color(renk.r * 0.15, renk.g * 0.15, renk.b * 0.15)
	
	# Can bari içindeki ColorRect'leri bul ve güncelle
	# _canbar_olustur içinde ColorRect'leri çocuk olarak ekliyoruz.
	var bar_parcalari = canbar.get_children()
	if bar_parcalari.size() != parca_sayisi: return
	
	for i in range(parca_sayisi):
		var parca = bar_parcalari[i] as ColorRect
		if parca:
			# Sağdan sola sönme mantığı: (parca_sayisi - i) <= current_hp
			var dolu = (parca_sayisi - i) <= int(veri.current_hp)
			parca.color = renk if dolu else sönük_renk

# ── ÇİZİM FONKSİYONLARI (Kalıcı node olarak oluşturulur) ──────────────────────

func _hex_noktalar(merkez: Vector2, r: float) -> PackedVector2Array:
	var noktalar: PackedVector2Array = PackedVector2Array()
	for i: int in 6:
		var aci: float = deg_to_rad(60.0 * i - 30.0)
		noktalar.append(merkez + Vector2(cos(aci), sin(aci)) * r)
	return noktalar

func _hex_ciz(pos: Vector2, r: float, renk: Color, tip: String) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = pos

	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = _hex_noktalar(Vector2(r, r), r)
	polygon.color = Color(renk.r * 0.15, renk.g * 0.15, renk.b * 0.15, 0.92)
	n.add_child(polygon)

	var line: Line2D = Line2D.new()
	var pts: PackedVector2Array = _hex_noktalar(Vector2(r, r), r)
	for p: Vector2 in pts: line.add_point(p)
	line.add_point(pts[0])
	line.default_color = Color(0.96, 0.773, 0.094)
	line.width = 3.0
	n.add_child(line)

	var dosya_tipi: String = tip
	if tip == "asit": dosya_tipi = "acid"
	elif tip == "tas" or tip == "kaya": dosya_tipi = "stone"
	elif tip == "zar": dosya_tipi = "dice"
	
	var tex_path: String = "res://Assets/" + dosya_tipi + "_hex.png"
	if ResourceLoader.exists(tex_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(tex_path)
		sprite.position = Vector2(r, r)
		sprite.scale = Vector2(0.035, 0.035) 
		n.add_child(sprite)
	return n

func _atak_hex_ciz(pos: Vector2, r: float, atak_tipi: String) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = pos

	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = _hex_noktalar(Vector2(r, r), r)
	polygon.color = Color(0.05, 0.05, 0.05, 0.9)
	n.add_child(polygon)

	var line: Line2D = Line2D.new()
	var pts: PackedVector2Array = _hex_noktalar(Vector2(r, r), r)
	for p: Vector2 in pts: line.add_point(p)
	line.add_point(pts[0])
	line.default_color = Color(0.96, 0.773, 0.094)
	line.width = 2.0
	n.add_child(line)

	var tex_path: String = ATAK_IKONLAR.get(atak_tipi, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(tex_path)
		sprite.position = Vector2(r, r)
		sprite.scale = Vector2(0.018, 0.018)
		n.add_child(sprite)
	return n

func _nokta_hex_ciz(pos: Vector2, r: float) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = pos
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = _hex_noktalar(Vector2(r, r), r)
	polygon.color = Color(0.05, 0.05, 0.05, 0.7)
	n.add_child(polygon)
	var line: Line2D = Line2D.new()
	var pts: PackedVector2Array = _hex_noktalar(Vector2(r, r), r)
	for p: Vector2 in pts: line.add_point(p)
	line.add_point(pts[0])
	line.default_color = Color(0.35, 0.35, 0.35)
	line.width = 1.5
	n.add_child(line)

	var label := Label.new()
	label.text = "···"
	label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(r * 0.3, r * 0.4)
	n.add_child(label)
	return n

func _canbar_olustur(veri: Dictionary, r: float) -> Control:
	var c: Control = Control.new()
	var toplam_genislik: float = r * 2.0
	var parca_sayisi: int = veri.max_hp
	var bosluk: float = 2.0
	var parca_genislik: float = (toplam_genislik - bosluk * (parca_sayisi - 1)) / float(parca_sayisi)
	var renk: Color = BOSS_RENKLER.get(veri.tip, Color.WHITE)
	var sönük_renk = Color(renk.r * 0.15, renk.g * 0.15, renk.b * 0.15)

	for i: int in parca_sayisi:
		var parca: ColorRect = ColorRect.new()
		parca.size = Vector2(parca_genislik, CANBAR_H)
		var dolu: bool = (parca_sayisi - i) <= int(veri.current_hp)
		parca.color = renk if dolu else sönük_renk
		var x_pos: float = (parca_sayisi - 1 - i) * (parca_genislik + bosluk)
		parca.position = Vector2(x_pos, 0)
		c.add_child(parca)

	c.custom_minimum_size = Vector2(toplam_genislik, CANBAR_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
