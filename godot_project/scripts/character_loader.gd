# godot_project/scripts/character_loader.gd
# Loads, validates, caches, and saves/loads runtime character sheet & 4-hero roster state.
# Connects to: godot_project/data/CharacterData.json, user://roster_save.json, godot_project/scripts/character_sheet_hud.gd
# Created: 2026-10-24

extends Node
class_name CharacterLoader

## Emitted when character data is loaded or switched from disk/cache.
signal character_loaded(data: Dictionary)

## Emitted when character stats (level, HP, mana, attributes, save/load) change at runtime.
signal character_updated(data: Dictionary, event_message: String)

## Emitted when a file read or schema boundary validation error occurs.
signal character_load_error(error_message: String)

const DEFAULT_DATA_PATH: String = "res://data/CharacterData.json"
const DEFAULT_SAVE_PATH: String = "user://roster_save.json"
const ROSTER_ENTRIES: Array[Dictionary] = [
	{
		"slot": 1,
		"label": "[1] Kaelen (Ranger)",
		"path": "res://data/CharacterData.json",
		"accent": Color(0.28, 0.78, 0.48)
	},
	{
		"slot": 2,
		"label": "[2] Ash-Knight (Paladin)",
		"path": "res://data/characters/ash_knight.json",
		"accent": Color(0.92, 0.45, 0.22)
	},
	{
		"slot": 3,
		"label": "[3] Echo-Wraith (Assassin)",
		"path": "res://data/characters/echo_wraith.json",
		"accent": Color(0.65, 0.42, 0.95)
	},
	{
		"slot": 4,
		"label": "[4] Rotting Sentinel (Warden)",
		"path": "res://data/characters/rotting_sentinel.json",
		"accent": Color(0.55, 0.78, 0.32)
	}
]

const BASE_ATTRIBUTE_SCORE: int = 10
const ATTRIBUTE_MODIFIER_DIVISOR: int = 2
const D20_SIDES: int = 20
const LEVEL_UP_HP_GAIN: int = 8
const LEVEL_UP_MANA_GAIN: int = 4
const POTION_HP_RESTORE: int = 25
const POTION_MP_RESTORE: int = 12
const DEFAULT_POTION_ITEM: Dictionary = {
	"item_id": "consum_elixir_01",
	"name": "Ashen Healing Elixir (+25 HP, +12 MP)",
	"quantity": 2
}
const RELIC_CATALOG: Array[Dictionary] = [
	{
		"item_id": "relic_ember_heart",
		"name": "Embercrest Relic (+4 Dmg, +10 HP)",
		"bonus_damage": 4,
		"bonus_max_hp": 10,
		"bonus_speed": 0.0
	},
	{
		"item_id": "relic_wind_feather",
		"name": "Gale-Stalker Plume (+2 Dmg, +25 Spd)",
		"bonus_damage": 2,
		"bonus_max_hp": 0,
		"bonus_speed": 25.0
	},
	{
		"item_id": "relic_titan_core",
		"name": "Titan Core Relic (+6 Dmg, +20 HP)",
		"bonus_damage": 6,
		"bonus_max_hp": 20,
		"bonus_speed": 10.0
	}
]
const REQUIRED_KEYS: Array[String] = [
	"character_id",
	"name",
	"race",
	"character_class",
	"level",
	"health",
	"mana",
	"attributes",
	"skills",
	"inventory",
	"backstory"
]

var current_data: Dictionary = {}
var current_roster_index: int = 0
var high_wave_reached: int = 1
var high_wave_score: int = 0

var _roster_state_cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var loaded := load_character_data(DEFAULT_DATA_PATH)
	if not loaded.is_empty():
		print("Successfully loaded character: ", loaded.get("name", "Unknown"))
		print(
			"Class: %s, Level: %d"
			% [loaded.get("character_class", "Unknown"), int(loaded.get("level", 1))]
		)
		var attrs: Dictionary = loaded.get("attributes", {})
		print("Strength: ", attrs.get("strength", 0))
		var skills: Array = loaded.get("skills", [])
		if not skills.is_empty():
			print("First Skill: ", skills[0].get("name", "None"))


