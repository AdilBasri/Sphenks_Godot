extends Control
# boss_ui.gd
# Sağ üst köşe boss UI — her boss için kafa hex + atak önizleme + can barı
# Sahne yapısı: CanvasLayer > BossUI (bu script)
# Her boss spawn olunca boss_ekle(), ölünce boss_kaldir() çağrılır

# ──────────────────────────────────────────────────────────────────────────────
# AJUSTABLE CONSTANTS (DEĞİŞTİRİLEBİLİR AYARLAR)
# ──────────────────────────────────────────────────────────────────────────────
const BOSS_OFFSET_Y   : float = 80.0           # Bosslar arası dikey mesafe
const BOSS_MARGIN_RIGHT: float = 40.0          # Ekranın sağından olan genel boşluk
const BOSS_TOP_MARGIN : float = 40.0           # Ekranın üstünden olan boşluk

const HEX_BUYUK_R    : float = 18.0            # Boss kafa (büyük hex) yarıçapı
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
# Her boss için tutulan veri
# { "boss_ref": Node, "tip": String, "max_hp": int, "current_hp": int,
#   "gelecek_ataklar": Array, "container": Control }
var aktif_bosslar: Array = []

# ── HAZIRLIK ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_ui")
	# Anchor sağ üst köşe - Kapsayıcıyı tam sağ üst köşedeki bir "noktaya" sabitliyoruz
	anchor_left   = 1.0
	anchor_right  = 1.0
	anchor_top    = 0.0
	anchor_bottom = 0.0
	
	# Node'un kendisini bir nokta haline getiriyoruz. 
	# Böylece (0,0) koordinatı tam olarak ekranın sağ üst köşesi olur.
	# Çocukları negatif X vererek sağdan sola dizeceğiz.
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	size = Vector2(0, 0)

	# Görünürlük değişikliklerini izlemek için basit bir timer
	var timer: Timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_ui_yenile)
	add_child(timer)

# ── PUBLIC API ────────────────────────────────────────────────────────────────

## Yeni boss ekle — boss spawn olunca çağır
func boss_ekle(boss_ref: Node, tip: String, max_hp: int) -> void:
	# Mükerrer kaydı engelle
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

## Boss hasar aldı — hasar_al() içinden çağır
func boss_hasar_guncelle(boss_ref: Node, yeni_hp: int) -> void:
	for veri in aktif_bosslar:
		if veri.boss_ref == boss_ref:
			veri.current_hp = max(yeni_hp, 0)
			_ui_yenile()
			return

## Boss öldü — queue_free öncesinde çağır
func boss_kaldir(boss_ref: Node) -> void:
	for i: int in aktif_bosslar.size():
		var veri: Dictionary = aktif_bosslar[i]
		if veri.boss_ref == boss_ref:
			if veri.container:
				veri.container.queue_free()
			aktif_bosslar.remove_at(i)
			_ui_yenile()
			return

## Gelecek atakları güncelle (opsiyonel — şimdilik sabit)
func atak_guncelle(boss_ref: Node, ataklar: Array) -> void:
	for veri in aktif_bosslar:
		if veri.boss_ref == boss_ref:
			veri.gelecek_ataklar = ataklar
			_ui_yenile()
			return

# ── İÇ YARDIMCILAR ───────────────────────────────────────────────────────────

func _varsayilan_ataklar(tip: String) -> Array:
	# Şimdilik her boss kendi atak tipini tekrar eder
	return [tip, tip, tip]

