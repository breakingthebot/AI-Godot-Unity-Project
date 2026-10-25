# godot_project/scripts/title_screen.gd
# Dark-Fantasy Pixel-Art Title Screen & 4-Hero Pantheon Selector Overlay.
# Renders animated rising embers, flickering torch sconces, Citadel Crest Emblem,
# 4 interactive Hero Cards ([1]-[4]), and direct launch into the 2D Dungeon Crawler or HUD.
# Connects to: godot_project/scripts/character_loader.gd, godot_project/scripts/arena_controller.gd,
#              godot_project/scripts/character_sheet_hud.gd, godot_project/scripts/sprite_art_generator.gd
# Created: 2026-10-25

extends CanvasLayer
class_name TitleScreen

const SpriteArtGeneratorScript = preload("res://scripts/sprite_art_generator.gd")

const HERO_ROSTER_META: Array[Dictionary] = [
	{
		"slot": 0,
		"id": "char_001",
		"name": "Kaelen",
		"class_title": "Elf Ranger",
		"weapon": "Emberwood Longbow",
		"signature": "Ultimate [Q]: Arrow Storm Volley",
		"specialty": "High DEX • Crit Chance • Ranged Kiting",
		"accent": Color(0.28, 0.78, 0.48)
	},
	{
		"slot": 1,
		"id": "ash_001",
		"name": "Malakor, The Ash-Knight",
		"class_title": "Ashen Paladin",
		"weapon": "Obsidian Greatsword",
		"signature": "Ultimate [Q]: Consecrated Ember Nova",
		"specialty": "High STR • Heavy Armor • Frontline Tank",
		"accent": Color(0.92, 0.45, 0.22)
	},
	{
		"slot": 2,
		"id": "ash_002",
		"name": "Vespera, Echo-Wraith",
		"class_title": "Shadow Assassin",
		"weapon": "Twin Phase Daggers",
		"signature": "Ultimate [Q]: Phantom Blade Storm",
		"specialty": "Lethal Crits • Fast Dash • Backstab",
		"accent": Color(0.65, 0.42, 0.95)
	},
	{
		"slot": 3,
		"id": "ash_003",
		"name": "Gorvath, Rotting Sentinel",
		"class_title": "Blight Warden",
		"weapon": "Runic Plague Maul",
		"signature": "Ultimate [Q]: Putrid Tremor Slam",
		"specialty": "High CON/WIS • Iron Bulwark • Sustain",
		"accent": Color(0.55, 0.78, 0.32)
	}
]

var loader: Node = null
var hud: CanvasLayer = null
var arena: Node2D = null
var sfx: Node = null
var sprite_gen: RefCounted = null

var selected_slot: int = 0
var dismiss_count: int = 0
var _anim_time: float = 0.0
var _embers: Array[Dictionary] = []

# UI Node References constructed deterministically in _build_ui()
var backdrop_canvas: Control = null
var crest_icon: TextureRect = null
var title_label: Label = null
var subtitle_label: Label = null
var status_banner: Label = null
var hero_cards: Array[PanelContainer] = []
var hero_sprites: Array[TextureRect] = []
var enter_citadel_btn: Button = null
var continue_run_btn: Button = null
var open_sheet_btn: Button = null


class TitleBackdropCanvas extends Control:
	var owner_screen: TitleScreen = null

	func _draw() -> void:
		if owner_screen == null:
			return
		owner_screen._draw_backdrop(self)


func _ready() -> void:
	layer = 20
	sprite_gen = SpriteArtGeneratorScript.new()
	_init_embers()
	_build_ui()
	_bind_siblings()
	_refresh_card_selection()


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	_step_embers(delta)
	# Animate 2-frame hero preview sprites every 0.45s
	var frame_idx: int = int(_anim_time / 0.45) % 2
	if sprite_gen != null:
		for i in range(mini(hero_sprites.size(), HERO_ROSTER_META.size())):
			var char_id: String = str(HERO_ROSTER_META[i].get("id", "char_001"))
			var tex: Texture2D = sprite_gen.get_hero_texture(char_id, frame_idx)
			if tex != null and hero_sprites[i] != null:
				hero_sprites[i].texture = tex
	if backdrop_canvas != null:
		backdrop_canvas.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ESCAPE:
		toggle_title_screen()
		get_viewport().set_input_as_handled()
	elif visible and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
		enter_citadel_arena()
		get_viewport().set_input_as_handled()