## Switches the active character to the specified roster index (0..3), preserving in-memory progression.
func select_roster_character(roster_index: int, force_disk_reload: bool = false) -> Dictionary:
	if roster_index < 0 or roster_index >= ROSTER_ENTRIES.size():
		return {}

	if not current_data.is_empty() and not force_disk_reload:
		_cache_current_hero_state()

	current_roster_index = roster_index
	var entry: Dictionary = ROSTER_ENTRIES[roster_index]
	var path_str: String = str(entry.get("path", DEFAULT_DATA_PATH))

	var loaded: Dictionary = {}
	if not force_disk_reload and _roster_state_cache.has(path_str):
		current_data = (_roster_state_cache[path_str] as Dictionary).duplicate(true)
		character_loaded.emit(current_data)
		loaded = current_data
	else:
		loaded = load_character_data(path_str)

	if not loaded.is_empty():
		var msg := "[Roster Switch] Activated Slot [%d]: %s (Lv.%d %s)" % [
			int(entry.get("slot", roster_index + 1)),
			str(loaded.get("name", "Hero")),
			int(loaded.get("level", 1)),
			str(loaded.get("character_class", "Class"))
		]
		character_updated.emit(current_data, msg)
	return loaded


func _cache_current_hero_state() -> void:
	if current_data.is_empty():
		return
	if current_roster_index >= 0 and current_roster_index < ROSTER_ENTRIES.size():
		var path_str: String = str(ROSTER_ENTRIES[current_roster_index].get("path", DEFAULT_DATA_PATH))
		_roster_state_cache[path_str] = current_data.duplicate(true)


## Updates highest Wave Survival wave number and score if exceeded.
func record_wave_progress(wave_num: int, score_val: int) -> void:
	if wave_num > high_wave_reached:
		high_wave_reached = wave_num
	if score_val > high_wave_score:
		high_wave_score = score_val