func _ui_yenile() -> void:
	# Tüm mevcut container'ları gizle veya sil
	for child in get_children():
		if not child is Timer:
			child.queue_free()

	# Kartın toplam genişliğini hesapla
	# Atakların bittiği nokta (Ellipsis dahil)
	var ataklar_toplam_w: float = KAFA_ATAK_ARASI + (3.0 * (HEX_KUCUK_R * 2.0 + ATAK_ARASI)) + (HEX_KUCUK_R * 2.0)
	var kart_toplam_w: float = (HEX_BUYUK_R * 2.0) + ataklar_toplam_w

	var visible_count: int = 0
	for i: int in aktif_bosslar.size():
		var veri: Dictionary = aktif_bosslar[i]
		
		# Boss referansı geçerli mi ve sahnede görünür mu kontrol et
		var is_visible: bool = false
		if is_instance_valid(veri.boss_ref):
			if "visible" in veri.boss_ref:
				is_visible = veri.boss_ref.visible
			else:
				is_visible = true
		
		if not is_visible:
			veri.container = null
			continue

		# Kartı sağa yaslıyoruz: Ellipsis en sağda olsun istendiği için x_pos'u buna göre kuruyoruz
		# Boss Kafası (Local 0,0) en solda olacak.
		# O zaman kafa.pos = screen_right - margin - kart_w
		var x_pos: float = -BOSS_MARGIN_RIGHT - kart_toplam_w
		var y_pos: float = BOSS_TOP_MARGIN + (visible_count * BOSS_OFFSET_Y)
		
		# Bosslar üst üste binmesin diye basamak etkisi (opsiyonel)
		# x_pos -= visible_count * 20.0 

		var container: Control = _boss_kart_olustur(veri, Vector2(x_pos, y_pos))
		veri.container = container
		add_child(container)
		visible_count += 1

func _boss_kart_olustur(veri: Dictionary, offset: Vector2) -> Control:
	var c: Control = Control.new()
	c.position = offset

	# 1 — Büyük boss kafa hexagonu (EN SOLDA: x=0)
	var kafa: Node2D = _hex_ciz(
		Vector2(0, 0),
		HEX_BUYUK_R,
		BOSS_RENKLER.get(veri.tip, Color.WHITE),
		veri.tip
	)
	c.add_child(kafa)

	# 2 — Atak önizleme hexleri (Kafanın SAĞINDA sırayla)
	var atak_baslangic_x: float = (HEX_BUYUK_R * 2.0) + KAFA_ATAK_ARASI
	for j: int in 3:
		var atak_x: float = atak_baslangic_x + j * (HEX_KUCUK_R * 2.0 + ATAK_ARASI)
		var atak_hex: Node2D = _atak_hex_ciz(
			Vector2(atak_x, (HEX_BUYUK_R - HEX_KUCUK_R)), # Merkeze hizalı
			HEX_KUCUK_R,
			veri.gelecek_ataklar[j] if j < veri.gelecek_ataklar.size() else ""
		)
		c.add_child(atak_hex)

	# ... hex (EN SAĞDA)
	var nokta_x: float = atak_baslangic_x + 3 * (HEX_KUCUK_R * 2.0 + ATAK_ARASI)
	var nokta_hex: Node2D = _nokta_hex_ciz(Vector2(nokta_x, (HEX_BUYUK_R - HEX_KUCUK_R)), HEX_KUCUK_R)
	c.add_child(nokta_hex)

	# 3 — Can barı (KAFANIN TAM ALTINDA merkezlenmiş)
	var canbar: Control = _canbar_olustur(veri)
	# canbar genişliği kafa genişliği kadar (2*R)
	canbar.position = Vector2(0, HEX_BUYUK_R * 2.0 + CANBAR_OFFSET_Y)
	c.add_child(canbar)

	# Container boyutunu ayarla (mouse filter yok — tıklanamaz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# ── HEX ÇİZİCİLER ────────────────────────────────────────────────────────────

func _hex_noktalar(merkez: Vector2, r: float) -> PackedVector2Array:
	var noktalar: PackedVector2Array = PackedVector2Array()
	for i: int in 6:
		var aci: float = deg_to_rad(60.0 * i - 30.0)  # Düz üst
		noktalar.append(merkez + Vector2(cos(aci), sin(aci)) * r)
	return noktalar

