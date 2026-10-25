# godot_project/scripts/character_sheet_hud.gd
# Renders an interactive RPG Character Sheet HUD with 4-Hero Roster Switcher & Save/Load (F5/F9).
# Connects to: godot_project/scripts/character_loader.gd, godot_project/scripts/arena_controller.gd
# Created: 2026-10-24

extends CanvasLayer
class_name CharacterSheetHUD

const CharacterLoaderScript = preload("res://scripts/character_loader.gd")
const SpriteArtGeneratorScript = preload("res://scripts/sprite_art_generator.gd")
const DAMAGE_STEP: int = -9
const HEAL_STEP: int = 12
const MAX_LOG_ENTRIES: int = 8

var loader: Node = null
var arena: Node = null
var _portrait_gen: RefCounted = null

# UI Node References constructed deterministically in _build_ui()
var roster_bar: HBoxContainer
var hero_portrait: TextureRect
var title_label: Label
var subtitle_label: Label
var error_banner: Label
var hp_bar: ProgressBar
var hp_value_label: Label
var mana_bar: ProgressBar
var mana_value_label: Label
var attributes_grid: GridContainer
var skills_box: VBoxContainer
var inventory_box: VBoxContainer
var backstory_label: RichTextLabel
var combat_log_label: RichTextLabel

var _log_lines: Array[String] = []


func _ready() -> void:
	_build_ui()
	_bind_or_create_loader()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_TAB:
		toggle_arena_mode()
	elif key_event.keycode == KEY_1:
		_on_roster_slot_pressed(0)
	elif key_event.keycode == KEY_2:
		_on_roster_slot_pressed(1)
	elif key_event.keycode == KEY_3:
		_on_roster_slot_pressed(2)
	elif key_event.keycode == KEY_4:
		_on_roster_slot_pressed(3)
	elif key_event.keycode == KEY_F5:
		_on_save_party_pressed()
	elif key_event.keycode == KEY_F9:
		_on_load_party_pressed()
	elif key_event.keycode == KEY_L:
		_on_level_up_pressed()
	elif visible and key_event.keycode == KEY_R:
		_on_roll_skill_pressed(0)
	elif visible and key_event.keycode == KEY_D:
		_on_damage_pressed()
	elif visible and key_event.keycode == KEY_H:
		_on_heal_pressed()
	elif visible and key_event.keycode == KEY_C:
		_on_use_potion_pressed()


## Toggles between the Character Sheet HUD and the playable 2D Ranger Arena.
func toggle_arena_mode() -> void:
	if arena == null and get_parent() != null:
		arena = get_parent().get_node_or_null("Arena")
	if arena == null:
		return

	var entering_arena: bool = visible
	visible = not entering_arena
	if arena.has_method("set_arena_active"):
		arena.set_arena_active(entering_arena)
	if entering_arena:
		_append_log("[Mode Switch] Entered 2D Arena (WASD: Move, Click/Space: Attack, [1]-[4]: Swap Hero).")
	else:
		_append_log("[Mode Switch] Returned to Character Sheet HUD.")
		if loader != null:
			refresh_ui(loader.current_data)


## Finds a sibling/parent CharacterLoader or creates one if standalone.
func _bind_or_create_loader() -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("load_character_data"):
		loader = parent
		arena = parent.get_node_or_null("Arena")
		if arena != null and arena.has_signal("request_hud_toggle"):
			if not arena.request_hud_toggle.is_connected(toggle_arena_mode):
				arena.request_hud_toggle.connect(toggle_arena_mode)
	else:
		loader = CharacterLoaderScript.new()
		loader.name = "CharacterLoader"
		add_child(loader)

	if not loader.character_loaded.is_connected(_on_character_loaded):
		loader.character_loaded.connect(_on_character_loaded)
	if not loader.character_updated.is_connected(_on_character_updated):
		loader.character_updated.connect(_on_character_updated)
	if not loader.character_load_error.is_connected(_on_character_load_error):
		loader.character_load_error.connect(_on_character_load_error)

	_populate_roster_buttons()

	var existing_data: Dictionary = loader.current_data
	if not existing_data.is_empty():
		refresh_ui(existing_data)
		_append_log(
			"Loaded character sheet '%s' from res://data/CharacterData.json."
			% str(existing_data.get("name", "Unknown"))
		)
	else:
		var data: Dictionary = loader.load_character_data()
		if not data.is_empty():
			refresh_ui(data)