## Saves all 4 heroes' runtime progression and high scores to user://roster_save.json.
func save_party_progression(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	_cache_current_hero_state()
	var save_payload := {
		"version": "1.0",
		"saved_at": Time.get_datetime_string_from_system(true),
		"active_roster_index": current_roster_index,
		"high_wave_reached": high_wave_reached,
		"high_wave_score": high_wave_score,
		"roster_cache": _roster_state_cache.duplicate(true)
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var err_msg := "Failed to write save file at %s (Error %d)" % [save_path, FileAccess.get_open_error()]
		printerr(err_msg)
		character_load_error.emit(err_msg)
		return {"error": err_msg}

	file.store_string(JSON.stringify(save_payload, "\t"))
	file.close()

	var msg := "[Party Saved] Saved %d hero state(s) & High Score (%d) to %s." % [
		_roster_state_cache.size(),
		high_wave_score,
		save_path
	]
	character_updated.emit(current_data, msg)
	return {
		"status": "saved",
		"save_path": save_path,
		"saved_heroes_count": _roster_state_cache.size(),
		"high_wave_reached": high_wave_reached,
		"high_wave_score": high_wave_score,
		"message": msg
	}


## Loads party progression and high scores from user://roster_save.json.
func load_party_progression(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		var err_msg := "Save file not found at '%s'. Press [F5] to save party progression first." % save_path
		printerr(err_msg)
		character_load_error.emit(err_msg)
		return {"error": err_msg}

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		var err_msg := "Failed to open save file at %s" % save_path
		printerr(err_msg)
		character_load_error.emit(err_msg)
		return {"error": err_msg}

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw_text) != OK or not (json.data is Dictionary):
		var err_msg := "Corrupted save JSON in %s" % save_path
		printerr(err_msg)
		character_load_error.emit(err_msg)
		return {"error": err_msg}

	var payload: Dictionary = json.data
	if not payload.has("roster_cache") or not (payload.get("roster_cache") is Dictionary):
		var err_msg := "Save file %s is missing 'roster_cache' dictionary." % save_path
		printerr(err_msg)
		character_load_error.emit(err_msg)
		return {"error": err_msg}

	var loaded_cache: Dictionary = payload["roster_cache"]
	for path_key in loaded_cache.keys():
		var hero_dict = loaded_cache[path_key]
		if not (hero_dict is Dictionary) or not validate_schema(hero_dict).is_empty():
			var err_msg := "Invalid hero schema inside save cache for key '%s'." % str(path_key)
			printerr(err_msg)
			character_load_error.emit(err_msg)
			return {"error": err_msg}

	_roster_state_cache = loaded_cache.duplicate(true)
	high_wave_reached = maxi(1, int(payload.get("high_wave_reached", 1)))
	high_wave_score = maxi(0, int(payload.get("high_wave_score", 0)))
	var target_idx: int = clampi(int(payload.get("active_roster_index", 0)), 0, ROSTER_ENTRIES.size() - 1)

	current_roster_index = target_idx
	var active_path: String = str(ROSTER_ENTRIES[target_idx].get("path", DEFAULT_DATA_PATH))
	if _roster_state_cache.has(active_path):
		current_data = (_roster_state_cache[active_path] as Dictionary).duplicate(true)
	else:
		load_character_data(active_path)

	character_loaded.emit(current_data)
	var msg := "[Party Loaded] Restored %d hero state(s) & Best Wave %d (Score: %d) from %s." % [
		_roster_state_cache.size(),
		high_wave_reached,
		high_wave_score,
		save_path
	]
	character_updated.emit(current_data, msg)
	return {
		"status": "loaded",
		"save_path": save_path,
		"active_roster_index": current_roster_index,
		"high_wave_reached": high_wave_reached,
		"high_wave_score": high_wave_score,
		"message": msg
	}


## Clears all cached runtime mutations and reloads clean baseline JSON from res://data/.
func reset_all_progression() -> Dictionary:
	_roster_state_cache.clear()
	high_wave_reached = 1
	high_wave_score = 0
	return select_roster_character(current_roster_index, true)


## Returns the color accent for the currently active roster hero.
func get_current_hero_accent() -> Color:
	if current_roster_index >= 0 and current_roster_index < ROSTER_ENTRIES.size():
		return ROSTER_ENTRIES[current_roster_index].get("accent", Color(0.28, 0.78, 0.48))
	return Color(0.28, 0.78, 0.48)


## Reads, parses, and boundary-validates a character sheet JSON file.
func load_character_data(file_path: String = DEFAULT_DATA_PATH) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		var msg := "Character file not found at '%s'. Verify res://data/CharacterData.json exists." % file_path
		printerr(msg)
		character_load_error.emit(msg)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var msg := "Failed to open file at path: %s (Error %d)" % [file_path, FileAccess.get_open_error()]
		printerr(msg)
		character_load_error.emit(msg)
		return {}

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		var msg := "Error parsing JSON in %s: %s at line %d" % [
			file_path,
			json.get_error_message(),
			json.get_error_line()
		]
		printerr(msg)
		character_load_error.emit(msg)
		return {}

	if not (json.data is Dictionary):
		var msg := "Invalid root JSON type in %s: expected Dictionary object." % file_path
		printerr(msg)
		character_load_error.emit(msg)
		return {}

	var parsed: Dictionary = json.data
	var validation_errors := validate_schema(parsed)
	if not validation_errors.is_empty():
		var msg := "Schema validation failed (%d issues): %s" % [
			validation_errors.size(),
			"; ".join(validation_errors)
		]
		printerr(msg)
		character_load_error.emit(msg)
		return {}

	current_data = parsed.duplicate(true)
	_ensure_starter_consumables(current_data)
	_roster_state_cache[file_path] = current_data.duplicate(true)
	character_loaded.emit(current_data)
	return current_data


func _ensure_starter_consumables(data: Dictionary) -> void:
	var inventory: Array = data.get("inventory", [])
	for item in inventory:
		if item is Dictionary and is_consumable_item(item):
			return
	inventory.append(DEFAULT_POTION_ITEM.duplicate(true))
	data["inventory"] = inventory


## Returns true if the given inventory item dictionary is a usable consumable potion/elixir.
func is_consumable_item(item: Dictionary) -> bool:
	var iid := str(item.get("item_id", "")).to_lower()
	return iid.begins_with("consum_") or bool(item.get("consumable", false))


## Returns total remaining quantity of consumable potions across the active hero's inventory.
func get_consumable_count() -> int:
	if current_data.is_empty():
		return 0
	var total: int = 0
	var inventory: Array = current_data.get("inventory", [])
	for item in inventory:
		if item is Dictionary and is_consumable_item(item):
			total += maxi(0, int(item.get("quantity", 0)))
	return total


## Restocks +amount consumable potions into the active hero's inventory (e.g., on Boss defeat).
func grant_consumable_potion(amount: int = 1) -> Dictionary:
	if current_data.is_empty() or amount <= 0:
		return {"error": "Invalid potion grant"}

	var inventory: Array = current_data.get("inventory", [])
	var found := false
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if is_consumable_item(item):
			item["quantity"] = int(item.get("quantity", 0)) + amount
			inventory[i] = item
			found = true
			break

	if not found:
		var new_pot := DEFAULT_POTION_ITEM.duplicate(true)
		new_pot["quantity"] = amount
		inventory.append(new_pot)

	current_data["inventory"] = inventory
	_cache_current_hero_state()
	var total_left := get_consumable_count()
	var msg := "[Potion Restocked!] +%d Ashen Healing Elixir (%d total in inventory)." % [amount, total_left]
	character_updated.emit(current_data, msg)
	return {
		"status": "restocked",
		"added": amount,
		"remaining_potions": total_left,
		"message": msg
	}


## Uses 1 consumable potion ([C] key), restoring +25 HP & +12 MP and removing the item when quantity reaches 0.
func use_consumable_potion() -> Dictionary:
	if current_data.is_empty():
		return {"error": "No active character loaded"}

	var inventory: Array = current_data.get("inventory", [])
	var target_idx: int = -1
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if is_consumable_item(item) and int(item.get("quantity", 0)) > 0:
			target_idx = i
			break

	if target_idx < 0:
		var empty_msg := "[Potions Empty!] No consumable potions remaining — defeat a Boss Wave to restock!"
		character_updated.emit(current_data, empty_msg)
		return {
			"error": "No consumable potions remaining",
			"remaining_potions": 0,
			"message": empty_msg
		}

	var used_item: Dictionary = inventory[target_idx]
	var item_name: String = str(used_item.get("name", "Healing Potion"))
	var new_qty: int = int(used_item.get("quantity", 1)) - 1
	if new_qty <= 0:
		inventory.remove_at(target_idx)
	else:
		used_item["quantity"] = new_qty
		inventory[target_idx] = used_item
	current_data["inventory"] = inventory

	var health: Dictionary = current_data.get("health", {"current": 45, "max": 45})
	var max_hp: int = int(health.get("max", 45))
	var old_hp: int = int(health.get("current", max_hp))
	var new_hp: int = clampi(old_hp + POTION_HP_RESTORE, 0, max_hp)
	health["current"] = new_hp
	current_data["health"] = health

	var mana: Dictionary = current_data.get("mana", {"current": 20, "max": 20})
	var max_mp: int = int(mana.get("max", 20))
	var old_mp: int = int(mana.get("current", max_mp))
	var new_mp: int = clampi(old_mp + POTION_MP_RESTORE, 0, max_mp)
	mana["current"] = new_mp
	current_data["mana"] = mana

	_cache_current_hero_state()
	var remaining := get_consumable_count()
	var msg := "[Potion Used: %s] Restored +%d HP (%d/%d) & +%d MP (%d/%d) — %d potion(s) left!" % [
		item_name,
		POTION_HP_RESTORE,
		new_hp,
		max_hp,
		POTION_MP_RESTORE,
		new_mp,
		max_mp,
		remaining
	]
	character_updated.emit(current_data, msg)
	return {
		"status": "consumed",
		"item_name": item_name,
		"hp_current": new_hp,
		"mp_current": new_mp,
		"remaining_potions": remaining,
		"message": msg
	}


## Collect-all boundary validator checking required top-level fields.
func validate_schema(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key in REQUIRED_KEYS:
		if not data.has(key):
			errors.append("Missing required field '%s'" % key)
	return errors


## Calculates standard RPG attribute modifier: floor((score - 10) / 2).
func get_attribute_modifier(score: int) -> int:
	return int(floor(float(score - BASE_ATTRIBUTE_SCORE) / float(ATTRIBUTE_MODIFIER_DIVISOR)))


## Returns damage reduction derived from the hero's Constitution modifier (minimum 0).
func get_armor_reduction() -> int:
	if current_data.is_empty():
		return 0
	var attrs: Dictionary = current_data.get("attributes", {})
	var con_score: int = int(attrs.get("constitution", BASE_ATTRIBUTE_SCORE))
	return maxi(0, get_attribute_modifier(con_score))


## Calculates cumulative passive stat bonuses from equipped Relic items in the active hero's inventory.
func get_inventory_bonuses() -> Dictionary:
	if current_data.is_empty():
		return {"damage": 0, "max_hp": 0, "speed": 0.0, "relic_count": 0}

	var total_dmg: int = 0
	var total_hp: int = 0
	var total_spd: float = 0.0
	var relic_count: int = 0
	var inventory: Array = current_data.get("inventory", [])
	for item in inventory:
		if not (item is Dictionary):
			continue
		var qty: int = maxi(1, int(item.get("quantity", 1)))
		var b_dmg: int = int(item.get("bonus_damage", 0))
		var b_hp: int = int(item.get("bonus_max_hp", 0))
		var b_spd: float = float(item.get("bonus_speed", 0.0))
		if b_dmg > 0 or b_hp > 0 or b_spd > 0.0:
			total_dmg += b_dmg * qty
			total_hp += b_hp * qty
			total_spd += b_spd * float(qty)
			relic_count += qty

	return {
		"damage": total_dmg,
		"max_hp": total_hp,
		"speed": total_spd,
		"relic_count": relic_count
	}


## Grants a Relic item into the active hero's inventory, deduplicating by item_id and applying Max HP bonuses.
func grant_relic_item(relic_index: int = -1) -> Dictionary:
	if current_data.is_empty():
		return {"error": "No active character loaded"}

	var chosen_idx: int = relic_index
	if chosen_idx < 0 or chosen_idx >= RELIC_CATALOG.size():
		chosen_idx = _rng.randi_range(0, RELIC_CATALOG.size() - 1)
	var relic: Dictionary = (RELIC_CATALOG[chosen_idx] as Dictionary).duplicate(true)
	var target_id: String = str(relic.get("item_id", "relic_ember_heart"))

	var inventory: Array = current_data.get("inventory", [])
	var found := false
	for i in range(inventory.size()):
		var existing: Dictionary = inventory[i]
		if str(existing.get("item_id", "")) == target_id:
			existing["quantity"] = int(existing.get("quantity", 1)) + 1
			existing["bonus_damage"] = int(relic.get("bonus_damage", 0))
			existing["bonus_max_hp"] = int(relic.get("bonus_max_hp", 0))
			existing["bonus_speed"] = float(relic.get("bonus_speed", 0.0))
			inventory[i] = existing
			found = true
			break

	if not found:
		inventory.append({
			"item_id": target_id,
			"name": str(relic.get("name", "Ancient Relic")),
			"quantity": 1,
			"bonus_damage": int(relic.get("bonus_damage", 0)),
			"bonus_max_hp": int(relic.get("bonus_max_hp", 0)),
			"bonus_speed": float(relic.get("bonus_speed", 0.0))
		})
	current_data["inventory"] = inventory

	var hp_bonus: int = int(relic.get("bonus_max_hp", 0))
	if hp_bonus > 0:
		var health: Dictionary = current_data.get("health", {"current": 45, "max": 45})
		health["max"] = int(health.get("max", 45)) + hp_bonus
		health["current"] = mini(int(health["max"]), int(health.get("current", 45)) + hp_bonus)
		current_data["health"] = health

	_cache_current_hero_state()
	var bonuses := get_inventory_bonuses()
	var msg := "[Relic Looted!] %s equipped %s (Total Relic Bonuses: +%d Dmg, +%d HP, +%d Spd)!" % [
		str(current_data.get("name", "Hero")),
		str(relic.get("name", "Relic")),
		int(bonuses.get("damage", 0)),
		int(bonuses.get("max_hp", 0)),
		int(bonuses.get("speed", 0.0))
	]
	character_updated.emit(current_data, msg)
	return {
		"status": "relic_looted",
		"relic": relic,
		"bonuses": bonuses,
		"message": msg
	}


## Formats an integer modifier with an explicit sign (e.g., "+4" or "-1").
func format_modifier(mod_value: int) -> String:
	return "+%d" % mod_value if mod_value >= 0 else "%d" % mod_value


## Performs a d20 skill check using skill rank + linked attribute modifier.
func roll_skill_check(skill_index: int = 0) -> Dictionary:
	var skills: Array = current_data.get("skills", [])
	if skills.is_empty() or skill_index < 0 or skill_index >= skills.size():
		return {"error": "Invalid skill index"}

	var skill: Dictionary = skills[skill_index]
	var skill_name: String = str(skill.get("name", "Unknown"))
	var rank: int = int(skill.get("rank", 0))
	var attr_name: String = str(skill.get("modifier", "dexterity"))
	var attrs: Dictionary = current_data.get("attributes", {})
	var attr_score: int = int(attrs.get(attr_name, BASE_ATTRIBUTE_SCORE))
	var attr_mod: int = get_attribute_modifier(attr_score)

	var d20_roll: int = _rng.randi_range(1, D20_SIDES)
	var total: int = d20_roll + rank + attr_mod

	var summary := "[Skill Check: %s] d20(%d) + Rank(%d) + %s(%s) = %d" % [
		skill_name,
		d20_roll,
		rank,
		attr_name.capitalize(),
		format_modifier(attr_mod),
		total
	]
	character_updated.emit(current_data, summary)
	return {
		"skill_name": skill_name,
		"d20": d20_roll,
		"rank": rank,
		"attr_name": attr_name,
		"attr_mod": attr_mod,
		"total": total,
		"summary": summary
	}


## Increments character level, boosts max HP/Mana, and adds +1 to primary skill attribute.
func apply_level_up() -> Dictionary:
	if current_data.is_empty():
		return {}

	var new_level: int = int(current_data.get("level", 1)) + 1
	current_data["level"] = new_level

	var health: Dictionary = current_data.get("health", {"current": 10, "max": 10})
	health["max"] = int(health.get("max", 10)) + LEVEL_UP_HP_GAIN
	health["current"] = health["max"]
	current_data["health"] = health

	var mana: Dictionary = current_data.get("mana", {"current": 10, "max": 10})
	mana["max"] = int(mana.get("max", 10)) + LEVEL_UP_MANA_GAIN
	mana["current"] = mana["max"]
	current_data["mana"] = mana

	var primary_attr := "dexterity"
	var skills: Array = current_data.get("skills", [])
	if not skills.is_empty():
		primary_attr = str(skills[0].get("modifier", "dexterity"))

	var attrs: Dictionary = current_data.get("attributes", {})
	attrs[primary_attr] = int(attrs.get(primary_attr, BASE_ATTRIBUTE_SCORE)) + 1
	current_data["attributes"] = attrs

	_cache_current_hero_state()
	var msg := "[Level Up!] %s reached Level %d (+%d Max HP, +%d Max Mana, +1 %s)" % [
		str(current_data.get("name", "Hero")),
		new_level,
		LEVEL_UP_HP_GAIN,
		LEVEL_UP_MANA_GAIN,
		primary_attr.capitalize()
	]
	character_updated.emit(current_data, msg)
	return current_data


## Adjusts current HP by delta (negative for damage, positive for healing) clamped to [0, max].
func modify_health(delta: int) -> Dictionary:
	if current_data.is_empty():
		return {}

	var health: Dictionary = current_data.get("health", {"current": 10, "max": 10})
	var max_hp: int = int(health.get("max", 10))
	var old_hp: int = int(health.get("current", max_hp))
	var new_hp: int = clampi(old_hp + delta, 0, max_hp)
	health["current"] = new_hp
	current_data["health"] = health

	_cache_current_hero_state()
	var action_label := "Healed +%d HP" % delta if delta >= 0 else "Took %d Damage" % abs(delta)
	var msg := "[Combat Health] %s (%d -> %d / %d HP)" % [action_label, old_hp, new_hp, max_hp]
	character_updated.emit(current_data, msg)
	return current_data


## Adjusts current Mana by delta (negative for spell/dash cost, positive for regen) clamped to [0, max].
func modify_mana(delta: int, silent: bool = false) -> Dictionary:
	if current_data.is_empty():
		return {}

	var mana: Dictionary = current_data.get("mana", {"current": 10, "max": 10})
	var max_mp: int = int(mana.get("max", 10))
	var old_mp: int = int(mana.get("current", max_mp))
	var new_mp: int = clampi(old_mp + delta, 0, max_mp)
	mana["current"] = new_mp
	current_data["mana"] = mana

	_cache_current_hero_state()
	if not silent:
		var action_label := "Restored +%d MP" % delta if delta >= 0 else "Spent %d MP" % abs(delta)
		var msg := "[Combat Mana] %s (%d -> %d / %d MP)" % [action_label, old_mp, new_mp, max_mp]
		character_updated.emit(current_data, msg)
	return current_data