func _hex_ciz(pos: Vector2, r: float, renk: Color, tip: String) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = pos

	# Arka plan çizimi
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = _hex_noktalar(Vector2(r, r), r)
	polygon.color = Color(renk.r * 0.15, renk.g * 0.15, renk.b * 0.15, 0.92)
	n.add_child(polygon)

	# Çerçeve
	var line: Line2D = Line2D.new()
	var pts: PackedVector2Array = _hex_noktalar(Vector2(r, r), r)
	for p: Vector2 in pts:
		line.add_point(p)
	line.add_point(pts[0])
	line.default_color = Color(0.96, 0.773, 0.094)  # Altın
	line.width = 3.0
	n.add_child(line)

	# Texture varsa göster, yoksa renkli daire
	# Örn: res://Assets/acid_hex.png
	var dosya_tipi: String = tip
	if tip == "asit": dosya_tipi = "acid"
	if tip == "tas" or tip == "kaya": dosya_tipi = "stone"
	if tip == "zar": dosya_tipi = "dice"
	
	var tex_path: String = "res://Assets/" + dosya_tipi + "_hex.png"
	if ResourceLoader.exists(tex_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(tex_path)
		sprite.position = Vector2(r, r)
		# 1024'lük texture için r=18 d=36. 36/1024 = 0.035
		sprite.scale = Vector2(0.035, 0.035) 
		n.add_child(sprite)
	else:
		# Placeholder: renkli daire
		var circle: Polygon2D = Polygon2D.new()
		var pts2: PackedVector2Array = PackedVector2Array()
		for i_c: int in 32:
			var a: float = deg_to_rad(360.0 / 32.0 * i_c)
			pts2.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r * 0.55)
		circle.polygon = pts2
		circle.color = renk
		n.add_child(circle)

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
	for p: Vector2 in pts:
		line.add_point(p)
	line.add_point(pts[0])
	line.default_color = Color(0.96, 0.773, 0.094)
	line.width = 2.0
	n.add_child(line)

	# Atak ikonu
	var tex_path: String = ATAK_IKONLAR.get(atak_tipi, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(tex_path)
		sprite.position = Vector2(r, r)
		# Küçük hex r=9 d=18. 18/1024 = 0.0175.
		sprite.scale = Vector2(0.018, 0.018)
		n.add_child(sprite)
	else:
		# Placeholder: atak tipine göre renk
		var renk: Color = BOSS_RENKLER.get(atak_tipi, Color.GRAY)
		var circle: Polygon2D = Polygon2D.new()
		var pts2: PackedVector2Array = PackedVector2Array()
		for i: int in 16:
			var a: float = deg_to_rad(360.0 / 16.0 * i)
			pts2.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r * 0.5)
		circle.polygon = pts2
		circle.color = renk
		n.add_child(circle)

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
	for p: Vector2 in pts:
		line.add_point(p)
	line.add_point(pts[0])
	line.default_color = Color(0.35, 0.35, 0.35)
	line.width = 1.5
	n.add_child(line)

	# "..." label
	var label := Label.new()
	label.text = "···"
	label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(r * 0.3, r * 0.4)
	n.add_child(label)

	return n

# ── CAN BARI ──────────────────────────────────────────────────────────────────

func _canbar_olustur(veri: Dictionary) -> Control:
	var c: Control = Control.new()
	var toplam_genislik: float = HEX_BUYUK_R * 2.0
	var parca_sayisi: int = veri.max_hp
	var bosluk: float = 2.0
	var parca_genislik: float = (toplam_genislik - bosluk * (parca_sayisi - 1)) / float(parca_sayisi)

	for i: int in parca_sayisi:
		var parca: ColorRect = ColorRect.new()
		parca.size = Vector2(parca_genislik, CANBAR_H)
		# Sağdan sola sönme: son parçalar önce solar
		# i = 0 en sol (son sönen), i = max_hp-1 en sağ (ilk sönen)
		var dolu: bool = (parca_sayisi - i) <= int(veri.current_hp)
		var renk: Color = BOSS_RENKLER.get(veri.tip, Color.WHITE)
		parca.color = renk if dolu else Color(renk.r * 0.15, renk.g * 0.15, renk.b * 0.15)
		# Sağdan sola: en sağdaki parça index (max_hp - 1)
		var x_pos: float = (parca_sayisi - 1 - i) * (parca_genislik + bosluk)
		parca.position = Vector2(x_pos, 0)
		c.add_child(parca)

	c.custom_minimum_size = Vector2(toplam_genislik, CANBAR_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