func _bind_siblings() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent.has_method("select_roster_character"):
		loader = parent
		if not loader.character_loaded.is_connected(_on_loader_character_loaded):
			loader.character_loaded.connect(_on_loader_character_loaded)
	hud = parent.get_node_or_null("CharacterSheetHUD") as CanvasLayer
	arena = parent.get_node_or_null("Arena") as Node2D
	sfx = parent.get_node_or_null("ProceduralSfx")


func _init_embers() -> void:
	_embers.clear()
	for i in range(36):
		_embers.append({
			"x": float((i * 37 + 29) % 1260) + 10.0,
			"y": float((i * 53 + 17) % 700) + 10.0,
			"vy": 22.0 + float((i * 19) % 34),
			"vx": float((i % 5) - 2) * 6.5,
			"size": 2.0 + float(i % 3) * 1.5,
			"warmth": float(i % 4) * 0.25
		})


func _step_embers(delta: float) -> void:
	for ember in _embers:
		ember["y"] = float(ember.get("y", 0.0)) - float(ember.get("vy", 28.0)) * delta
		ember["x"] = float(ember.get("x", 0.0)) + sin(_anim_time * 1.8 + float(ember.get("vy", 0.0))) * 12.0 * delta
		if float(ember["y"]) < -10.0:
			ember["y"] = 725.0
			ember["x"] = fposmod(float(ember["x"]) + 97.0, 1280.0)


func _draw_backdrop(canvas: Control) -> void:
	var vp_size: Vector2 = canvas.size
	if vp_size.x <= 10.0 or vp_size.y <= 10.0:
		vp_size = Vector2(1280.0, 720.0)

	# 1. Deep Obsidian Citadel Background
	canvas.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.04, 0.04, 0.06, 0.97), true)

	# 2. Subtle Stone Masonry Grid Lines
	var grid_col := Color(0.11, 0.10, 0.15, 0.42)
	var step_x: int = 64
	var step_y: int = 48
	for y in range(0, int(vp_size.y), step_y):
		canvas.draw_line(Vector2(0, y), Vector2(vp_size.x, y), grid_col, 1.0)
		var offset_x: int = (y / step_y % 2) * (step_x / 2)
		for x in range(offset_x, int(vp_size.x), step_x):
			canvas.draw_line(Vector2(x, y), Vector2(x, y + step_y), grid_col, 1.0)

	# 3. Twin Flickering Torch Sconces Flanking the Citadel Crest
	var pulse: float = 0.85 + 0.15 * sin(_anim_time * 6.5)
	var torch_positions: Array[Vector2] = [
		Vector2(vp_size.x * 0.23, 108.0),
		Vector2(vp_size.x * 0.77, 108.0)
	]
	for tpos in torch_positions:
		canvas.draw_circle(tpos, 58.0 * pulse, Color(0.96, 0.42, 0.12, 0.11 * pulse))
		canvas.draw_circle(tpos, 32.0 * pulse, Color(0.98, 0.68, 0.18, 0.20 * pulse))
		# Iron bracket + flame pixel blocks
		canvas.draw_rect(Rect2(tpos + Vector2(-4, 4), Vector2(8, 22)), Color(0.32, 0.26, 0.22), true)
		canvas.draw_rect(Rect2(tpos + Vector2(-7, -10), Vector2(14, 14)), Color(0.98, 0.45, 0.12), true)
		canvas.draw_rect(Rect2(tpos + Vector2(-4, -16 * pulse), Vector2(8, 12)), Color(1.0, 0.86, 0.28), true)

	# 4. Rising Cinder & Ember Particles
	for ember in _embers:
		var pos := Vector2(float(ember.get("x", 0.0)), float(ember.get("y", 0.0)))
		var sz: float = float(ember.get("size", 3.0))
		var w: float = float(ember.get("warmth", 0.5))
		var col := Color(0.98, 0.38 + w * 0.48, 0.14, 0.72)
		canvas.draw_rect(Rect2(pos, Vector2(sz, sz)), col, true)

	# 5. Ornate Outer Double Gold/Obsidian Citadel Frame
	var outer := Rect2(Vector2(18, 14), vp_size - Vector2(36, 28))
	var inner := Rect2(Vector2(24, 20), vp_size - Vector2(48, 40))
	canvas.draw_rect(outer, Color(0.84, 0.66, 0.24, 0.85), false, 2.0)
	canvas.draw_rect(inner, Color(0.45, 0.32, 0.16, 0.65), false, 1.0)