func _populate_roster_buttons() -> void:
	if roster_bar == null or loader == null:
		return
	for child in roster_bar.get_children():
		child.queue_free()

	var lbl := Label.new()
	lbl.text = "Party Roster (Keys 1–4):"
	lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	roster_bar.add_child(lbl)

	var entries: Array = loader.ROSTER_ENTRIES
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var btn := Button.new()
		btn.text = str(entry.get("label", "Hero"))
		btn.pressed.connect(_on_roster_slot_pressed.bind(i))
		roster_bar.add_child(btn)


## Builds the complete responsive HUD node hierarchy cleanly in code.
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.09, 0.13, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "RootMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Roster Switcher Bar (Slots 1-4)
	roster_bar = HBoxContainer.new()
	roster_bar.name = "RosterBar"
	roster_bar.add_theme_constant_override("separation", 10)
	main_vbox.add_child(roster_bar)

	# Error Banner (hidden by default)
	error_banner = Label.new()
	error_banner.name = "ErrorBanner"
	error_banner.visible = false
	error_banner.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	main_vbox.add_child(error_banner)

	# Header Row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header_hbox)

	hero_portrait = TextureRect.new()
	hero_portrait.name = "HeroPortrait"
	hero_portrait.custom_minimum_size = Vector2(56, 56)
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header_hbox.add_child(hero_portrait)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Loading Character..."
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	title_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "ID: -- | Race: -- | Class: -- | Alignment: --"
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86))
	title_vbox.add_child(subtitle_label)

	# Action Toolbar Buttons
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	header_hbox.add_child(btn_box)

	var arena_btn := Button.new()
	arena_btn.name = "PlayArenaButton"
	arena_btn.text = "Play 2D Arena [Tab]"
	arena_btn.pressed.connect(toggle_arena_mode)
	btn_box.add_child(arena_btn)

	var level_btn := Button.new()
	level_btn.name = "LevelUpButton"
	level_btn.text = "Level Up [L]"
	level_btn.pressed.connect(_on_level_up_pressed)
	btn_box.add_child(level_btn)

	var dmg_btn := Button.new()
	dmg_btn.name = "DamageButton"
	dmg_btn.text = "Hit -9 HP [D]"
	dmg_btn.pressed.connect(_on_damage_pressed)
	btn_box.add_child(dmg_btn)

	var heal_btn := Button.new()
	heal_btn.name = "HealButton"
	heal_btn.text = "Heal +12 HP [H]"
	heal_btn.pressed.connect(_on_heal_pressed)
	btn_box.add_child(heal_btn)

	var potion_btn := Button.new()
	potion_btn.name = "UsePotionButton"
	potion_btn.text = "Potion [C]"
	potion_btn.pressed.connect(_on_use_potion_pressed)
	btn_box.add_child(potion_btn)

	var save_btn := Button.new()
	save_btn.name = "SavePartyButton"
	save_btn.text = "Save [F5]"
	save_btn.pressed.connect(_on_save_party_pressed)
	btn_box.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.name = "LoadPartyButton"
	load_btn.text = "Load [F9]"
	load_btn.pressed.connect(_on_load_party_pressed)
	btn_box.add_child(load_btn)

	var reset_btn := Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_on_reset_pressed)
	btn_box.add_child(reset_btn)

	# Vitals Bars Row (Health & Mana)
	var vitals_hbox := HBoxContainer.new()
	vitals_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(vitals_hbox)

	var hp_vbox := VBoxContainer.new()
	hp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals_hbox.add_child(hp_vbox)

	hp_value_label = Label.new()
	hp_value_label.name = "HPValueLabel"
	hp_value_label.text = "Health: 0 / 0"
	hp_value_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.55))
	hp_vbox.add_child(hp_value_label)

	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(0, 20)
	hp_bar.show_percentage = false
	hp_vbox.add_child(hp_bar)

	var mana_vbox := VBoxContainer.new()
	mana_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals_hbox.add_child(mana_vbox)

	mana_value_label = Label.new()
	mana_value_label.name = "ManaValueLabel"
	mana_value_label.text = "Mana: 0 / 0"
	mana_value_label.add_theme_color_override("font_color", Color(0.48, 0.75, 0.98))
	mana_vbox.add_child(mana_value_label)

	mana_bar = ProgressBar.new()
	mana_bar.name = "ManaBar"
	mana_bar.custom_minimum_size = Vector2(0, 20)
	mana_bar.show_percentage = false
	mana_vbox.add_child(mana_bar)

	# Middle 3-Column Section: Attributes | Skills (Interactive Rolls) | Inventory & Backstory
	var columns_hbox := HBoxContainer.new()
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(columns_hbox)

	# Column 1: Core Attributes
	var attr_panel := _create_section_panel("Core Attributes", columns_hbox)
	attributes_grid = GridContainer.new()
	attributes_grid.name = "AttributesGrid"
	attributes_grid.columns = 2
	attributes_grid.add_theme_constant_override("h_separation", 16)
	attributes_grid.add_theme_constant_override("v_separation", 10)
	attr_panel.add_child(attributes_grid)

	# Column 2: Skills & Interactive d20 Checks
	var skills_panel := _create_section_panel("Skills (Click to Roll d20 Check [R])", columns_hbox)
	skills_box = VBoxContainer.new()
	skills_box.name = "SkillsBox"
	skills_box.add_theme_constant_override("separation", 8)
	skills_panel.add_child(skills_box)

	# Column 3: Inventory & Backstory
	var right_panel := _create_section_panel("Inventory & Backstory", columns_hbox)
	inventory_box = VBoxContainer.new()
	inventory_box.name = "InventoryBox"
	inventory_box.add_theme_constant_override("separation", 6)
	right_panel.add_child(inventory_box)

	var divider := HSeparator.new()
	right_panel.add_child(divider)

	backstory_label = RichTextLabel.new()
	backstory_label.name = "BackstoryLabel"
	backstory_label.fit_content = true
	backstory_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(backstory_label)

	# Bottom Activity & Dice Roll Log
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 120)
	main_vbox.add_child(log_panel)

	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 12)
	log_margin.add_theme_constant_override("margin_top", 8)
	log_margin.add_theme_constant_override("margin_right", 12)
	log_margin.add_theme_constant_override("margin_bottom", 8)
	log_panel.add_child(log_margin)

	combat_log_label = RichTextLabel.new()
	combat_log_label.name = "CombatLogLabel"
	combat_log_label.scroll_following = true
	log_margin.add_child(combat_log_label)


