extends Node3D

# --- SAHNE REFERANSLARI ---
@export var gold_card: Area3D
@export var sleep_card: Area3D
@export var fire_light: OmniLight3D
@export var ui_tooltip: Label

# --- DEĞİŞKENLER ---
var selected_card: Area3D = null
var is_transitioning: bool = false
var original_scales: Dictionary = {}

func _ready():
	# Kartların orijinal boyutlarını kaydet
	if gold_card: original_scales[gold_card] = gold_card.scale
	if sleep_card: original_scales[sleep_card] = sleep_card.scale
	
	# Signal bağlantıları (Eğer editörden yapılmadıysa)
	_connect_card_signals(gold_card)
	_connect_card_signals(sleep_card)
	
	if ui_tooltip: ui_tooltip.text = "Bir yol seç..."

func _connect_card_signals(card: Area3D):
	if not card: return
	card.mouse_entered.connect(_on_card_hover_enter.bind(card))
	card.mouse_exited.connect(_on_card_hover_exit.bind(card))
	card.input_event.connect(_on_card_input.bind(card))

# --- MOUSE ETKİLEŞİMİ ---

func _on_card_hover_enter(card: Area3D):
	if is_transitioning: return
	
	# Scale Up Animation
	var t = create_tween()
	t.tween_property(card, "scale", original_scales[card] * 1.2, 0.2).set_trans(Tween.TRANS_BACK)
	
	# Tooltip Güncelle
	if ui_tooltip:
		if card == gold_card:
			ui_tooltip.text = "Açgözlülük: Altın ara (+15 Gold)"
			ui_tooltip.modulate = Color.GOLD
		elif card == sleep_card:
			ui_tooltip.text = "Dinlenme: Rüyalara dal (+1 Health)"
			ui_tooltip.modulate = Color.CYAN

func _on_card_hover_exit(card: Area3D):
	if is_transitioning: return
	
	# Scale Down Animation
	var t = create_tween()
	t.tween_property(card, "scale", original_scales[card], 0.2)
	
	if ui_tooltip:
		ui_tooltip.text = "Bir yol seç..."
		ui_tooltip.modulate = Color.WHITE

func _on_card_input(camera, event, position, normal, shape_idx, card: Area3D):
	if is_transitioning: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_card(card)

# --- SEÇİM MANTIĞI ---

func _select_card(card: Area3D):
	is_transitioning = true
	selected_card = card
	
	print("Kart Seçildi: ", card.name)
	
	# Diğer kartı yok et
	var other_card = sleep_card if card == gold_card else gold_card
	if other_card:
		var t_hide = create_tween()
		t_hide.tween_property(other_card, "scale", Vector3.ZERO, 0.5)
		t_hide.tween_callback(other_card.queue_free)
	
	# Seçilen kartı merkeze taşı ve parlat
	var t_select = create_tween()
	t_select.set_parallel(true)
	# Kamera önüne taşı (basit bir yaklaşım, kamera sabit varsayılıyor)
	t_select.tween_property(card, "position", Vector3(0, 1.5, 2.0), 1.0)
	t_select.tween_property(card, "rotation", Vector3(0, PI, 0), 1.0) # Düz bak
	
	await t_select.finished
	
	# Efekt uygula ve sahne değiştir
	if card == gold_card:
		_process_gold_choice()
	elif card == sleep_card:
		_process_sleep_choice()

func _process_gold_choice():
	# Altın ekle
	var amount = randi_range(10, 25)
	if GameManager:
		GameManager.toplam_altin += amount
		print("💰 Altın eklendi: ", amount)
	
	# UI Feedback (Geliştirilebilir: Floating Text)
	if ui_tooltip:
		ui_tooltip.text = "+%d Altın Kazandın!" % amount
	
	# Sonraki Combat Level'a geç
	await get_tree().create_timer(1.5).timeout
	var next_level = "res://PyroKoridoru.tscn" # Şimdilik Pyro'ya dönüyor, ilerde dinamik olabilir
	get_tree().change_scene_to_file(next_level)

func _process_sleep_choice():
	# İyileştir
	if GameManager:
		GameManager.oyuncu_kalan_bar = min(GameManager.oyuncu_kalan_bar + 1, GameManager.oyuncu_max_bar)
		print("💚 Oyuncu iyileşti. HP Bar: ", GameManager.oyuncu_kalan_bar)
	
	# StoryManager'a kaydet
	if StoryManager:
		StoryManager.record_sleep()
		var next_dream = StoryManager.get_next_dream_scene()
		
		# Rüya Sahnesine Geç
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file(next_dream)