func _build_ui() -> void:
	backdrop_canvas = TitleBackdropCanvas.new()
	backdrop_canvas.name = "TitleBackdropCanvas"
	backdrop_canvas.owner_screen = self
	backdrop_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop_canvas)

	var margin := MarginContainer.new()
	margin.name = "TitleMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "TitleRootVBox"
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# --- 1. Crest + Grand Title Header ---
	var header_vbox := VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(header_vbox)

	var crest_row := HBoxContainer.new()
	crest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_row.add_theme_constant_override("separation", 14)
	header_vbox.add_child(crest_row)

	crest_icon = TextureRect.new()
	crest_icon.name = "CitadelCrestIcon"
	crest_icon.custom_minimum_size = Vector2(52, 52)
	crest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite_gen != null:
		crest_icon.texture = sprite_gen.get_prop_texture("ui_crest_emblem")
	crest_row.add_child(crest_icon)

	var title_text_vbox := VBoxContainer.new()
	title_text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_row.add_child(title_text_vbox)

	title_label = Label.new()
	title_label.name = "GameTitleLabel"
	title_label.text = "ASHEN PANTHEON: CITADEL OF ASH"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.36))
	title_text_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "GameSubtitleLabel"
	subtitle_label.text = "Dark-Fantasy 2D Pixel-Art Roguelike Dungeon Crawler  •  v2.8.0  •  Godot 4.4.1 & Unity 6"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.76, 0.74, 0.82))
	title_text_vbox.add_child(subtitle_label)

	# --- 2. Choose Your Champion Prompt ---
	var select_prompt := Label.new()
	select_prompt.text = "— SELECT YOUR ASHEN CHAMPION ([1] – [4] OR CLICK CARD) —"
	select_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_prompt.add_theme_font_size_override("font_size", 13)
	select_prompt.add_theme_color_override("font_color", Color(0.92, 0.66, 0.28))
	root_vbox.add_child(select_prompt)

	# --- 3. 4-Hero Interactive Pantheon Cards ---
	var cards_hbox := HBoxContainer.new()
	cards_hbox.name = "HeroCardsHBox"
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 14)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cards_hbox)

	hero_cards.clear()
	hero_sprites.clear()

	for meta in HERO_ROSTER_META:
		var slot_idx: int = int(meta.get("slot", 0))
		var char_id: String = str(meta.get("id", "char_001"))
		var accent: Color = meta.get("accent", Color.GOLD)

		var card := PanelContainer.new()
		card.name = "HeroCard_%d" % slot_idx
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(250, 270)
		cards_hbox.add_child(card)
		hero_cards.append(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 14)
		card_margin.add_theme_constant_override("margin_right", 14)
		card_margin.add_theme_constant_override("margin_top", 12)
		card_margin.add_theme_constant_override("margin_bottom", 12)
		card.add_child(card_margin)

		var card_vbox := VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", 6)
		card_margin.add_child(card_vbox)

		var key_badge := Label.new()
		key_badge.text = "[%d] %s" % [slot_idx + 1, str(meta.get("class_title", "Hero")).to_upper()]
		key_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_badge.add_theme_font_size_override("font_size", 12)
		key_badge.add_theme_color_override("font_color", accent)
		card_vbox.add_child(key_badge)

		# Sprite + Weapon Preview Row
		var preview_hbox := HBoxContainer.new()
		preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_hbox.add_theme_constant_override("separation", 12)
		card_vbox.add_child(preview_hbox)

		var hero_tex_rect := TextureRect.new()
		hero_tex_rect.name = "HeroPreview_%d" % slot_idx
		hero_tex_rect.custom_minimum_size = Vector2(72, 72)
		hero_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if sprite_gen != null:
			hero_tex_rect.texture = sprite_gen.get_hero_texture(char_id, 0)
		preview_hbox.add_child(hero_tex_rect)
		hero_sprites.append(hero_tex_rect)

		var weapon_tex_rect := TextureRect.new()
		weapon_tex_rect.custom_minimum_size = Vector2(40, 40)
		weapon_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		weapon_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if sprite_gen != null:
			weapon_tex_rect.texture = sprite_gen.get_weapon_texture(char_id)
		preview_hbox.add_child(weapon_tex_rect)

		var name_lbl := Label.new()
		name_lbl.text = str(meta.get("name", "Hero"))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
		card_vbox.add_child(name_lbl)

		var weapon_lbl := Label.new()
		weapon_lbl.text = "Armament: %s" % str(meta.get("weapon", "Weapon"))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.add_theme_font_size_override("font_size", 12)
		weapon_lbl.add_theme_color_override("font_color", Color(0.84, 0.78, 0.64))
		card_vbox.add_child(weapon_lbl)

		var spec_lbl := Label.new()
		spec_lbl.text = str(meta.get("specialty", ""))
		spec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec_lbl.add_theme_font_size_override("font_size", 11)
		spec_lbl.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
		card_vbox.add_child(spec_lbl)

		var ult_lbl := Label.new()
		ult_lbl.text = str(meta.get("signature", ""))
		ult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ult_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ult_lbl.add_theme_font_size_override("font_size", 11)
		ult_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.34))
		card_vbox.add_child(ult_lbl)

		var pick_btn := Button.new()
		pick_btn.name = "SelectHeroButton_%d" % slot_idx
		pick_btn.text = "Select %s [%d]" % [str(meta.get("name", "Hero")).split(" ")[0], slot_idx + 1]
		pick_btn.pressed.connect(select_hero_on_title.bind(slot_idx))
		card_vbox.add_child(pick_btn)

	# --- 4. Primary Action Bar (Enter Citadel / Continue Saved Run / Character Sheet) ---
	var actions_hbox := HBoxContainer.new()
	actions_hbox.name = "TitleActionsHBox"
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 18)
	root_vbox.add_child(actions_hbox)

	enter_citadel_btn = Button.new()
	enter_citadel_btn.name = "EnterCitadelButton"
	enter_citadel_btn.text = "⚔  ENTER THE CITADEL (2D ARENA) [ENTER]  ⚔"
	enter_citadel_btn.custom_minimum_size = Vector2(360, 46)
	enter_citadel_btn.add_theme_font_size_override("font_size", 15)
	enter_citadel_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	enter_citadel_btn.pressed.connect(enter_citadel_arena)
	actions_hbox.add_child(enter_citadel_btn)

	continue_run_btn = Button.new()
	continue_run_btn.name = "ContinueRunButton"
	continue_run_btn.text = "CONTINUE SAVED RUN [F9]"
	continue_run_btn.custom_minimum_size = Vector2(240, 46)
	continue_run_btn.add_theme_font_size_override("font_size", 14)
	continue_run_btn.pressed.connect(continue_saved_run)
	actions_hbox.add_child(continue_run_btn)

	open_sheet_btn = Button.new()
	open_sheet_btn.name = "OpenSheetButton"
	open_sheet_btn.text = "CHARACTER SHEET & LORE [TAB]"
	open_sheet_btn.custom_minimum_size = Vector2(250, 46)
	open_sheet_btn.add_theme_font_size_override("font_size", 14)
	open_sheet_btn.pressed.connect(open_character_sheet)
	actions_hbox.add_child(open_sheet_btn)

	# --- 5. Status & Controls Footer ---
	status_banner = Label.new()
	status_banner.name = "TitleStatusBanner"
	status_banner.text = "Champion Ready: Sylvara Emberveil (Ashen Ranger)  •  Press [ENTER] to Enter the Dungeon or [ESC] Anytime to Return Here"
	status_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_banner.add_theme_font_size_override("font_size", 12)
	status_banner.add_theme_color_override("font_color", Color(0.68, 0.86, 0.72))
	root_vbox.add_child(status_banner)