func _create_section_panel(heading: String, parent_container: Container) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent_container.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = heading
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55))
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)
	return vbox


## Populates all HUD labels, bars, attribute badges, skill buttons, and inventory items.
func refresh_ui(data: Dictionary) -> void:
	if data.is_empty():
		return
	error_banner.visible = false

	var char_name: String = str(data.get("name", "Unknown"))
	var char_level: int = int(data.get("level", 1))
	var char_race: String = str(data.get("race", "Unknown"))
	var char_class: String = str(data.get("character_class", "Adventurer"))
	var char_id: String = str(data.get("character_id", "N/A"))
	var backstory: Dictionary = data.get("backstory", {})
	var alignment: String = str(backstory.get("alignment", "Unaligned"))
	var best_wave: int = int(loader.high_wave_reached) if loader != null else 1
	var best_score: int = int(loader.high_wave_score) if loader != null else 0

	title_label.text = "%s — Level %d %s %s" % [char_name, char_level, char_race, char_class]
	subtitle_label.text = "ID: %s | Alignment: %s | Best Arena Wave: %d (High Score: %d)" % [
		char_id,
		alignment,
		best_wave,
		best_score
	]

	if hero_portrait != null:
		if _portrait_gen == null:
			if arena != null and arena.get("sprite_gen") != null:
				_portrait_gen = arena.get("sprite_gen")
			else:
				_portrait_gen = SpriteArtGeneratorScript.new()
		if _portrait_gen != null and _portrait_gen.has_method("get_hero_texture"):
			hero_portrait.texture = _portrait_gen.get_hero_texture(char_id, 0)

	# Health & Mana
	var health: Dictionary = data.get("health", {"current": 0, "max": 1})
	var hp_curr: int = int(health.get("current", 0))
	var hp_max: int = maxi(1, int(health.get("max", 1)))
	hp_bar.max_value = hp_max
	hp_bar.value = hp_curr
	hp_value_label.text = "Health (HP): %d / %d" % [hp_curr, hp_max]

	var mana: Dictionary = data.get("mana", {"current": 0, "max": 1})
	var mana_curr: int = int(mana.get("current", 0))
	var mana_max: int = maxi(1, int(mana.get("max", 1)))
	mana_bar.max_value = mana_max
	mana_bar.value = mana_curr
	mana_value_label.text = "Mana (MP): %d / %d" % [mana_curr, mana_max]

	# Attributes
	for child in attributes_grid.get_children():
		child.queue_free()

	var attrs: Dictionary = data.get("attributes", {})
	var ordered_attrs: Array[String] = [
		"strength",
		"dexterity",
		"constitution",
		"intelligence",
		"wisdom",
		"charisma"
	]
	for attr_key in ordered_attrs:
		var score: int = int(attrs.get(attr_key, 10))
		var mod_val: int = loader.get_attribute_modifier(score) if loader else 0
		var mod_str: String = loader.format_modifier(mod_val) if loader else "+0"

		var name_lbl := Label.new()
		name_lbl.text = attr_key.capitalize()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attributes_grid.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "%d (%s)" % [score, mod_str]
		val_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.75))
		attributes_grid.add_child(val_lbl)

	# Skills
	for child in skills_box.get_children():
		child.queue_free()

	var skills: Array = data.get("skills", [])
	for idx in range(skills.size()):
		var sk: Dictionary = skills[idx]
		var sk_name: String = str(sk.get("name", "Skill"))
		var sk_rank: int = int(sk.get("rank", 0))
		var sk_mod_attr: String = str(sk.get("modifier", "dexterity"))

		var btn := Button.new()
		btn.text = "Roll %s (Rank %d | %s)" % [sk_name, sk_rank, sk_mod_attr.capitalize()]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_roll_skill_pressed.bind(idx))
		skills_box.add_child(btn)

	# Inventory
	for child in inventory_box.get_children():
		child.queue_free()

	if loader != null and loader.has_method("get_inventory_bonuses"):
		var bonuses: Dictionary = loader.get_inventory_bonuses()
		if int(bonuses.get("relic_count", 0)) > 0:
			var bonus_lbl := Label.new()
			bonus_lbl.text = "★ Active Relic Bonuses: +%d Dmg | +%d HP | +%d Spd" % [
				int(bonuses.get("damage", 0)),
				int(bonuses.get("max_hp", 0)),
				int(bonuses.get("speed", 0.0))
			]
			bonus_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
			inventory_box.add_child(bonus_lbl)

	var inventory: Array = data.get("inventory", [])
	for item in inventory:
		var item_lbl := Label.new()
		var item_id_str := str(item.get("item_id", "id"))
		item_lbl.text = "• %s (x%d) [%s]" % [
			str(item.get("name", "Item")),
			int(item.get("quantity", 1)),
			item_id_str
		]
		if item_id_str.begins_with("relic_") or int(item.get("bonus_damage", 0)) > 0:
			item_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
		elif item_id_str.begins_with("consum_"):
			item_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.65))
		inventory_box.add_child(item_lbl)

	backstory_label.text = "Backstory:\n%s" % str(backstory.get("summary", "No backstory recorded."))