## Selects one of the 4 Ashen Pantheon heroes (`0`..`3`) on the Title Screen and syncs CharacterLoader.
func select_hero_on_title(slot_index: int) -> Dictionary:
	var clamped: int = clampi(slot_index, 0, HERO_ROSTER_META.size() - 1)
	selected_slot = clamped
	if loader != null and loader.has_method("select_roster_character"):
		loader.select_roster_character(clamped)
	_refresh_card_selection()
	if sfx != null and sfx.has_method("play_cue"):
		sfx.play_cue("relic_loot")
	var meta: Dictionary = HERO_ROSTER_META[clamped]
	if status_banner != null:
		status_banner.text = "Champion Selected: %s (%s) — Press [ENTER] to Enter the Citadel!" % [
			str(meta.get("name", "Hero")),
			str(meta.get("class_title", "Class"))
		]
	return {
		"selected_slot": selected_slot,
		"character_id": str(meta.get("id", "char_001")),
		"name": str(meta.get("name", "Hero"))
	}


func _on_loader_character_loaded(character_data: Dictionary) -> void:
	var char_id: String = str(character_data.get("character_id", ""))
	for i in range(HERO_ROSTER_META.size()):
		if str(HERO_ROSTER_META[i].get("id", "")) == char_id:
			selected_slot = i
			break
	_refresh_card_selection()


func _refresh_card_selection() -> void:
	for i in range(hero_cards.size()):
		var card: PanelContainer = hero_cards[i]
		if card == null:
			continue
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		if i == selected_slot:
			var accent: Color = HERO_ROSTER_META[i].get("accent", Color(0.98, 0.82, 0.32))
			style.bg_color = Color(0.13, 0.12, 0.18, 0.96)
			style.border_color = accent
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.07, 0.07, 0.10, 0.88)
			style.border_color = Color(0.26, 0.24, 0.32, 0.85)
			style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)


## Dismisses the Title Screen and launches directly into the 2D Dungeon Crawler Arena.
func enter_citadel_arena() -> Dictionary:
	dismiss_title_screen()
	if hud != null:
		hud.visible = false
	if arena != null and arena.has_method("set_arena_active"):
		arena.set_arena_active(true)
	if sfx != null and sfx.has_method("play_cue"):
		sfx.play_cue("level_up")
	return {
		"title_visible": visible,
		"mode": "arena",
		"selected_slot": selected_slot,
		"dismiss_count": dismiss_count
	}


## Loads saved party progression (`user://roster_save.json`) if available and enters the 2D Arena.
func continue_saved_run() -> Dictionary:
	var loaded_res: Dictionary = {}
	if loader != null and loader.has_method("load_party_progression"):
		loaded_res = loader.load_party_progression()
	var res := enter_citadel_arena()
	res["loaded_save"] = (str(loaded_res.get("status", "")) == "ok")
	return res


## Dismisses the Title Screen and opens the RPG Character Sheet HUD.
func open_character_sheet() -> Dictionary:
	dismiss_title_screen()
	if arena != null and arena.has_method("set_arena_active"):
		arena.set_arena_active(false)
	if hud != null:
		hud.visible = true
	return {
		"title_visible": visible,
		"mode": "character_sheet",
		"selected_slot": selected_slot,
		"dismiss_count": dismiss_count
	}


## Dismisses the Title Screen overlay.
func dismiss_title_screen() -> void:
	if visible:
		dismiss_count += 1
	visible = false


## Shows the Title Screen overlay.
func show_title_screen() -> void:
	visible = true
	_refresh_card_selection()


## Toggles the Title Screen overlay (`[ESC]` key).
func toggle_title_screen() -> bool:
	if visible:
		dismiss_title_screen()
	else:
		show_title_screen()
	return visible