func _append_log(message: String) -> void:
	_log_lines.append(message)
	while _log_lines.size() > MAX_LOG_ENTRIES:
		_log_lines.pop_front()
	if combat_log_label != null:
		combat_log_label.text = "\n".join(_log_lines)


func _on_character_loaded(data: Dictionary) -> void:
	refresh_ui(data)


func _on_character_updated(data: Dictionary, event_message: String) -> void:
	refresh_ui(data)
	_append_log(event_message)


func _on_character_load_error(error_message: String) -> void:
	error_banner.text = "ERROR: " + error_message
	error_banner.visible = true
	_append_log("ERROR: " + error_message)


func _on_roster_slot_pressed(roster_index: int) -> void:
	if loader != null and loader.has_method("select_roster_character"):
		loader.select_roster_character(roster_index)


func _on_save_party_pressed() -> void:
	if loader != null and loader.has_method("save_party_progression"):
		loader.save_party_progression()


func _on_load_party_pressed() -> void:
	if loader != null and loader.has_method("load_party_progression"):
		loader.load_party_progression()


func _on_level_up_pressed() -> void:
	if loader != null:
		loader.apply_level_up()


func _on_roll_skill_pressed(skill_index: int) -> void:
	if loader != null:
		loader.roll_skill_check(skill_index)


func _on_damage_pressed() -> void:
	if loader != null:
		loader.modify_health(DAMAGE_STEP)


func _on_heal_pressed() -> void:
	if loader != null:
		loader.modify_health(HEAL_STEP)


func _on_use_potion_pressed() -> void:
	if loader != null and loader.has_method("use_consumable_potion"):
		loader.use_consumable_potion()


func _on_reset_pressed() -> void:
	if loader != null and loader.has_method("reset_all_progression"):
		loader.reset_all_progression()
		_append_log("[Reset] Reloaded clean baseline hero sheets from res://data/.")
