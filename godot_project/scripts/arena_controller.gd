# godot_project/scripts/arena_controller.gd
# Playable 2D Top-Down Combat Arena with Wave Survival AI, Mana Dash (Shift), and 4-Hero Roster.
# Connects to: godot_project/scripts/character_loader.gd, godot_project/scripts/character_sheet_hud.gd, godot_project/scenes/arena.tscn
# Created: 2026-10-24

extends Node2D
class_name ArenaController

## Emitted when the player clicks the button or presses Tab to return to the Character Sheet HUD.
signal request_hud_toggle

## Emitted whenever a projectile hits, dash triggers, or wave advances in the arena.
signal arena_combat_event(message: String)

const SpriteArtGeneratorScript = preload("res://scripts/sprite_art_generator.gd")
const BASE_MOVE_SPEED: float = 230.0
const SPEED_PER_DEX_MOD: float = 18.0
const ARROW_SPEED: float = 620.0
const BASE_ARROW_DAMAGE: int = 6
const PLAYER_RADIUS: float = 18.0
const DUMMY_RADIUS: float = 24.0
const PILLAR_RADIUS: float = 32.0
const ARROW_HIT_RADIUS: float = 28.0
const CONTACT_HIT_DISTANCE: float = 40.0
const ARENA_MIN_BOUNDS: Vector2 = Vector2(48.0, 96.0)
const ARENA_MAX_BOUNDS: Vector2 = Vector2(1100.0, 610.0)

const DASH_MANA_COST: int = 6
const DASH_BURST_DISTANCE: float = 145.0
const DASH_IFRAME_DURATION: float = 0.45
const BASE_DASH_COOLDOWN: float = 1.2
const DASH_CD_PER_RANK: float = 0.08
const ULTIMATE_MANA_COST: int = 15
const ULTIMATE_COOLDOWN: float = 2.0
const ULTIMATE_NOVA_RADIUS: float = 280.0
const CHEST_PICKUP_RADIUS: float = 42.0
const CONTACT_BASE_DAMAGE: int = 12
const CONTACT_IFRAME_DURATION: float = 0.65
const BASE_ENEMY_CHASE_SPEED: float = 95.0
const MANA_REGEN_INTERVAL: float = 1.0
const MANA_REGEN_AMOUNT: int = 3
const BASE_CRIT_CHANCE: float = 0.08
const CRIT_PER_MOD: float = 0.03
const CRIT_DAMAGE_MULTIPLIER: int = 2
const ENEMY_PROJECTILE_SPEED: float = 340.0
const ENEMY_PROJECTILE_BASE_DAMAGE: int = 10
const ENEMY_FIRE_INTERVAL: float = 2.4
const PARRY_WINDOW_DURATION: float = 0.35
const PARRY_COOLDOWN: float = 1.1
const PARRY_REFLECT_RADIUS: float = 48.0
const HAZARD_TICK_INTERVAL: float = 0.5
const HAZARD_BURN_DAMAGE: int = 8
const SANCTUARY_HEAL_HP: int = 2
const SANCTUARY_HEAL_MP: int = 3
const COMBO_DURATION: float = 3.5
const FRENZY_COMBO_THRESHOLD: int = 3
const FRENZY_SPEED_MULTIPLIER: float = 1.15
const FRENZY_CRIT_BONUS: float = 0.10
const AI_FIRE_INTERVAL: float = 0.38
const AI_POTION_HP_THRESHOLD: float = 0.45
const AI_DANGER_DASH_DISTANCE: float = 92.0
const DOOR_TRIGGER_RADIUS: float = 42.0
const DOOR_COOLDOWN_DURATION: float = 0.85
const BOSS_ENRAGE_HP_THRESHOLD: float = 0.50
const BOSS_ENRAGE_SPEED_MULTIPLIER: float = 1.30
const ELEMENTAL_STANCES: Array[String] = ["none", "frostbite", "cinderbrand", "stormchain"]
const FROST_DURATION: float = 3.5
const FROST_SLOW_MULTIPLIER: float = 0.65
const CINDER_DURATION: float = 3.0
const CINDER_BURN_DAMAGE_PER_STACK: int = 5
const STORMCHAIN_RANGE: float = 340.0
const STORMCHAIN_RATIO: float = 0.50
const ENEMY_GOLD_REWARD: int = 20
const BOSS_GOLD_REWARD: int = 60
const COIN_MAGNET_RADIUS: float = 160.0
const COIN_PICKUP_RADIUS: float = 28.0
const MERCHANT_POS: Vector2 = Vector2(210.0, 175.0)

var loader: Node = null
var sfx_node: Node = null
var arena_active: bool = false
var wave_survival_active: bool = false
var wave_number: int = 1
var wave_score: int = 0

var player_pos: Vector2 = Vector2(260.0, 350.0)
var aim_dir: Vector2 = Vector2.RIGHT
var last_move_dir: Vector2 = Vector2.RIGHT
var dash_iframe_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var ultimate_cooldown_timer: float = 0.0
var ult_vfx_timer: float = 0.0
var ult_vfx_radius: float = 180.0
var _mana_regen_accum: float = 0.0

var arrows: Array[Dictionary] = []
var dummies: Array[Dictionary] = []
var loot_chests: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var obstacle_blocks_count: int = 0
var floating_texts: Array[Dictionary] = []
var total_floating_texts_spawned: int = 0
var force_next_crit: bool = false
var total_critical_hits: int = 0
var enemy_projectiles: Array[Dictionary] = []
var enemy_fire_timer: float = 0.0
var enemy_projectiles_spawned_total: int = 0
var enemy_projectiles_blocked_by_cover: int = 0
var parry_window_timer: float = 0.0
var parry_cooldown_timer: float = 0.0
var total_projectiles_parried: int = 0
var hazard_zones: Array[Dictionary] = []
var _hazard_tick_accum: float = 0.0
var total_hazard_burn_ticks: int = 0
var total_sanctuary_ticks: int = 0
var combo_count: int = 0
var max_combo_reached: int = 0
var combo_timer: float = 0.0
var ai_pilot_active: bool = false
var ai_fire_timer: float = 0.0
var ai_decisions_count: int = 0
var ai_last_action: String = "idle"
var sprite_gen: RefCounted = null
var particles: Array[Dictionary] = []
var total_particles_spawned: int = 0
var screen_shake_trauma: float = 0.0
var _anim_time: float = 0.0
var dungeon_rooms: Dictionary = {}
var current_room_coord: Vector2i = Vector2i(0, 0)
var rooms_explored_count: int = 1
var total_door_transitions: int = 0
var door_cooldown_timer: float = 0.0
var total_boss_enrages: int = 0
var total_cinder_imps_summoned: int = 0
var elemental_stance: String = "none"
var lightning_arcs: Array[Dictionary] = []
var _elemental_burn_accum: float = 0.0
var total_chilled_hits: int = 0
var total_elemental_burn_ticks: int = 0
var total_stormchain_arcs: int = 0
var gold_coins: int = 0
var total_gold_earned: int = 0
var coin_drops: Array[Dictionary] = []
var shop_bonus_damage: int = 0
var shop_bonus_max_hp: int = 0
var shop_purchases_count: int = 0

var _ui_layer: CanvasLayer
var _status_label: Label
var _combat_banner: Label
var _wave_btn: Button
var _ai_btn: Button
var _stance_btn: Button
var _sfx_btn: Button


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_gen = SpriteArtGeneratorScript.new()
	_init_dungeon_floor()
	_init_obstacles()
	_init_hazard_zones()
	_init_dummies()
	_build_arena_overlay()
	_bind_loader()
	set_arena_active(false)


func _bind_loader() -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("load_character_data"):
		loader = parent
		if not loader.character_loaded.is_connected(_on_character_data_changed):
			loader.character_loaded.connect(_on_character_data_changed)
		if not loader.character_updated.is_connected(_on_character_updated):
			loader.character_updated.connect(_on_character_updated)
	if parent != null:
		sfx_node = parent.get_node_or_null("ProceduralSfx")
	_refresh_status_bar()


func _play_sfx(cue_name: String) -> void:
	if sfx_node == null and get_parent() != null:
		sfx_node = get_parent().get_node_or_null("ProceduralSfx")
	if sfx_node != null and sfx_node.has_method("play_cue"):
		sfx_node.play_cue(cue_name)


## Initializes the 5-Room Procedural Dungeon Floor graph centered at (0, 0).
func _init_dungeon_floor() -> void:
	current_room_coord = Vector2i(0, 0)
	rooms_explored_count = 1
	total_door_transitions = 0
	door_cooldown_timer = 0.0
	dungeon_rooms = {
		"0,0": {
			"coord": Vector2i(0, 0),
			"name": "Crypt Entry Hall",
			"type": "entry",
			"visited": true,
			"cleared": false,
			"doors": ["N", "E", "S", "W"],
			"tint": Color(1.0, 1.0, 1.0, 1.0)
		},
		"0,-1": {
			"coord": Vector2i(0, -1),
			"name": "Ashen Catacombs",
			"type": "skirmish",
			"visited": false,
			"cleared": false,
			"doors": ["S"],
			"tint": Color(0.86, 0.80, 1.08, 1.0)
		},
		"-1,0": {
			"coord": Vector2i(-1, 0),
			"name": "Consecrated Sanctuary",
			"type": "sanctuary",
			"visited": false,
			"cleared": true,
			"doors": ["E"],
			"tint": Color(0.75, 1.08, 0.94, 1.0)
		},
		"0,1": {
			"coord": Vector2i(0, 1),
			"name": "Gilded Relic Vault",
			"type": "treasure",
			"visited": false,
			"cleared": false,
			"doors": ["N"],
			"tint": Color(1.10, 0.96, 0.74, 1.0)
		},
		"1,0": {
			"coord": Vector2i(1, 0),
			"name": "Throne of the Ashen Titan",
			"type": "boss",
			"visited": false,
			"cleared": false,
			"doors": ["W"],
			"tint": Color(1.15, 0.76, 0.72, 1.0)
		}
	}


func get_room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func get_current_room() -> Dictionary:
	return dungeon_rooms.get(get_room_key(current_room_coord), {})


func are_room_doors_unlocked() -> bool:
	var room := get_current_room()
	if bool(room.get("cleared", false)):
		return true
	if not wave_survival_active:
		return true
	return _are_all_dummies_defeated()


func get_door_world_pos(direction: String) -> Vector2:
	match direction.to_upper():
		"N":
			return Vector2(574.0, ARENA_MIN_BOUNDS.y)
		"S":
			return Vector2(574.0, ARENA_MAX_BOUNDS.y)
		"E":
			return Vector2(ARENA_MAX_BOUNDS.x, 350.0)
		"W":
			return Vector2(ARENA_MIN_BOUNDS.x, 350.0)
		_:
			return Vector2(574.0, ARENA_MIN_BOUNDS.y)


func get_door_offset(direction: String) -> Vector2i:
	match direction.to_upper():
		"N":
			return Vector2i(0, -1)
		"S":
			return Vector2i(0, 1)
		"E":
			return Vector2i(1, 0)
		"W":
			return Vector2i(-1, 0)
		_:
			return Vector2i.ZERO


## Transitions the hero through a directional Stone Archway Door ("N", "E", "S", "W") into the connected dungeon room.
func enter_dungeon_door(direction: String, force_unlock: bool = false) -> Dictionary:
	var dir_up := direction.strip_edges().to_upper()
	var curr_room := get_current_room()
	var valid_doors: Array = curr_room.get("doors", [])
	if not valid_doors.has(dir_up):
		return {"error": "No door in direction '%s' from %s" % [dir_up, str(curr_room.get("name", "Room"))]}
	if not force_unlock and not are_room_doors_unlocked():
		return {"error": "Dungeon doors are locked until room enemies are cleared!"}

	var target_coord: Vector2i = current_room_coord + get_door_offset(dir_up)
	var target_key := get_room_key(target_coord)
	if not dungeon_rooms.has(target_key):
		return {"error": "Target room at %s does not exist" % target_key}

	current_room_coord = target_coord
	total_door_transitions += 1
	door_cooldown_timer = DOOR_COOLDOWN_DURATION
	var target_room: Dictionary = dungeon_rooms[target_key]
	var first_visit: bool = not bool(target_room.get("visited", false))
	target_room["visited"] = true
	if first_visit:
		rooms_explored_count += 1
	dungeon_rooms[target_key] = target_room

	# Position hero inside the opposite entrance archway
	match dir_up:
		"N":
			player_pos = Vector2(574.0, ARENA_MAX_BOUNDS.y - 68.0)
		"S":
			player_pos = Vector2(574.0, ARENA_MIN_BOUNDS.y + 68.0)
		"E":
			player_pos = Vector2(ARENA_MIN_BOUNDS.x + 72.0, 350.0)
		"W":
			player_pos = Vector2(ARENA_MAX_BOUNDS.x - 72.0, 350.0)

	arrows.clear()
	enemy_projectiles.clear()

	var r_type: String = str(target_room.get("type", "skirmish"))
	var r_name: String = str(target_room.get("name", "Dungeon Room"))
	var bonus_note: String = ""

	if r_type == "sanctuary":
		if first_visit and loader != null:
			loader.modify_health(20)
			loader.modify_mana(15, true)
			if loader.has_method("grant_consumable_potion"):
				loader.grant_consumable_potion(1)
			bonus_note = " (+20 HP, +15 MP & +1 Healing Elixir Restocked!)"
		for i in range(dummies.size()):
			dummies[i]["hp"] = 0
			dummies[i]["alive"] = false
	elif r_type == "treasure":
		_init_dummies(maxi(1, wave_number))
		if first_visit:
			spawn_relic_chest(Vector2(520.0, 300.0), 0)
			spawn_relic_chest(Vector2(620.0, 400.0), 1)
			bonus_note = " (2 Golden Relic Chests Discovered!)"
	elif r_type == "boss":
		_init_dummies(3)
		bonus_note = " (ASHEN TITAN [BOSS] AWAITS!)"
	else:
		_init_dummies(maxi(1, wave_number))

	spawn_particle_burst(player_pos, Color(0.35, 0.96, 0.88), 18, 1.35)
	trigger_screen_shake(0.24)
	spawn_floating_text(player_pos, r_name.to_upper(), Color(0.55, 0.96, 1.0), true)
	_play_sfx("dash")

	var msg := "[Dungeon Door -> %s] Entered %s [%s]%s (Rooms Explored: %d/%d)" % [
		dir_up,
		r_name,
		r_type.to_upper(),
		bonus_note,
		rooms_explored_count,
		dungeon_rooms.size()
	]
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "room_entered",
		"direction": dir_up,
		"room_coord": "%d,%d" % [current_room_coord.x, current_room_coord.y],
		"room_name": r_name,
		"room_type": r_type,
		"first_visit": first_visit,
		"rooms_explored_count": rooms_explored_count,
		"total_door_transitions": total_door_transitions,
		"message": msg
	}


## Cycles to the next connected or unexplored Dungeon Room ([N] Key / "Next Room [N]" Button).
func enter_next_unexplored_room() -> Dictionary:
	var curr_room := get_current_room()
	var doors: Array = curr_room.get("doors", [])
	# Prefer an unvisited connected door first
	for d in doors:
		var d_str := str(d)
		var next_coord := current_room_coord + get_door_offset(d_str)
		var next_room: Dictionary = dungeon_rooms.get(get_room_key(next_coord), {})
		if not bool(next_room.get("visited", false)):
			return enter_dungeon_door(d_str, true)
	# Otherwise take the first connected door back to the hub or next chamber
	if not doors.is_empty():
		var idx: int = total_door_transitions % doors.size()
		return enter_dungeon_door(str(doors[idx]), true)
	return {"error": "No connected doors available"}


## Checks if the hero walked into an unlocked Stone Archway Door during manual movement.
func check_door_transition() -> Dictionary:
	if door_cooldown_timer > 0.0 or not are_room_doors_unlocked():
		return {}
	var curr_room := get_current_room()
	var doors: Array = curr_room.get("doors", [])
	for d in doors:
		var d_str := str(d)
		var d_pos := get_door_world_pos(d_str)
		if player_pos.distance_to(d_pos) <= DOOR_TRIGGER_RADIUS:
			return enter_dungeon_door(d_str, false)
	return {}


## Initializes the 4 tactical Obsidian Pillars inside the 2D Arena.
func _init_obstacles() -> void:
	obstacles = [
		{
			"name": "Obsidian Pillar NW",
			"pos": Vector2(470.0, 220.0),
			"radius": PILLAR_RADIUS,
			"flash_timer": 0.0
		},
		{
			"name": "Obsidian Pillar SW",
			"pos": Vector2(470.0, 480.0),
			"radius": PILLAR_RADIUS,
			"flash_timer": 0.0
		},
		{
			"name": "Obsidian Pillar NE",
			"pos": Vector2(660.0, 260.0),
			"radius": PILLAR_RADIUS,
			"flash_timer": 0.0
		},
		{
			"name": "Obsidian Pillar SE",
			"pos": Vector2(660.0, 440.0),
			"radius": PILLAR_RADIUS,
			"flash_timer": 0.0
		}
	]


## Resolves circle-vs-circle collision between an entity (player or enemy) and all Obsidian Pillars.
func resolve_circle_obstacle_collision(entity_pos: Vector2, entity_radius: float) -> Dictionary:
	var resolved_pos := entity_pos
	var collided := false
	var hit_obstacle_name := ""
	for obs in obstacles:
		var obs_pos: Vector2 = obs.get("pos", Vector2.ZERO)
		var obs_rad: float = float(obs.get("radius", PILLAR_RADIUS))
		var min_dist: float = obs_rad + entity_radius
		var diff: Vector2 = resolved_pos - obs_pos
		var dist: float = diff.length()
		if dist < min_dist:
			var push_dir: Vector2 = diff / dist if dist > 0.001 else Vector2.UP
			resolved_pos = obs_pos + push_dir * min_dist
			collided = true
			hit_obstacle_name = str(obs.get("name", "Obsidian Pillar"))
	return {
		"pos": resolved_pos,
		"collided": collided,
		"obstacle_name": hit_obstacle_name
	}


## Returns true if the line-of-sight segment between from_pos and to_pos is clear of all Obsidian Pillars.
func has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	for obs in obstacles:
		var obs_pos: Vector2 = obs.get("pos", Vector2.ZERO)
		var obs_rad: float = float(obs.get("radius", PILLAR_RADIUS))
		var hit_t: float = Geometry2D.segment_intersects_circle(from_pos, to_pos, obs_pos, obs_rad)
		if hit_t >= 0.0:
			return false
	return true


## Counts how many alive enemies currently have their line-of-sight to the hero obstructed by an Obsidian Pillar.
func count_enemies_blocked_by_cover() -> int:
	var blocked_count: int = 0
	for d in dummies:
		if not bool(d.get("alive", true)):
			continue
		var d_pos: Vector2 = d.get("pos", Vector2.ZERO)
		if not has_line_of_sight(player_pos, d_pos):
			blocked_count += 1
	return blocked_count


## Returns the index of the Obsidian Pillar hit by a projectile at proj_pos, or -1 if none.
func check_projectile_obstacle_hit(proj_pos: Vector2) -> int:
	for i in range(obstacles.size()):
		var obs_pos: Vector2 = obstacles[i].get("pos", Vector2.ZERO)
		var obs_rad: float = float(obstacles[i].get("radius", PILLAR_RADIUS)) + 4.0
		if proj_pos.distance_to(obs_pos) <= obs_rad:
			return i
	return -1


## Initializes the 2 Molten Cinder Pits (enemy burn DoT) and 1 Consecrated Sanctuary Shrine (player regen).
func _init_hazard_zones() -> void:
	hazard_zones = [
		{
			"name": "Molten Cinder Pit N",
			"type": "cinder_pit",
			"pos": Vector2(565.0, 175.0),
			"radius": 46.0,
			"damage": HAZARD_BURN_DAMAGE
		},
		{
			"name": "Molten Cinder Pit S",
			"type": "cinder_pit",
			"pos": Vector2(565.0, 525.0),
			"radius": 46.0,
			"damage": HAZARD_BURN_DAMAGE
		},
		{
			"name": "Sanctuary Shrine",
			"type": "sanctuary",
			"pos": Vector2(330.0, 350.0),
			"radius": 44.0,
			"heal_hp": SANCTUARY_HEAL_HP,
			"heal_mp": SANCTUARY_HEAL_MP
		}
	]


## Steps environmental Hazard & Sanctuary Zones by delta, applying periodic burn ticks to enemies and regen to the hero.
func step_hazard_zones(delta: float) -> Dictionary:
	_hazard_tick_accum += delta
	var enemies_burned: int = 0
	var sanctuary_healed: int = 0
	if _hazard_tick_accum < HAZARD_TICK_INTERVAL:
		return {"enemies_burned": 0, "sanctuary_healed": 0}

	_hazard_tick_accum -= HAZARD_TICK_INTERVAL
	for zone in hazard_zones:
		var z_type: String = str(zone.get("type", ""))
		var z_pos: Vector2 = zone.get("pos", Vector2.ZERO)
		var z_rad: float = float(zone.get("radius", 45.0))
		if z_type == "cinder_pit":
			var burn_dmg: int = int(zone.get("damage", HAZARD_BURN_DAMAGE))
			for i in range(dummies.size()):
				if not bool(dummies[i].get("alive", true)):
					continue
				var d_pos: Vector2 = dummies[i].get("pos", Vector2.ZERO)
				var d_rad: float = float(dummies[i].get("radius", DUMMY_RADIUS))
				if d_pos.distance_to(z_pos) <= z_rad + d_rad * 0.5:
					enemies_burned += 1
					total_hazard_burn_ticks += 1
					apply_damage_to_dummy(i, burn_dmg, false)
					spawn_floating_text(d_pos + Vector2(0, -14), "BURN -%d" % burn_dmg, Color(1.0, 0.48, 0.15), false)
		elif z_type == "sanctuary":
			if player_pos.distance_to(z_pos) <= z_rad + PLAYER_RADIUS * 0.5:
				sanctuary_healed += 1
				total_sanctuary_ticks += 1
				if loader != null:
					loader.modify_health(SANCTUARY_HEAL_HP)
					loader.modify_mana(SANCTUARY_HEAL_MP, true)
				spawn_floating_text(player_pos + Vector2(0, -14), "+%d HP / +%d MP [SHRINE]" % [SANCTUARY_HEAL_HP, SANCTUARY_HEAL_MP], Color(0.35, 0.98, 0.78), false)

	return {
		"enemies_burned": enemies_burned,
		"sanctuary_healed": sanctuary_healed
	}


## Registers a combo hit, refreshing the 3.5s combo timer and activating Frenzy Mode at 3+ consecutive hits.
func register_combo_hit() -> Dictionary:
	combo_count += 1
	max_combo_reached = maxi(max_combo_reached, combo_count)
	combo_timer = COMBO_DURATION
	if combo_count == FRENZY_COMBO_THRESHOLD:
		spawn_floating_text(player_pos + Vector2(0, -24), "FRENZY x2!", Color(1.0, 0.85, 0.18), true)
	elif combo_count == 6:
		spawn_floating_text(player_pos + Vector2(0, -24), "MEGA FRENZY x3!", Color(1.0, 0.55, 0.15), true)
	_refresh_status_bar()
	queue_redraw()
	return {
		"combo_count": combo_count,
		"max_combo_reached": max_combo_reached,
		"frenzy_active": is_frenzy_active(),
		"multiplier": get_combo_multiplier()
	}


## Returns true when the hero has 3+ consecutive hits within the active Combo timer window.
func is_frenzy_active() -> bool:
	return combo_count >= FRENZY_COMBO_THRESHOLD and combo_timer > 0.0


## Returns the active Combo score multiplier (1x, 2x at 3+ hits, 3x at 6+ hits).
func get_combo_multiplier() -> int:
	if not is_frenzy_active():
		return 1
	return 3 if combo_count >= 6 else 2


## Returns the hero's effective movement speed including the +15% Frenzy haste bonus when active.
func get_frenzy_move_speed() -> float:
	var base_spd := get_calculated_move_speed()
	return base_spd * FRENZY_SPEED_MULTIPLIER if is_frenzy_active() else base_spd


## Toggles Autonomous Tactical Utility AI Auto-Pilot ([P] key / "toggle_ai_pilot" RPC).
func toggle_ai_pilot() -> bool:
	ai_pilot_active = not ai_pilot_active
	if _ai_btn != null:
		_ai_btn.text = "AI Pilot: ON [P]" if ai_pilot_active else "AI Pilot: OFF [P]"
	var popup_txt := "AI PILOT ENGAGED!" if ai_pilot_active else "MANUAL CONTROL"
	spawn_floating_text(player_pos + Vector2(0, -20), popup_txt, Color(0.45, 0.98, 1.0), true)
	var msg := "[Tactical AI Auto-Pilot: %s] Utility AI steering, parrying, kiting & ability rotation active!" % ("ON" if ai_pilot_active else "OFF")
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return ai_pilot_active


## Evaluates and executes 1 step of the 7-priority Tactical Utility AI Auto-Pilot.
func step_ai_pilot(delta: float) -> Dictionary:
	ai_fire_timer += delta
	var actions_taken: Array[String] = []

	var hp_cur: int = 45
	var hp_max: int = 45
	var mp_cur: int = 20
	var mp_max: int = 20
	if loader != null and not loader.current_data.is_empty():
		var h: Dictionary = loader.current_data.get("health", {})
		var m: Dictionary = loader.current_data.get("mana", {})
		hp_cur = int(h.get("current", 45))
		hp_max = maxi(1, int(h.get("max", 45)))
		mp_cur = int(m.get("current", 20))
		mp_max = maxi(1, int(m.get("max", 20)))
	var hp_ratio: float = float(hp_cur) / float(hp_max)

	# Priority 1: Emergency Consumable Potion ([C]) when HP < 45%
	if hp_ratio < AI_POTION_HP_THRESHOLD and loader != null and loader.has_method("get_consumable_count") and loader.get_consumable_count() > 0:
		var pot_res := trigger_use_potion()
		if pot_res.get("status") == "consumed":
			ai_last_action = "use_potion"
			ai_decisions_count += 1
			actions_taken.append("use_potion")

	# Priority 2: Reflex Arcane Parry ([F]) against incoming Enemy Projectiles within reflect radius
	if parry_cooldown_timer <= 0.0 and not enemy_projectiles.is_empty():
		for bolt in enemy_projectiles:
			var b_pos: Vector2 = bolt.get("pos", Vector2.ZERO)
			if b_pos.distance_to(player_pos) <= PARRY_REFLECT_RADIUS:
				trigger_arcane_parry()
				ai_last_action = "arcane_parry"
				ai_decisions_count += 1
				actions_taken.append("arcane_parry")
				break

	# Locate nearest alive enemy and prioritize Boss / Line-of-Sight target
	var nearest_idx: int = -1
	var nearest_dist: float = INF
	var nearest_pos: Vector2 = Vector2(760.0, 350.0)
	var best_target_idx: int = -1
	var best_target_score: float = -INF

	for i in range(dummies.size()):
		if not bool(dummies[i].get("alive", true)):
			continue
		var d_pos: Vector2 = dummies[i].get("pos", Vector2.ZERO)
		var dist: float = player_pos.distance_to(d_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_idx = i
			nearest_pos = d_pos
		var score: float = 1000.0 - dist
		if bool(dummies[i].get("is_boss", false)):
			score += 250.0
		if has_line_of_sight(player_pos, d_pos):
			score += 400.0
		if score > best_target_score:
			best_target_score = score
			best_target_idx = i

	# Priority 3: Emergency Mana Dash Evasion ([Shift]) when an enemy closes within AI_DANGER_DASH_DISTANCE
	if nearest_idx >= 0 and nearest_dist <= AI_DANGER_DASH_DISTANCE and dash_cooldown_timer <= 0.0 and mp_cur >= DASH_MANA_COST:
		var away_dir: Vector2 = (player_pos - nearest_pos).normalized()
		var to_shrine: Vector2 = (Vector2(330.0, 350.0) - player_pos).normalized()
		var escape_dir: Vector2 = (away_dir * 0.7 + to_shrine * 0.3).normalized()
		var dash_res := trigger_mana_dash(escape_dir)
		if dash_res.get("status") == "dashed":
			ai_last_action = "evade_dash"
			ai_decisions_count += 1
			actions_taken.append("evade_dash")

	# Priority 4: Auto-Loot Dropped Relic Chests ([E])
	if not loot_chests.is_empty():
		var loot_res := collect_nearest_relic_chest(true)
		if loot_res.get("status") == "relic_looted":
			ai_last_action = "loot_relic"
			ai_decisions_count += 1
			actions_taken.append("loot_relic")

	# Priority 5: Class Ultimate Ability ([Q]) when off cooldown and sufficient Mana
	if nearest_idx >= 0 and ultimate_cooldown_timer <= 0.0 and mp_cur >= ULTIMATE_MANA_COST and (nearest_dist <= ULTIMATE_NOVA_RADIUS or is_boss_wave()):
		aim_dir = (nearest_pos - player_pos).normalized()
		var ult_res := trigger_ultimate_ability()
		if ult_res.get("status") == "ultimate_cast":
			ai_last_action = "cast_ultimate"
			ai_decisions_count += 1
			actions_taken.append("cast_ultimate")

	# Priority 6: Composite Vector Steering (Kiting + Sanctuary Positioning + Pillar Orbit)
	var steer_vec := Vector2.ZERO
	if nearest_idx >= 0:
		if nearest_dist < 230.0:
			steer_vec += (player_pos - nearest_pos).normalized() * 1.35
		elif nearest_dist > 380.0:
			steer_vec += (nearest_pos - player_pos).normalized() * 0.65
		# Tangential orbit vector to kite enemies around Pillars and Cinder Pits
		var tangent := Vector2(-(nearest_pos - player_pos).y, (nearest_pos - player_pos).x).normalized()
		steer_vec += tangent * 0.60

	if hp_ratio < 0.85 or float(mp_cur) / float(mp_max) < 0.65:
		var shrine_pos := Vector2(330.0, 350.0)
		if player_pos.distance_to(shrine_pos) > 28.0:
			steer_vec += (shrine_pos - player_pos).normalized() * 0.95

	if steer_vec.length_squared() > 0.001:
		last_move_dir = steer_vec.normalized()
		player_pos += last_move_dir * get_frenzy_move_speed() * delta
		var p_col := resolve_circle_obstacle_collision(player_pos, PLAYER_RADIUS)
		player_pos = p_col.get("pos", player_pos)
		player_pos.x = clampf(player_pos.x, ARENA_MIN_BOUNDS.x, ARENA_MAX_BOUNDS.x)
		player_pos.y = clampf(player_pos.y, ARENA_MIN_BOUNDS.y, ARENA_MAX_BOUNDS.y)

	# Priority 7: Aim & Fire Primary Weapon at Best Target
	if best_target_idx >= 0:
		var t_pos: Vector2 = dummies[best_target_idx].get("pos", nearest_pos)
		var to_target: Vector2 = t_pos - player_pos
		if to_target.length_squared() > 1.0:
			aim_dir = to_target.normalized()
		if ai_fire_timer >= AI_FIRE_INTERVAL:
			ai_fire_timer = 0.0
			fire_arrow_at(t_pos, true)
			ai_last_action = "aim_and_fire"
			ai_decisions_count += 1
			actions_taken.append("aim_and_fire")

	queue_redraw()
	return {
		"ai_pilot_active": ai_pilot_active,
		"last_action": ai_last_action,
		"actions_taken": actions_taken,
		"decisions_total": ai_decisions_count,
		"player_pos": player_pos
	}


func _init_dummies(scale_wave: int = 1) -> void:
	var hp_mult: float = 1.0 + float(maxi(0, scale_wave - 1)) * 0.18
	var spd_mult: float = 1.0 + float(maxi(0, scale_wave - 1)) * 0.10
	dummies = [
		{
			"name": "Corruption Scout",
			"pos": Vector2(760.0, 200.0),
			"hp": int(round(45.0 * hp_mult)),
			"max_hp": int(round(45.0 * hp_mult)),
			"speed": BASE_ENEMY_CHASE_SPEED * 1.15 * spd_mult,
			"alive": true,
			"is_boss": false,
			"radius": DUMMY_RADIUS,
			"flash_timer": 0.0,
			"color": Color(0.85, 0.32, 0.32)
		},
		{
			"name": "Ashen Stalker",
			"pos": Vector2(880.0, 350.0),
			"hp": int(round(75.0 * hp_mult)),
			"max_hp": int(round(75.0 * hp_mult)),
			"speed": BASE_ENEMY_CHASE_SPEED * 1.0 * spd_mult,
			"alive": true,
			"is_boss": false,
			"radius": DUMMY_RADIUS,
			"flash_timer": 0.0,
			"color": Color(0.75, 0.42, 0.88)
		},
		{
			"name": "Blighted Sentinel",
			"pos": Vector2(760.0, 500.0),
			"hp": int(round(110.0 * hp_mult)),
			"max_hp": int(round(110.0 * hp_mult)),
			"speed": BASE_ENEMY_CHASE_SPEED * 0.82 * spd_mult,
			"alive": true,
			"is_boss": false,
			"radius": DUMMY_RADIUS,
			"flash_timer": 0.0,
			"color": Color(0.35, 0.78, 0.52)
		}
	]
	if scale_wave > 0 and scale_wave % 3 == 0:
		var boss_hp := int(round(220.0 * hp_mult))
		dummies.append({
			"name": "Ashen Titan [BOSS]",
			"pos": Vector2(980.0, 350.0),
			"hp": boss_hp,
			"max_hp": boss_hp,
			"speed": BASE_ENEMY_CHASE_SPEED * 0.78 * spd_mult,
			"alive": true,
			"is_boss": true,
			"enraged": false,
			"radius": 38.0,
			"flash_timer": 0.0,
			"color": Color(0.96, 0.62, 0.18)
		})
		_play_sfx("boss_spawn")


## Returns true if an alive Boss is currently in Phase 2 Molten Enrage.
func is_boss_enraged() -> bool:
	for d in dummies:
		if bool(d.get("alive", true)) and bool(d.get("is_boss", false)) and bool(d.get("enraged", false)):
			return true
	return false


## Summons 2 fast Cinder Imp minions flanking the Boss during Phase 2 Molten Enrage.
func _summon_cinder_imps(boss_pos: Vector2) -> int:
	var offsets := [Vector2(-58.0, -54.0), Vector2(-58.0, 54.0)]
	var count := 0
	for i in range(offsets.size()):
		var imp_pos: Vector2 = boss_pos + offsets[i]
		imp_pos.x = clampf(imp_pos.x, ARENA_MIN_BOUNDS.x + 24.0, ARENA_MAX_BOUNDS.x - 24.0)
		imp_pos.y = clampf(imp_pos.y, ARENA_MIN_BOUNDS.y + 24.0, ARENA_MAX_BOUNDS.y - 24.0)
		dummies.append({
			"name": "Cinder Imp [SUMMON]",
			"pos": imp_pos,
			"hp": 32,
			"max_hp": 32,
			"speed": BASE_ENEMY_CHASE_SPEED * 1.35,
			"alive": true,
			"is_boss": false,
			"is_summon": true,
			"radius": 18.0,
			"flash_timer": 0.0,
			"color": Color(1.0, 0.45, 0.15)
		})
		spawn_particle_burst(imp_pos, Color(1.0, 0.48, 0.12), 12, 1.2)
		count += 1
		total_cinder_imps_summoned += 1
	return count


## Triggers Phase 2 Molten Enrage on the Boss at boss_index (+30% speed, 2 Cinder Imp summons, and 5-Bolt Fireball Nova).
func check_and_trigger_boss_enrage(boss_index: int = -1, force_enrage: bool = false) -> Dictionary:
	var target_idx := boss_index
	if target_idx < 0:
		for i in range(dummies.size()):
			if bool(dummies[i].get("alive", true)) and bool(dummies[i].get("is_boss", false)):
				target_idx = i
				break
	if target_idx < 0 or target_idx >= dummies.size():
		return {"error": "No active Boss found"}

	var boss: Dictionary = dummies[target_idx]
	if not bool(boss.get("alive", true)) or not bool(boss.get("is_boss", false)):
		return {"error": "Target dummy is not an alive Boss"}
	if bool(boss.get("enraged", false)):
		return {"status": "already_enraged"}

	var hp_curr: int = int(boss.get("hp", 1))
	var hp_max: int = maxi(1, int(boss.get("max_hp", 1)))
	if not force_enrage and float(hp_curr) > float(hp_max) * BOSS_ENRAGE_HP_THRESHOLD:
		return {"status": "above_threshold", "hp_ratio": float(hp_curr) / float(hp_max)}

	boss["enraged"] = true
	boss["speed"] = float(boss.get("speed", BASE_ENEMY_CHASE_SPEED * 0.78)) * BOSS_ENRAGE_SPEED_MULTIPLIER
	boss["color"] = Color(1.0, 0.28, 0.12)
	dummies[target_idx] = boss
	total_boss_enrages += 1

	var b_pos: Vector2 = boss.get("pos", Vector2(980.0, 350.0))
	var imps_spawned: int = _summon_cinder_imps(b_pos)
	var nova_res: Dictionary = fire_enemy_projectile_from(target_idx, player_pos)

	spawn_particle_burst(b_pos, Color(1.0, 0.32, 0.08), 28, 1.65)
	trigger_screen_shake(0.65)
	spawn_floating_text(b_pos + Vector2(0, -18), "MOLTEN ENRAGE!", Color(1.0, 0.35, 0.12), true)
	_play_sfx("boss_spawn")

	var msg := "[BOSS PHASE 2: MOLTEN ENRAGE!] Ashen Titan enraged at %d/%d HP (+30%% Speed, Summoned %d Cinder Imps & Fired 5-Bolt Fireball Nova)!" % [
		hp_curr,
		hp_max,
		imps_spawned
	]
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "boss_enraged",
		"boss_index": target_idx,
		"boss_hp": hp_curr,
		"boss_max_hp": hp_max,
		"imps_summoned": imps_spawned,
		"nova_bolts_fired": int(nova_res.get("bolts_spawned", 0)),
		"message": msg
	}


## Returns true if the current wave is a Boss Wave (every 3rd wave).
func is_boss_wave() -> bool:
	return wave_number > 0 and wave_number % 3 == 0


## Cycles or sets the active Elemental Weapon Infusion Stance ([V] Key: "none" -> "frostbite" -> "cinderbrand" -> "stormchain").
func cycle_elemental_stance(target_stance: String = "") -> Dictionary:
	var req := target_stance.strip_edges().to_lower()
	if not req.is_empty() and ELEMENTAL_STANCES.has(req):
		elemental_stance = req
	else:
		var idx: int = ELEMENTAL_STANCES.find(elemental_stance)
		elemental_stance = ELEMENTAL_STANCES[(idx + 1) % ELEMENTAL_STANCES.size()]

	if _stance_btn != null:
		_stance_btn.text = "Infusion: %s [V]" % elemental_stance.to_upper()

	var stance_col := get_elemental_stance_color()
	spawn_particle_burst(player_pos, stance_col, 14, 1.15)
	spawn_floating_text(player_pos + Vector2(0, -22), "INFUSION: %s" % elemental_stance.to_upper(), stance_col, true)
	_play_sfx("relic_loot")

	var desc := "Physical (No Infusion)"
	match elemental_stance:
		"frostbite":
			desc = "Frostbite (-35% Enemy Speed for 3.5s)"
		"cinderbrand":
			desc = "Cinderbrand (Stacking +5 Burn DoT every 0.5s)"
		"stormchain":
			desc = "Stormchain (Arcs 50% Chain-Lightning Dmg to Nearby Enemy)"

	var msg := "[Elemental Infusion -> %s] Active weapon imbued with %s!" % [
		elemental_stance.to_upper(),
		desc
	]
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "stance_changed",
		"elemental_stance": elemental_stance,
		"description": desc,
		"message": msg
	}


func get_elemental_stance_color() -> Color:
	match elemental_stance:
		"frostbite":
			return Color(0.38, 0.90, 1.0)
		"cinderbrand":
			return Color(1.0, 0.48, 0.14)
		"stormchain":
			return Color(0.55, 0.95, 1.0)
		_:
			return Color(0.85, 0.90, 0.96)


## Applies the active Elemental Weapon Infusion effect ("frostbite", "cinderbrand", or "stormchain") to a struck enemy.
func apply_elemental_infusion_on_hit(dummy_index: int, hit_damage: int, allow_chain: bool = true) -> Dictionary:
	if elemental_stance == "none" or dummy_index < 0 or dummy_index >= dummies.size():
		return {"effect": "none"}

	var d: Dictionary = dummies[dummy_index]
	var d_pos: Vector2 = d.get("pos", Vector2.ZERO)

	if elemental_stance == "frostbite":
		if bool(d.get("alive", true)):
			d["frost_timer"] = FROST_DURATION
			dummies[dummy_index] = d
		total_chilled_hits += 1
		spawn_particle_burst(d_pos, Color(0.38, 0.92, 1.0), 12, 1.1)
		spawn_floating_text(d_pos + Vector2(0, -16), "CHILLED -35%!", Color(0.45, 0.94, 1.0), false)
		return {"effect": "frostbite", "frost_timer": FROST_DURATION, "slow_multiplier": FROST_SLOW_MULTIPLIER}

	elif elemental_stance == "cinderbrand":
		if bool(d.get("alive", true)):
			d["burn_timer"] = CINDER_DURATION
			d["burn_stacks"] = mini(3, int(d.get("burn_stacks", 0)) + 1)
			dummies[dummy_index] = d
		spawn_particle_burst(d_pos, Color(1.0, 0.45, 0.12), 12, 1.1)
		spawn_floating_text(d_pos + Vector2(0, -16), "IGNITED x%d!" % int(d.get("burn_stacks", 1)), Color(1.0, 0.58, 0.18), false)
		return {"effect": "cinderbrand", "burn_stacks": int(d.get("burn_stacks", 1))}

	elif elemental_stance == "stormchain" and allow_chain:
		var best_idx: int = -1
		var best_dist: float = STORMCHAIN_RANGE
		for i in range(dummies.size()):
			if i == dummy_index or not bool(dummies[i].get("alive", true)):
				continue
			var dist := d_pos.distance_to(dummies[i].get("pos", Vector2.ZERO))
			if dist <= best_dist:
				best_dist = dist
				best_idx = i
		if best_idx >= 0:
			var chain_dmg: int = maxi(4, int(round(float(hit_damage) * STORMCHAIN_RATIO)))
			var target_pos: Vector2 = dummies[best_idx].get("pos", Vector2.ZERO)
			lightning_arcs.append({
				"from": d_pos,
				"to": target_pos,
				"ttl": 0.28,
				"max_ttl": 0.28
			})
			total_stormchain_arcs += 1
			spawn_particle_burst(target_pos, Color(0.52, 0.96, 1.0), 14, 1.3)
			spawn_floating_text(target_pos + Vector2(0, -18), "CHAIN -%d!" % chain_dmg, Color(0.55, 0.96, 1.0), true)
			apply_damage_to_dummy(best_idx, chain_dmg, false, false)
			return {"effect": "stormchain", "chained_to_index": best_idx, "chain_damage": chain_dmg}

	return {"effect": elemental_stance}


## Steps active elemental debuffs (Frostbite chill decay, Cinderbrand burn DoT ticks, and Stormchain lightning arc TTLs).
func step_elemental_statuses(delta: float) -> Dictionary:
	var remaining_arcs: Array[Dictionary] = []
	for arc in lightning_arcs:
		arc["ttl"] = float(arc.get("ttl", 0.0)) - delta
		if float(arc["ttl"]) > 0.0:
			remaining_arcs.append(arc)
	lightning_arcs = remaining_arcs

	for i in range(dummies.size()):
		if not bool(dummies[i].get("alive", true)):
			continue
		var ft: float = float(dummies[i].get("frost_timer", 0.0))
		if ft > 0.0:
			dummies[i]["frost_timer"] = maxf(0.0, ft - delta)
		var bt: float = float(dummies[i].get("burn_timer", 0.0))
		if bt > 0.0:
			dummies[i]["burn_timer"] = maxf(0.0, bt - delta)
			if float(dummies[i]["burn_timer"]) <= 0.0:
				dummies[i]["burn_stacks"] = 0

	_elemental_burn_accum += delta
	var burn_ticks_applied: int = 0
	var total_burn_dmg: int = 0
	if _elemental_burn_accum >= 0.5:
		_elemental_burn_accum -= 0.5
		for i in range(dummies.size()):
			if not bool(dummies[i].get("alive", true)):
				continue
			var stacks: int = int(dummies[i].get("burn_stacks", 0))
			if float(dummies[i].get("burn_timer", 0.0)) > 0.0 and stacks > 0:
				var b_dmg: int = stacks * CINDER_BURN_DAMAGE_PER_STACK
				var d_pos: Vector2 = dummies[i].get("pos", Vector2.ZERO)
				total_elemental_burn_ticks += 1
				burn_ticks_applied += 1
				total_burn_dmg += b_dmg
				spawn_floating_text(d_pos, "-%d [CINDER x%d]" % [b_dmg, stacks], Color(1.0, 0.52, 0.16), false)
				apply_damage_to_dummy(i, b_dmg, false, false)

	return {
		"burn_ticks_applied": burn_ticks_applied,
		"total_burn_damage": total_burn_dmg,
		"active_lightning_arcs": lightning_arcs.size()
	}


## Spawns a gleaming Gold Coin drop on the dungeon floor and credits gold to the hero's pouch.
func spawn_coin_drop(world_pos: Vector2, amount: int, auto_credit: bool = false) -> Dictionary:
	var val: int = maxi(1, amount)
	if auto_credit:
		gold_coins += val
		total_gold_earned += val
	var coin := {
		"pos": world_pos,
		"amount": val,
		"credited": auto_credit,
		"ttl": 10.0
	}
	coin_drops.append(coin)
	spawn_particle_burst(world_pos, Color(1.0, 0.88, 0.25), 8, 0.95)
	spawn_floating_text(world_pos + Vector2(0, -14), "+%dg GOLD" % val, Color(1.0, 0.88, 0.24), false)
	_refresh_status_bar()
	queue_redraw()
	return coin


## Steps active Gold Coin drops on the floor, magnetizing them toward the hero and collecting them on contact.
func step_coin_drops(delta: float) -> int:
	var collected_this_step: int = 0
	var remaining: Array[Dictionary] = []
	for coin in coin_drops:
		var c_pos: Vector2 = coin.get("pos", Vector2.ZERO)
		var dist: float = c_pos.distance_to(player_pos)
		if dist <= COIN_MAGNET_RADIUS and dist > 0.001:
			var dir := (player_pos - c_pos).normalized()
			c_pos += dir * 320.0 * delta
			coin["pos"] = c_pos
			dist = c_pos.distance_to(player_pos)
		coin["ttl"] = float(coin.get("ttl", 5.0)) - delta
		if dist <= COIN_PICKUP_RADIUS:
			var amt: int = int(coin.get("amount", ENEMY_GOLD_REWARD))
			if not bool(coin.get("credited", false)):
				gold_coins += amt
				total_gold_earned += amt
			collected_this_step += amt
			_play_sfx("relic_loot")
			_refresh_status_bar()
			continue
		if float(coin["ttl"]) > 0.0:
			remaining.append(coin)
	coin_drops = remaining
	return collected_this_step


## Purchases an upgrade from Vaelor the Dungeon Merchant ([B] Key / "Merchant [B]" Button / "buy_upgrade" RPC).
func buy_merchant_upgrade(item_key: String = "") -> Dictionary:
	var catalog := {
		"whetstone": {"name": "Ashen Whetstone (+3 Dmg)", "cost": 35},
		"armor": {"name": "Obsidian Plate (+15 Max HP)", "cost": 40},
		"elixir": {"name": "Ashen Healing Elixir (+1 Potion)", "cost": 25}
	}
	var req := item_key.strip_edges().to_lower()
	if req.is_empty():
		var order := ["whetstone", "armor", "elixir"]
		req = order[shop_purchases_count % order.size()]
		if gold_coins < int(catalog[req]["cost"]):
			for candidate in order:
				if gold_coins >= int(catalog[candidate]["cost"]):
					req = candidate
					break

	if not catalog.has(req):
		return {"error": "Unknown merchant item '%s'" % req}

	var item_info: Dictionary = catalog[req]
	var cost: int = int(item_info["cost"])
	var item_name: String = str(item_info["name"])
	if gold_coins < cost:
		var err_msg := "[Merchant: Vaelor] Need %dg for %s (You have %dg)!" % [cost, item_name, gold_coins]
		if _combat_banner != null:
			_combat_banner.text = err_msg
		return {"error": "Insufficient gold", "required_gold": cost, "current_gold": gold_coins, "message": err_msg}

	gold_coins -= cost
	shop_purchases_count += 1

	match req:
		"whetstone":
			shop_bonus_damage += 3
		"armor":
			shop_bonus_max_hp += 15
			if loader != null and not loader.current_data.is_empty():
				var h: Dictionary = loader.current_data.get("health", {"current": 45, "max": 45})
				h["max"] = int(h.get("max", 45)) + 15
				h["current"] = mini(int(h["max"]), int(h.get("current", 45)) + 15)
				loader.current_data["health"] = h
		"elixir":
			if loader != null and loader.has_method("grant_consumable_potion"):
				loader.grant_consumable_potion(1)

	spawn_particle_burst(player_pos, Color(1.0, 0.88, 0.25), 18, 1.3)
	spawn_floating_text(player_pos + Vector2(0, -22), "BOUGHT: %s!" % req.to_upper(), Color(1.0, 0.90, 0.28), true)
	_play_sfx("level_up")

	var msg := "[Dungeon Merchant -> Purchased %s (-%dg)] Gold Remaining: %dg (Shop Upgrades: %d, Bonus Dmg: +%d)!" % [
		item_name,
		cost,
		gold_coins,
		shop_purchases_count,
		shop_bonus_damage
	]
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "purchased",
		"item_key": req,
		"item_name": item_name,
		"cost": cost,
		"gold_remaining": gold_coins,
		"shop_bonus_damage": shop_bonus_damage,
		"shop_bonus_max_hp": shop_bonus_max_hp,
		"shop_purchases_count": shop_purchases_count,
		"message": msg
	}


func _build_arena_overlay() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ArenaOverlay"
	add_child(_ui_layer)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 68)
	_ui_layer.add_child(top_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 10)
	top_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_status_label = Label.new()
	_status_label.name = "ArenaStatusLabel"
	_status_label.text = "2D ARENA — WASD: Move | Click/Space: Attack | [Shift]: Dash | [Q]: Ultimate | [G]: Wave Survival"
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	vbox.add_child(_status_label)

	_combat_banner = Label.new()
	_combat_banner.name = "ArenaCombatBanner"
	_combat_banner.text = "Press [Q] for Class Ultimate (-15 MP), [Shift] to Mana Dash (-6 MP), or [G] for Wave Survival!"
	_combat_banner.add_theme_color_override("font_color", Color(0.65, 0.88, 0.75))
	vbox.add_child(_combat_banner)

	_wave_btn = Button.new()
	_wave_btn.name = "WaveSurvivalButton"
	_wave_btn.text = "Wave Survival: OFF [G]"
	_wave_btn.pressed.connect(toggle_wave_survival)
	hbox.add_child(_wave_btn)

	_ai_btn = Button.new()
	_ai_btn.name = "AiPilotButton"
	_ai_btn.text = "AI Pilot: OFF [P]"
	_ai_btn.pressed.connect(toggle_ai_pilot)
	hbox.add_child(_ai_btn)

	_stance_btn = Button.new()
	_stance_btn.name = "ElementalStanceButton"
	_stance_btn.text = "Infusion: NONE [V]"
	_stance_btn.pressed.connect(func() -> void: cycle_elemental_stance())
	hbox.add_child(_stance_btn)

	var dash_btn := Button.new()
	dash_btn.name = "ManaDashButton"
	dash_btn.text = "Mana Dash [Shift]"
	dash_btn.pressed.connect(func() -> void: trigger_mana_dash())
	hbox.add_child(dash_btn)

	var parry_btn := Button.new()
	parry_btn.name = "ArcaneParryButton"
	parry_btn.text = "Parry [F]"
	parry_btn.pressed.connect(func() -> void: trigger_arcane_parry())
	hbox.add_child(parry_btn)

	var ult_btn := Button.new()
	ult_btn.name = "UltimateAbilityButton"
	ult_btn.text = "Ultimate [Q]"
	ult_btn.pressed.connect(func() -> void: trigger_ultimate_ability())
	hbox.add_child(ult_btn)

	var loot_btn := Button.new()
	loot_btn.name = "LootRelicButton"
	loot_btn.text = "Loot Chest [E]"
	loot_btn.pressed.connect(func() -> void: collect_nearest_relic_chest(true))
	hbox.add_child(loot_btn)

	var pot_btn := Button.new()
	pot_btn.name = "ArenaPotionButton"
	pot_btn.text = "Potion [C]"
	pot_btn.pressed.connect(func() -> void: trigger_use_potion())
	hbox.add_child(pot_btn)

	var room_btn := Button.new()
	room_btn.name = "NextRoomButton"
	room_btn.text = "Next Room [N]"
	room_btn.pressed.connect(func() -> void: enter_next_unexplored_room())
	hbox.add_child(room_btn)

	var shop_btn := Button.new()
	shop_btn.name = "MerchantShopButton"
	shop_btn.text = "Merchant [B]"
	shop_btn.pressed.connect(func() -> void: buy_merchant_upgrade())
	hbox.add_child(shop_btn)

	_sfx_btn = Button.new()
	_sfx_btn.name = "SfxMuteButton"
	_sfx_btn.text = "SFX: ON [M]"
	_sfx_btn.pressed.connect(_on_toggle_sfx_mute)
	hbox.add_child(_sfx_btn)

	var lvl_btn := Button.new()
	lvl_btn.text = "Level Up [L]"
	lvl_btn.pressed.connect(_on_arena_level_up)
	hbox.add_child(lvl_btn)

	var back_btn := Button.new()
	back_btn.name = "BackToSheetButton"
	back_btn.text = "Character Sheet [Tab]"
	back_btn.pressed.connect(func() -> void: request_hud_toggle.emit())
	hbox.add_child(back_btn)


## Enables or disables the 2D Arena rendering and input processing.
func set_arena_active(is_active: bool) -> void:
	arena_active = is_active
	visible = is_active
	if _ui_layer != null:
		_ui_layer.visible = is_active
	_refresh_status_bar()
	queue_redraw()


## Toggles Wave Survival Mode (chasing enemies, wave progression, and score tracking).
func toggle_wave_survival() -> bool:
	wave_survival_active = not wave_survival_active
	if wave_survival_active:
		wave_number = 1
		wave_score = 0
		player_pos = Vector2(220.0, 350.0)
		_init_dummies(wave_number)
		if _wave_btn != null:
			_wave_btn.text = "Wave Survival: ON [G]"
		var msg := "[Wave Survival] Wave 1 Started! Enemies are pursuing — use [Shift] to Mana Dash and kite!"
		if _combat_banner != null:
			_combat_banner.text = msg
		arena_combat_event.emit(msg)
	else:
		_init_dummies(1)
		if _wave_btn != null:
			_wave_btn.text = "Wave Survival: OFF [G]"
		var msg := "[Practice Mode] Returned to stationary target dummy practice."
		if _combat_banner != null:
			_combat_banner.text = msg
		arena_combat_event.emit(msg)

	_refresh_status_bar()
	queue_redraw()
	return wave_survival_active


## Executes a Mana Dash (-6 MP), bursting the hero 145 px and granting 0.45s of invulnerability frames.
func trigger_mana_dash(override_dir: Vector2 = Vector2.ZERO) -> Dictionary:
	if dash_cooldown_timer > 0.0:
		return {"error": "Dash on cooldown", "cooldown": dash_cooldown_timer}

	var current_mp: int = 0
	if loader != null and not loader.current_data.is_empty():
		var mana: Dictionary = loader.current_data.get("mana", {})
		current_mp = int(mana.get("current", 0))

	if current_mp < DASH_MANA_COST:
		var low_msg := "[Mana Dash] Not enough Mana (%d/%d MP required)!" % [current_mp, DASH_MANA_COST]
		if _combat_banner != null:
			_combat_banner.text = low_msg
		return {"error": "Insufficient mana", "current_mp": current_mp}

	var dash_dir := override_dir.normalized() if override_dir.length_squared() > 0.001 else last_move_dir
	if dash_dir.length_squared() < 0.001:
		dash_dir = aim_dir if aim_dir.length_squared() > 0.001 else Vector2.RIGHT

	if loader != null and loader.has_method("modify_mana"):
		loader.modify_mana(-DASH_MANA_COST, true)

	player_pos += dash_dir * DASH_BURST_DISTANCE
	var dash_col := resolve_circle_obstacle_collision(player_pos, PLAYER_RADIUS)
	player_pos = dash_col.get("pos", player_pos)
	player_pos.x = clampf(player_pos.x, ARENA_MIN_BOUNDS.x, ARENA_MAX_BOUNDS.x)
	player_pos.y = clampf(player_pos.y, ARENA_MIN_BOUNDS.y, ARENA_MAX_BOUNDS.y)

	dash_iframe_timer = DASH_IFRAME_DURATION
	var secondary_rank: int = 0
	if loader != null and not loader.current_data.is_empty():
		var skills: Array = loader.current_data.get("skills", [])
		if skills.size() > 1:
			secondary_rank = int(skills[1].get("rank", 0))
	dash_cooldown_timer = maxf(0.35, BASE_DASH_COOLDOWN - float(secondary_rank) * DASH_CD_PER_RANK)

	var dash_skill_name := "Mobility Dash"
	if loader != null and not loader.current_data.is_empty():
		var skills: Array = loader.current_data.get("skills", [])
		if skills.size() > 1:
			dash_skill_name = str(skills[1].get("name", "Mobility Dash"))

	var msg := "[Mana Dash: %s] Spent %d MP -> Bursted %d px (0.45s Invulnerability)!" % [
		dash_skill_name,
		DASH_MANA_COST,
		int(DASH_BURST_DISTANCE)
	]
	_play_sfx("dash")
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "dashed",
		"new_pos": player_pos,
		"mana_spent": DASH_MANA_COST,
		"iframe_timer": dash_iframe_timer,
		"message": msg
	}


## Applies Constitution-mitigated enemy contact damage to the active hero.
func apply_enemy_contact_hit(enemy_name: String) -> Dictionary:
	if dash_iframe_timer > 0.0:
		return {"status": "dodged_with_iframes"}

	combo_count = 0
	combo_timer = 0.0
	var armor: int = loader.get_armor_reduction() if (loader != null and loader.has_method("get_armor_reduction")) else 0
	var actual_dmg: int = maxi(2, CONTACT_BASE_DAMAGE - armor)
	dash_iframe_timer = CONTACT_IFRAME_DURATION

	var remaining_hp: int = 1
	if loader != null and loader.has_method("modify_health"):
		var updated: Dictionary = loader.modify_health(-actual_dmg)
		remaining_hp = int(updated.get("health", {}).get("current", 1))

	spawn_floating_text(player_pos, "-%d HP" % actual_dmg, Color(1.0, 0.35, 0.35), false)
	var msg := "[Enemy Contact!] %s struck hero for %d dmg (Armor mitigated -%d)." % [
		enemy_name,
		actual_dmg,
		armor
	]
	if remaining_hp <= 0 and loader != null:
		# Auto-revive and reset wave on defeat
		var idx: int = int(loader.current_roster_index)
		loader.select_roster_character(idx)
		msg = "[Hero Defeated on Wave %d (Score: %d)!] Revived at full HP/MP for Wave 1." % [wave_number, wave_score]
		wave_number = 1
		wave_score = 0
		player_pos = Vector2(220.0, 350.0)
		_init_dummies(1)

	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {"damage_taken": actual_dmg, "armor_mitigated": armor, "remaining_hp": remaining_hp, "message": msg}


## Fires a ranged Cinder Bolt (or 3-bolt Boss Fireball Volley if shooter is a Boss) from a dummy toward target_pos.
func fire_enemy_projectile_from(dummy_index: int, target_pos: Vector2 = Vector2(-1.0, -1.0)) -> Dictionary:
	if dummy_index < 0 or dummy_index >= dummies.size():
		return {"error": "Invalid dummy index"}
	var shooter: Dictionary = dummies[dummy_index]
	if not bool(shooter.get("alive", true)):
		return {"error": "Shooter is not alive"}

	var origin: Vector2 = shooter.get("pos", Vector2(880.0, 350.0))
	var s_rad: float = float(shooter.get("radius", DUMMY_RADIUS))
	var is_boss: bool = bool(shooter.get("is_boss", false))
	var is_enraged: bool = bool(shooter.get("enraged", false))
	var shooter_name: String = str(shooter.get("name", "Enemy"))
	var dest: Vector2 = player_pos if target_pos.x < 0.0 else target_pos
	var base_dir: Vector2 = (dest - origin).normalized()
	if base_dir.length_squared() < 0.001:
		base_dir = Vector2.LEFT

	var angles: Array = [0.0]
	if is_boss:
		angles = [-36.0, -18.0, 0.0, 18.0, 36.0] if is_enraged else [-16.0, 0.0, 16.0]
	var bolt_dmg: int = ENEMY_PROJECTILE_BASE_DAMAGE + (6 if is_enraged else (4 if is_boss else 0))
	var bolt_rad: float = 9.0 if is_enraged else (8.0 if is_boss else 6.0)
	var bolt_spd: float = ENEMY_PROJECTILE_SPEED * (1.15 if is_enraged else 1.0)
	var spawned_count: int = 0

	for deg in angles:
		var dir: Vector2 = base_dir.rotated(deg_to_rad(float(deg)))
		enemy_projectiles.append({
			"pos": origin + dir * (s_rad + 8.0),
			"vel": dir * bolt_spd,
			"damage": bolt_dmg,
			"radius": bolt_rad,
			"is_boss_fireball": is_boss,
			"is_enraged_nova": is_enraged,
			"shooter": shooter_name,
			"ttl": 2.6
		})
		spawned_count += 1
		enemy_projectiles_spawned_total += 1

	_play_sfx("shoot")
	queue_redraw()
	return {
		"status": "fired",
		"shooter": shooter_name,
		"bolts_spawned": spawned_count,
		"is_boss_volley": is_boss,
		"is_enraged_nova": is_enraged,
		"damage_per_bolt": bolt_dmg
	}


## Applies Constitution-mitigated enemy ranged projectile damage to the active hero.
func apply_enemy_projectile_hit(shooter_name: String, raw_damage: int) -> Dictionary:
	if dash_iframe_timer > 0.0:
		spawn_floating_text(player_pos, "DODGED!", Color(0.42, 0.95, 1.0), false)
		return {"status": "dodged_with_iframes", "damage_taken": 0}

	combo_count = 0
	combo_timer = 0.0
	var armor: int = loader.get_armor_reduction() if (loader != null and loader.has_method("get_armor_reduction")) else 0
	var actual_dmg: int = maxi(2, raw_damage - armor)
	dash_iframe_timer = CONTACT_IFRAME_DURATION

	var remaining_hp: int = 1
	if loader != null and loader.has_method("modify_health"):
		var updated: Dictionary = loader.modify_health(-actual_dmg)
		remaining_hp = int(updated.get("health", {}).get("current", 1))

	spawn_floating_text(player_pos, "-%d HP" % actual_dmg, Color(1.0, 0.35, 0.35), false)
	var msg := "[Enemy Projectile Hit!] %s's Cinder Bolt struck hero for %d dmg (Armor mitigated -%d)." % [
		shooter_name,
		actual_dmg,
		armor
	]
	if remaining_hp <= 0 and loader != null:
		var idx: int = int(loader.current_roster_index)
		loader.select_roster_character(idx)
		msg = "[Hero Defeated on Wave %d (Score: %d)!] Revived at full HP/MP for Wave 1." % [wave_number, wave_score]
		wave_number = 1
		wave_score = 0
		player_pos = Vector2(220.0, 350.0)
		enemy_projectiles.clear()
		_init_dummies(1)

	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "hit_player",
		"damage_taken": actual_dmg,
		"armor_mitigated": armor,
		"remaining_hp": remaining_hp,
		"message": msg
	}


## Activates a 0.35s Arcane Parry Reflect Shield ([F] key), deflecting incoming enemy Cinder Bolts & Boss Fireballs back at 2x damage.
func trigger_arcane_parry() -> Dictionary:
	if parry_cooldown_timer > 0.0:
		return {"error": "Arcane Parry on cooldown", "cooldown": parry_cooldown_timer}

	parry_window_timer = PARRY_WINDOW_DURATION
	parry_cooldown_timer = PARRY_COOLDOWN
	var reflected_now: int = 0
	var remaining_bolts: Array[Dictionary] = []

	for bolt in enemy_projectiles:
		var b_pos: Vector2 = bolt.get("pos", Vector2.ZERO)
		if b_pos.distance_to(player_pos) <= PARRY_REFLECT_RADIUS:
			_reflect_enemy_bolt(bolt)
			reflected_now += 1
		else:
			remaining_bolts.append(bolt)
	enemy_projectiles = remaining_bolts

	if reflected_now > 0:
		parry_cooldown_timer = 0.25
		var msg := "[ARCANE PARRY!] Deflected %d enemy projectile(s) back at 2x CRIT Damage (+%d MP)!" % [
			reflected_now,
			reflected_now * 5
		]
		if _combat_banner != null:
			_combat_banner.text = msg
		arena_combat_event.emit(msg)
		_refresh_status_bar()
		queue_redraw()
		return {
			"status": "parried_projectiles",
			"reflected_count": reflected_now,
			"total_parried": total_projectiles_parried,
			"message": msg
		}

	_play_sfx("dash")
	var stance_msg := "[Arcane Parry Stance] Reflect shield active for 0.35s!"
	if _combat_banner != null:
		_combat_banner.text = stance_msg
	queue_redraw()
	return {
		"status": "parry_window_active",
		"reflected_count": 0,
		"window_timer": parry_window_timer,
		"message": stance_msg
	}


func _reflect_enemy_bolt(bolt: Dictionary) -> void:
	var b_pos: Vector2 = bolt.get("pos", player_pos)
	var b_vel: Vector2 = bolt.get("vel", Vector2.LEFT * ENEMY_PROJECTILE_SPEED)
	var ref_dir: Vector2 = (-b_vel).normalized()
	if ref_dir.length_squared() < 0.001:
		ref_dir = aim_dir if aim_dir.length_squared() > 0.001 else Vector2.RIGHT
	var ref_dmg: int = maxi(get_calculated_arrow_damage(), int(bolt.get("damage", ENEMY_PROJECTILE_BASE_DAMAGE)) * 2)
	arrows.append({
		"pos": b_pos + ref_dir * 10.0,
		"vel": ref_dir * (ARROW_SPEED * 1.35),
		"damage": ref_dmg,
		"is_crit": true,
		"is_parried": true,
		"ttl": 2.2
	})
	total_projectiles_parried += 1
	register_combo_hit()
	if loader != null and loader.has_method("modify_mana"):
		loader.modify_mana(5, true)
	spawn_particle_burst(player_pos, Color(0.45, 0.98, 1.0), 16, 1.25)
	trigger_screen_shake(0.35)
	spawn_floating_text(player_pos + Vector2(0, -18), "PARRIED 2x!", Color(0.45, 0.98, 1.0), true)
	_play_sfx("ultimate")


## Steps all active enemy projectiles, checking Obsidian Pillar cover blocks, Arcane Parry deflection, and player hits/dodges.
func step_enemy_projectiles(delta: float) -> Dictionary:
	var blocked_by_cover: int = 0
	var player_hits: int = 0
	var dodged_hits: int = 0
	var parried_hits: int = 0
	var remaining: Array[Dictionary] = []

	for bolt in enemy_projectiles:
		bolt["pos"] += (bolt["vel"] as Vector2) * delta
		bolt["ttl"] = float(bolt["ttl"]) - delta
		var pos: Vector2 = bolt["pos"]
		var b_rad: float = float(bolt.get("radius", 6.0))

		# 1. Check Obsidian Pillar cover interception
		var obs_idx: int = check_projectile_obstacle_hit(pos)
		if obs_idx >= 0:
			obstacle_blocks_count += 1
			enemy_projectiles_blocked_by_cover += 1
			blocked_by_cover += 1
			obstacles[obs_idx]["flash_timer"] = 0.16
			spawn_floating_text(obstacles[obs_idx].get("pos", pos), "COVER BLOCK!", Color(0.45, 0.95, 1.0), false)
			_play_sfx("hit")
			continue

		# 2. Check Arcane Parry Reflect Shield when active
		if parry_window_timer > 0.0 and pos.distance_to(player_pos) <= PARRY_REFLECT_RADIUS + b_rad:
			_reflect_enemy_bolt(bolt)
			parried_hits += 1
			continue

		# 3. Check impact against player avatar (respecting Mana Dash i-frames)
		if pos.distance_to(player_pos) <= PLAYER_RADIUS + b_rad:
			if dash_iframe_timer > 0.0:
				dodged_hits += 1
				spawn_floating_text(player_pos, "DODGED!", Color(0.42, 0.95, 1.0), false)
			else:
				player_hits += 1
				apply_enemy_projectile_hit(str(bolt.get("shooter", "Enemy")), int(bolt.get("damage", ENEMY_PROJECTILE_BASE_DAMAGE)))
			continue

		if float(bolt["ttl"]) > 0.0 and pos.x <= ARENA_MAX_BOUNDS.x + 40.0 and pos.x >= ARENA_MIN_BOUNDS.x - 40.0 and pos.y <= ARENA_MAX_BOUNDS.y + 40.0 and pos.y >= ARENA_MIN_BOUNDS.y - 40.0:
			remaining.append(bolt)

	enemy_projectiles = remaining
	return {
		"blocked_by_cover": blocked_by_cover,
		"player_hits": player_hits,
		"dodged_hits": dodged_hits,
		"parried_hits": parried_hits
	}


## Calculates the active hero's movement speed from their Dexterity modifier + equipped Relic bonuses.
func get_calculated_move_speed() -> float:
	if loader == null or loader.current_data.is_empty():
		return BASE_MOVE_SPEED
	var attrs: Dictionary = loader.current_data.get("attributes", {})
	var dex_score: int = int(attrs.get("dexterity", 10))
	var dex_mod: int = loader.get_attribute_modifier(dex_score)
	var relic_spd: float = 0.0
	if loader.has_method("get_inventory_bonuses"):
		relic_spd = float(loader.get_inventory_bonuses().get("speed", 0.0))
	return BASE_MOVE_SPEED + float(dex_mod) * SPEED_PER_DEX_MOD + relic_spd


## Calculates primary attack damage from Base(6) + Primary Skill Rank + Linked Attribute Modifier + Relic Bonuses.
func get_calculated_arrow_damage() -> int:
	if loader == null or loader.current_data.is_empty():
		return BASE_ARROW_DAMAGE
	var attrs: Dictionary = loader.current_data.get("attributes", {})
	var skills: Array = loader.current_data.get("skills", [])
	var primary_rank: int = 0
	var mod_attr: String = "dexterity"
	if not skills.is_empty():
		primary_rank = int(skills[0].get("rank", 0))
		mod_attr = str(skills[0].get("modifier", "dexterity"))

	var attr_score: int = int(attrs.get(mod_attr, 10))
	var attr_mod: int = loader.get_attribute_modifier(attr_score)
	var relic_dmg: int = 0
	if loader.has_method("get_inventory_bonuses"):
		relic_dmg = int(loader.get_inventory_bonuses().get("damage", 0))
	return maxi(1, BASE_ARROW_DAMAGE + primary_rank + attr_mod + relic_dmg + shop_bonus_damage)


## Calculates the active hero's Critical Hit chance (0.05 to 0.65) from Base(8%) + 3% per Dexterity/Wisdom modifier + 10% Frenzy bonus.
func get_calculated_crit_chance() -> float:
	if loader == null or loader.current_data.is_empty():
		return BASE_CRIT_CHANCE
	var attrs: Dictionary = loader.current_data.get("attributes", {})
	var dex_mod: int = loader.get_attribute_modifier(int(attrs.get("dexterity", 10)))
	var wis_mod: int = loader.get_attribute_modifier(int(attrs.get("wisdom", 10)))
	var best_mod: int = maxi(0, maxi(dex_mod, wis_mod))
	var frenzy_bonus: float = FRENZY_CRIT_BONUS if is_frenzy_active() else 0.0
	return clampf(BASE_CRIT_CHANCE + float(best_mod) * CRIT_PER_MOD + frenzy_bonus, 0.05, 0.65)


## Rolls whether an attack is a Critical Hit (2x damage), respecting force_next_crit for deterministic testing.
func roll_critical_hit(allow_random: bool = true) -> bool:
	if force_next_crit:
		force_next_crit = false
		return true
	if allow_random:
		return randf() < get_calculated_crit_chance()
	return false


## Spawns a rising, fading Floating Combat Text popup at world_pos.
func spawn_floating_text(world_pos: Vector2, text_str: String, color: Color = Color(1.0, 0.92, 0.75), is_crit: bool = false) -> Dictionary:
	var ttl_val: float = 0.95 if is_crit else 0.75
	var popup := {
		"pos": world_pos + Vector2(0.0, -28.0),
		"vel": Vector2(0.0, -48.0 if is_crit else -36.0),
		"text": text_str,
		"color": color,
		"is_crit": is_crit,
		"ttl": ttl_val,
		"max_ttl": ttl_val
	}
	floating_texts.append(popup)
	total_floating_texts_spawned += 1
	queue_redraw()
	return popup


## Steps all active Floating Combat Text popups and removes expired ones.
func step_floating_texts(delta: float) -> void:
	if floating_texts.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for ft in floating_texts:
		ft["pos"] += (ft["vel"] as Vector2) * delta
		ft["ttl"] = float(ft["ttl"]) - delta
		if float(ft["ttl"]) > 0.0:
			remaining.append(ft)
	floating_texts = remaining


## Spawns a burst of directional pixel-spark particles at world_pos and optionally triggers camera screen-shake.
func spawn_particle_burst(world_pos: Vector2, base_color: Color, count: int = 12, speed_scale: float = 1.0) -> int:
	var spawned: int = 0
	for i in range(count):
		var angle: float = (TAU / float(maxi(1, count))) * float(i) + randf_range(-0.22, 0.22)
		var spd: float = randf_range(65.0, 175.0) * speed_scale
		var ttl_val: float = randf_range(0.28, 0.55)
		particles.append({
			"pos": world_pos,
			"vel": Vector2.RIGHT.rotated(angle) * spd,
			"color": base_color.lightened(randf_range(0.0, 0.35)),
			"size": randf_range(3.0, 6.0),
			"ttl": ttl_val,
			"max_ttl": ttl_val
		})
		spawned += 1
		total_particles_spawned += 1
	queue_redraw()
	return spawned


## Steps all active pixel-spark particles and decays camera screen-shake trauma.
func step_particles(delta: float) -> void:
	if screen_shake_trauma > 0.0:
		screen_shake_trauma = maxf(0.0, screen_shake_trauma - delta * 2.8)
		var shake_mag: float = screen_shake_trauma * screen_shake_trauma * 11.0
		position = Vector2(randf_range(-shake_mag, shake_mag), randf_range(-shake_mag, shake_mag))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

	if particles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for p in particles:
		p["pos"] += (p["vel"] as Vector2) * delta
		p["vel"] = (p["vel"] as Vector2) * maxf(0.0, 1.0 - delta * 3.5)
		p["ttl"] = float(p["ttl"]) - delta
		if float(p["ttl"]) > 0.0:
			remaining.append(p)
	particles = remaining


## Adds trauma (0.0 to 1.0) to trigger camera screen-shake on crits, ultimates, parries, and boss hits.
func trigger_screen_shake(trauma_amount: float = 0.45) -> void:
	screen_shake_trauma = clampf(screen_shake_trauma + trauma_amount, 0.0, 1.0)


## Spawns a collectible Relic Chest in the arena at world_pos.
func spawn_relic_chest(world_pos: Vector2, relic_index: int = 0) -> Dictionary:
	var clamped_pos := Vector2(
		clampf(world_pos.x, ARENA_MIN_BOUNDS.x + 30.0, ARENA_MAX_BOUNDS.x - 30.0),
		clampf(world_pos.y, ARENA_MIN_BOUNDS.y + 30.0, ARENA_MAX_BOUNDS.y - 30.0)
	)
	var chest := {
		"pos": clamped_pos,
		"relic_index": relic_index,
		"label": "Relic Chest [E]"
	}
	loot_chests.append(chest)
	queue_redraw()
	return chest


## Collects the nearest Relic Chest (either within pickup radius or remotely via [E] / RPC) and grants its Relic.
func collect_nearest_relic_chest(allow_remote_pickup: bool = true) -> Dictionary:
	if loot_chests.is_empty():
		return {"error": "No Relic Chests available in arena"}

	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(loot_chests.size()):
		var c_pos: Vector2 = loot_chests[i].get("pos", player_pos)
		var dist := player_pos.distance_to(c_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	if best_idx < 0:
		return {"error": "No valid chest found"}
	if not allow_remote_pickup and best_dist > CHEST_PICKUP_RADIUS:
		return {"status": "out_of_range", "distance": best_dist}

	var chest: Dictionary = loot_chests[best_idx]
	loot_chests.remove_at(best_idx)
	var relic_idx: int = int(chest.get("relic_index", 0))

	var grant_res: Dictionary = {}
	if loader != null and loader.has_method("grant_relic_item"):
		grant_res = loader.grant_relic_item(relic_idx)

	var msg: String = str(grant_res.get("message", "[Relic Chest] Looted Relic!"))
	spawn_floating_text(player_pos, "+RELIC!", Color(1.0, 0.88, 0.32), true)
	_play_sfx("relic_loot")
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return grant_res


## Uses 1 consumable potion ([C] key) from the active hero's inventory to restore +25 HP & +12 MP.
func trigger_use_potion() -> Dictionary:
	if loader == null or not loader.has_method("use_consumable_potion"):
		return {"error": "CharacterLoader unavailable"}

	var res: Dictionary = loader.use_consumable_potion()
	var msg: String = str(res.get("message", ""))
	if res.get("status") == "consumed":
		spawn_floating_text(player_pos, "+25 HP / +12 MP", Color(0.38, 0.96, 0.55), false)
		_play_sfx("relic_loot")
	if _combat_banner != null and not msg.is_empty():
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return res


## Returns the name of the active hero's primary attack skill.
func get_primary_attack_name() -> String:
	if loader != null and not loader.current_data.is_empty():
		var skills: Array = loader.current_data.get("skills", [])
		if not skills.is_empty():
			return str(skills[0].get("name", "Attack"))
	return "Longbow"


## Returns the name of the active hero's class Ultimate Ability ([Q] key).
func get_ultimate_ability_name() -> String:
	if loader == null or loader.current_data.is_empty():
		return "Multi-Shot Volley"
	var cid := str(loader.current_data.get("character_id", "char_001"))
	match cid:
		"ash_001":
			return "Consecrated Ember Nova"
		"ash_002":
			return "Phantom Blade Storm"
		"ash_003":
			return "Blighted Spore Quake"
		_:
			return "Multi-Shot Volley"


## Executes the active hero's class-specific Ultimate Ability (-15 MP, [Q] key).
func trigger_ultimate_ability() -> Dictionary:
	if ultimate_cooldown_timer > 0.0:
		return {"error": "Ultimate on cooldown", "cooldown": ultimate_cooldown_timer}

	var current_mp: int = 0
	if loader != null and not loader.current_data.is_empty():
		var mana: Dictionary = loader.current_data.get("mana", {})
		current_mp = int(mana.get("current", 0))

	if current_mp < ULTIMATE_MANA_COST:
		var low_msg := "[Ultimate] Not enough Mana (%d/%d MP required)!" % [current_mp, ULTIMATE_MANA_COST]
		if _combat_banner != null:
			_combat_banner.text = low_msg
		return {"error": "Insufficient mana", "current_mp": current_mp}

	if loader != null and loader.has_method("modify_mana"):
		loader.modify_mana(-ULTIMATE_MANA_COST, true)

	ultimate_cooldown_timer = ULTIMATE_COOLDOWN
	ult_vfx_timer = 0.55

	var cid := "char_001"
	if loader != null and not loader.current_data.is_empty():
		cid = str(loader.current_data.get("character_id", "char_001"))

	var ult_name := get_ultimate_ability_name()
	var base_dmg := get_calculated_arrow_damage()
	var projectiles_spawned: int = 0
	var targets_hit: int = 0
	var total_aoe_damage: int = 0
	var msg := ""

	match cid:
		"ash_001":
			# Malakor, The Ash-Knight: Consecrated Ember Nova (AoE shockwave + self-heal +12 HP)
			ult_vfx_radius = ULTIMATE_NOVA_RADIUS
			var nova_dmg: int = base_dmg * 2 + 12
			for i in range(dummies.size()):
				if not bool(dummies[i].get("alive", true)):
					continue
				if player_pos.distance_to(dummies[i]["pos"]) <= ULTIMATE_NOVA_RADIUS or not wave_survival_active:
					apply_damage_to_dummy(i, nova_dmg)
					targets_hit += 1
					total_aoe_damage += nova_dmg
			if loader != null and loader.has_method("modify_health"):
				loader.modify_health(12)
			msg = "[ULTIMATE: %s] Unleashed Ember Nova (%d AoE Dmg to %d target(s)) & healed +12 HP!" % [
				ult_name,
				nova_dmg,
				targets_hit
			]
		"ash_002":
			# Vespera, Echo-Wraith: Phantom Blade Storm (8 radial daggers + shadow strike all + 0.75s i-frames)
			ult_vfx_radius = 220.0
			dash_iframe_timer = maxf(dash_iframe_timer, 0.75)
			var dagger_dmg: int = base_dmg + 10
			for step in range(8):
				var angle := float(step) * (TAU / 8.0)
				var dir := Vector2.RIGHT.rotated(angle)
				arrows.append({
					"pos": player_pos + dir * (PLAYER_RADIUS + 8.0),
					"vel": dir * (ARROW_SPEED * 1.15),
					"damage": dagger_dmg,
					"ttl": 1.6
				})
				projectiles_spawned += 1
			var shadow_dmg: int = base_dmg + 14
			for i in range(dummies.size()):
				if bool(dummies[i].get("alive", true)):
					apply_damage_to_dummy(i, shadow_dmg)
					targets_hit += 1
					total_aoe_damage += shadow_dmg
			msg = "[ULTIMATE: %s] Fired 8 radial daggers & shadow-struck %d target(s) for %d dmg (0.75s i-frames)!" % [
				ult_name,
				targets_hit,
				shadow_dmg
			]
		"ash_003":
			# Gorvath, Rotting Sentinel: Blighted Spore Quake (Arena-wide tremor + 35% slow + 1.0s i-frames)
			ult_vfx_radius = 340.0
			dash_iframe_timer = maxf(dash_iframe_timer, 1.0)
			var quake_dmg: int = base_dmg * 2 + 8
			for i in range(dummies.size()):
				if bool(dummies[i].get("alive", true)):
					dummies[i]["speed"] = float(dummies[i].get("speed", BASE_ENEMY_CHASE_SPEED)) * 0.65
					apply_damage_to_dummy(i, quake_dmg)
					targets_hit += 1
					total_aoe_damage += quake_dmg
			msg = "[ULTIMATE: %s] Arena Quake struck %d target(s) for %d dmg, slowed enemies -35%% & fortified 1.0s!" % [
				ult_name,
				targets_hit,
				quake_dmg
			]
		_:
			# Kaelen, Elf Ranger: Multi-Shot Volley (5-arrow spread fan at 135% damage)
			ult_vfx_radius = 160.0
			var base_dir := aim_dir.normalized() if aim_dir.length_squared() > 0.001 else Vector2.RIGHT
			var volley_dmg: int = int(round(float(base_dmg) * 1.35))
			var spread_angles := [-24.0, -12.0, 0.0, 12.0, 24.0]
			for deg in spread_angles:
				var dir := base_dir.rotated(deg_to_rad(deg))
				arrows.append({
					"pos": player_pos + dir * (PLAYER_RADIUS + 8.0),
					"vel": dir * (ARROW_SPEED * 1.15),
					"damage": volley_dmg,
					"ttl": 2.0
				})
				projectiles_spawned += 1
			msg = "[ULTIMATE: %s] Fired 5-Arrow Spread Volley (%d dmg per arrow, -%d MP)!" % [
				ult_name,
				volley_dmg,
				ULTIMATE_MANA_COST
			]

	_play_sfx("ultimate")
	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"status": "ultimate_cast",
		"ultimate_name": ult_name,
		"mana_spent": ULTIMATE_MANA_COST,
		"projectiles_spawned": projectiles_spawned,
		"targets_hit": targets_hit,
		"total_aoe_damage": total_aoe_damage,
		"message": msg
	}


## Spawns a projectile aimed toward target_world_pos.
func fire_arrow_at(target_world_pos: Vector2, allow_random_crit: bool = false) -> Dictionary:
	var dir := (target_world_pos - player_pos).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	aim_dir = dir

	var dmg := get_calculated_arrow_damage()
	var crit_rolled := roll_critical_hit(allow_random_crit)
	var projectile := {
		"pos": player_pos + dir * (PLAYER_RADIUS + 8.0),
		"vel": dir * ARROW_SPEED,
		"damage": dmg,
		"is_crit": crit_rolled,
		"ttl": 2.0
	}
	arrows.append(projectile)
	_play_sfx("shoot")
	_refresh_status_bar()
	queue_redraw()
	return projectile


## Applies damage to a target dummy by index (with Critical Hit 2x multiplier & Floating Combat Text) and handles Wave Survival progression.
func apply_damage_to_dummy(dummy_index: int, damage: int, is_crit: bool = false, allow_elemental_proc: bool = true) -> Dictionary:
	if dummy_index < 0 or dummy_index >= dummies.size():
		return {"error": "Invalid dummy index"}

	var dummy: Dictionary = dummies[dummy_index]
	if not bool(dummy.get("alive", true)):
		return {"status": "already_defeated"}

	var crit_active: bool = is_crit or force_next_crit
	if force_next_crit:
		force_next_crit = false
	var final_damage: int = damage * CRIT_DAMAGE_MULTIPLIER if crit_active else damage
	if crit_active:
		total_critical_hits += 1

	_play_sfx("hit")
	var d_pos: Vector2 = dummy.get("pos", Vector2(760.0, 200.0))
	if crit_active:
		spawn_particle_burst(d_pos, Color(1.0, 0.92, 0.25), 18, 1.35)
		trigger_screen_shake(0.42)
		spawn_floating_text(d_pos, "CRIT -%d!" % final_damage, Color(1.0, 0.92, 0.22), true)
	else:
		spawn_particle_burst(d_pos, dummy.get("color", Color(1.0, 0.68, 0.38)), 10, 1.0)
		trigger_screen_shake(0.14)
		spawn_floating_text(d_pos, "-%d" % final_damage, Color(1.0, 0.68, 0.38), false)

	var old_hp: int = int(dummy.get("hp", 1))
	var max_hp: int = int(dummy.get("max_hp", 1))
	var new_hp: int = old_hp - final_damage
	dummy["flash_timer"] = 0.18
	var atk_name := get_primary_attack_name()
	var crit_prefix := "[CRIT 2x!] " if crit_active else ""

	var msg: String = ""
	if new_hp <= 0:
		var is_boss_kill: bool = bool(dummy.get("is_boss", false))
		var score_mult: int = 300 if is_boss_kill else 100
		wave_score += score_mult * wave_number
		var gold_reward: int = BOSS_GOLD_REWARD if is_boss_kill else ENEMY_GOLD_REWARD
		spawn_coin_drop(d_pos, gold_reward, true)
		if is_boss_kill and loader != null and loader.has_method("grant_consumable_potion"):
			loader.grant_consumable_potion(1)
		if loader != null and loader.has_method("record_wave_progress"):
			loader.record_wave_progress(wave_number, wave_score)
		if wave_survival_active:
			dummy["hp"] = 0
			dummy["alive"] = false
			dummies[dummy_index] = dummy
			if _are_all_dummies_defeated():
				var c_key := get_room_key(current_room_coord)
				if dungeon_rooms.has(c_key):
					dungeon_rooms[c_key]["cleared"] = true
				var drop_pos: Vector2 = dummy.get("pos", Vector2(560.0, 350.0))
				spawn_relic_chest(drop_pos, (wave_number - 1) % 3)
				wave_number += 1
				if loader != null and loader.has_method("record_wave_progress"):
					loader.record_wave_progress(wave_number, wave_score)
				_init_dummies(wave_number)
				if loader != null:
					loader.modify_health(15)
					loader.modify_mana(10, true)
				var boss_tag := " [BOSS WAVE: Ashen Titan Spawned!]" if is_boss_wave() else ""
				msg = "%s[WAVE %d CLEARED!] Relic Chest Dropped! +15 HP & +10 MP — Wave %d Incoming (Score: %d)%s!" % [
					crit_prefix,
					wave_number - 1,
					wave_number,
					wave_score,
					boss_tag
				]
			else:
				msg = "%s[Enemy Defeated!] %s eliminated %s (+%d Score)!" % [
					crit_prefix,
					atk_name,
					str(dummy.get("name", "Enemy")),
					score_mult * wave_number
				]
		else:
			dummy["hp"] = max_hp
			dummies[dummy_index] = dummy
			msg = "%s[Arena Kill!] %s hit %s for %d dmg — Dummy defeated & respawned (%d/%d HP)!" % [
				crit_prefix,
				atk_name,
				str(dummy.get("name", "Dummy")),
				final_damage,
				max_hp,
				max_hp
			]
	else:
		dummy["hp"] = new_hp
		dummies[dummy_index] = dummy
		msg = "%s[Arena Hit] %s hit %s for %d dmg (%d/%d HP remaining)." % [
			crit_prefix,
			atk_name,
			str(dummy.get("name", "Dummy")),
			final_damage,
			new_hp,
			max_hp
		]
		if bool(dummy.get("is_boss", false)) and not bool(dummy.get("enraged", false)) and float(new_hp) <= float(max_hp) * BOSS_ENRAGE_HP_THRESHOLD:
			var enrage_res: Dictionary = check_and_trigger_boss_enrage(dummy_index, true)
			if enrage_res.get("status") == "boss_enraged":
				msg = str(enrage_res.get("message", msg))

	var elem_res: Dictionary = {}
	if allow_elemental_proc and elemental_stance != "none":
		elem_res = apply_elemental_infusion_on_hit(dummy_index, final_damage, true)

	if _combat_banner != null:
		_combat_banner.text = msg
	arena_combat_event.emit(msg)
	if loader != null:
		loader.character_updated.emit(loader.current_data, msg)
	_refresh_status_bar()
	queue_redraw()
	return {
		"dummy_name": dummy.get("name"),
		"damage": final_damage,
		"is_crit": crit_active,
		"elemental_proc": elem_res,
		"remaining_hp": dummies[dummy_index]["hp"] if dummy_index < dummies.size() else 0,
		"message": msg
	}


func _are_all_dummies_defeated() -> bool:
	for d in dummies:
		if bool(d.get("alive", true)):
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not arena_active:
		return

	if event is InputEventMouseMotion:
		var mouse_pos := get_global_mouse_position()
		var delta_vec := mouse_pos - player_pos
		if delta_vec.length_squared() > 1.0:
			aim_dir = delta_vec.normalized()
			queue_redraw()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			fire_arrow_at(get_global_mouse_position(), true)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			trigger_mana_dash(aim_dir)

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_SPACE:
				fire_arrow_at(player_pos + aim_dir * 200.0, true)
			elif ke.keycode == KEY_SHIFT:
				trigger_mana_dash()
			elif ke.keycode == KEY_F:
				trigger_arcane_parry()
			elif ke.keycode == KEY_Q:
				trigger_ultimate_ability()
			elif ke.keycode == KEY_E:
				collect_nearest_relic_chest(true)
			elif ke.keycode == KEY_C:
				trigger_use_potion()
			elif ke.keycode == KEY_M:
				_on_toggle_sfx_mute()
			elif ke.keycode == KEY_G:
				toggle_wave_survival()
			elif ke.keycode == KEY_P:
				toggle_ai_pilot()
			elif ke.keycode == KEY_N:
				enter_next_unexplored_room()
			elif ke.keycode == KEY_V:
				cycle_elemental_stance()
			elif ke.keycode == KEY_B:
				buy_merchant_upgrade()


func _process(delta: float) -> void:
	if not arena_active:
		return

	if door_cooldown_timer > 0.0:
		door_cooldown_timer = maxf(0.0, door_cooldown_timer - delta)
	if dash_iframe_timer > 0.0:
		dash_iframe_timer = maxf(0.0, dash_iframe_timer - delta)
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	if ultimate_cooldown_timer > 0.0:
		ultimate_cooldown_timer = maxf(0.0, ultimate_cooldown_timer - delta)
	if ult_vfx_timer > 0.0:
		ult_vfx_timer = maxf(0.0, ult_vfx_timer - delta)
	if parry_window_timer > 0.0:
		parry_window_timer = maxf(0.0, parry_window_timer - delta)
	if parry_cooldown_timer > 0.0:
		parry_cooldown_timer = maxf(0.0, parry_cooldown_timer - delta)
	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_count = 0
			_refresh_status_bar()

	# Passive Mana regeneration in the arena
	_mana_regen_accum += delta
	if _mana_regen_accum >= MANA_REGEN_INTERVAL:
		_mana_regen_accum -= MANA_REGEN_INTERVAL
		if loader != null and loader.has_method("modify_mana"):
			loader.modify_mana(MANA_REGEN_AMOUNT, true)
			_refresh_status_bar()

	# 1. Poll WASD / Arrow Keys for smooth 8-way movement
	var move_vec := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0

	if move_vec.length_squared() > 0.0:
		last_move_dir = move_vec.normalized()
		player_pos += last_move_dir * get_frenzy_move_speed() * delta
		var p_col := resolve_circle_obstacle_collision(player_pos, PLAYER_RADIUS)
		player_pos = p_col.get("pos", player_pos)
		player_pos.x = clampf(player_pos.x, ARENA_MIN_BOUNDS.x, ARENA_MAX_BOUNDS.x)
		player_pos.y = clampf(player_pos.y, ARENA_MIN_BOUNDS.y, ARENA_MAX_BOUNDS.y)
		check_door_transition()

	# Auto-pickup Relic Chests when walking within CHEST_PICKUP_RADIUS
	if not loot_chests.is_empty():
		collect_nearest_relic_chest(false)

	# Step Autonomous Tactical Utility AI Auto-Pilot when enabled ([P] key)
	if ai_pilot_active:
		step_ai_pilot(delta)

	# Step Environmental Hazard & Sanctuary Zones, Elemental Statuses, and Coin Drops
	step_hazard_zones(delta)
	step_elemental_statuses(delta)
	step_coin_drops(delta)

	# 2. Wave Survival Enemy AI Pursuit & Contact Check
	if wave_survival_active:
		step_wave_enemies(delta)

	# 3. Update active player & enemy projectiles and check collisions with Obsidian Pillars, dummies, and hero
	step_projectiles(delta)
	step_enemy_projectiles(delta)

	# 4. Step Floating Combat Text popups, Pixel-Spark Particles, and decay hit flash timers
	_anim_time += delta
	step_floating_texts(delta)
	step_particles(delta)
	for i in range(dummies.size()):
		var ft: float = float(dummies[i].get("flash_timer", 0.0))
		if ft > 0.0:
			dummies[i]["flash_timer"] = maxf(0.0, ft - delta)
	for i in range(obstacles.size()):
		var oft: float = float(obstacles[i].get("flash_timer", 0.0))
		if oft > 0.0:
			obstacles[i]["flash_timer"] = maxf(0.0, oft - delta)

	queue_redraw()


## Steps all active projectiles by delta, resolving Obsidian Pillar blocks and dummy impacts.
func step_projectiles(delta: float) -> int:
	var blocked_this_step: int = 0
	var remaining_arrows: Array[Dictionary] = []
	for arrow in arrows:
		arrow["pos"] += arrow["vel"] * delta
		arrow["ttl"] = float(arrow["ttl"]) - delta
		var pos: Vector2 = arrow["pos"]

		# Check Obsidian Pillar collision first
		var obs_idx: int = check_projectile_obstacle_hit(pos)
		if obs_idx >= 0:
			obstacle_blocks_count += 1
			blocked_this_step += 1
			obstacles[obs_idx]["flash_timer"] = 0.16
			spawn_floating_text(obstacles[obs_idx].get("pos", pos), "BLOCKED", Color(0.55, 0.88, 1.0), false)
			_play_sfx("hit")
			continue

		var hit_dummy := false
		for i in range(dummies.size()):
			if not bool(dummies[i].get("alive", true)):
				continue
			var d_pos: Vector2 = dummies[i]["pos"]
			var hit_rad: float = float(dummies[i].get("radius", DUMMY_RADIUS)) + 4.0
			if pos.distance_to(d_pos) <= hit_rad:
				register_combo_hit()
				apply_damage_to_dummy(i, int(arrow["damage"]), bool(arrow.get("is_crit", false)))
				hit_dummy = true
				break

		if not hit_dummy and float(arrow["ttl"]) > 0.0 and pos.x <= ARENA_MAX_BOUNDS.x + 40.0 and pos.x >= ARENA_MIN_BOUNDS.x - 40.0:
			remaining_arrows.append(arrow)

	arrows = remaining_arrows
	return blocked_this_step


## Advances alive enemy positions toward the player (with Obsidian Pillar collision & sliding) and checks contact hits.
func step_wave_enemies(delta: float) -> void:
	for i in range(dummies.size()):
		if not bool(dummies[i].get("alive", true)):
			continue
		var d_pos: Vector2 = dummies[i]["pos"]
		var d_rad: float = float(dummies[i].get("radius", DUMMY_RADIUS))
		var to_player := player_pos - d_pos
		var dist := to_player.length()
		if dist > 1.0:
			var spd: float = float(dummies[i].get("speed", BASE_ENEMY_CHASE_SPEED))
			if float(dummies[i].get("frost_timer", 0.0)) > 0.0:
				spd *= FROST_SLOW_MULTIPLIER
			var dir: Vector2 = to_player / dist
			var next_pos: Vector2 = d_pos + dir * spd * delta
			var col_res := resolve_circle_obstacle_collision(next_pos, d_rad)
			if bool(col_res.get("collided", false)):
				var pushed_pos: Vector2 = col_res.get("pos", next_pos)
				var slide_dir := Vector2(-dir.y, dir.x)
				if (player_pos - pushed_pos).dot(slide_dir) < 0.0:
					slide_dir = -slide_dir
				var slid_pos: Vector2 = pushed_pos + slide_dir * (spd * 0.55 * delta)
				d_pos = resolve_circle_obstacle_collision(slid_pos, d_rad).get("pos", pushed_pos)
			else:
				d_pos = next_pos
			dummies[i]["pos"] = d_pos
		if d_pos.distance_to(player_pos) <= CONTACT_HIT_DISTANCE and dash_iframe_timer <= 0.0:
			apply_enemy_contact_hit(str(dummies[i].get("name", "Enemy")))

	# Periodic Ranged Cinder Bolt / Boss 3-Bolt Fireball Volley during Wave Survival
	enemy_fire_timer += delta
	if enemy_fire_timer >= ENEMY_FIRE_INTERVAL:
		enemy_fire_timer -= ENEMY_FIRE_INTERVAL
		var shooter_idx: int = -1
		for i in range(dummies.size()):
			if bool(dummies[i].get("alive", true)) and bool(dummies[i].get("is_boss", false)):
				shooter_idx = i
				break
		if shooter_idx < 0:
			if dummies.size() > 1 and bool(dummies[1].get("alive", true)):
				shooter_idx = 1
			else:
				for i in range(dummies.size()):
					if bool(dummies[i].get("alive", true)):
						shooter_idx = i
						break
		if shooter_idx >= 0:
			fire_enemy_projectile_from(shooter_idx)


func _draw() -> void:
	if not arena_active:
		return

	if sprite_gen == null:
		sprite_gen = SpriteArtGeneratorScript.new()

	var anim_frame: int = int(floor(_anim_time * 5.0)) % 2
	var font := ThemeDB.fallback_font

	# 1. Tiled Cobblestone Dungeon Floor & Carved Stone Battlements
	var arena_rect := Rect2(
		ARENA_MIN_BOUNDS - Vector2(28, 28),
		(ARENA_MAX_BOUNDS - ARENA_MIN_BOUNDS) + Vector2(56, 56)
	)
	draw_rect(arena_rect.grow(10.0), Color(0.06, 0.08, 0.11, 1.0), true)
	var curr_room := get_current_room()
	var floor_tint: Color = curr_room.get("tint", Color.WHITE)
	var floor_tex: Texture2D = sprite_gen.get_prop_texture("floor_tile")
	if floor_tex != null:
		draw_texture_rect(floor_tex, arena_rect, true, floor_tint)
	else:
		draw_rect(arena_rect, Color(0.10, 0.13, 0.17, 1.0), true)

	var border_col := Color(0.88, 0.42, 0.32, 1.0) if wave_survival_active else Color(0.38, 0.50, 0.65, 1.0)
	draw_rect(arena_rect, border_col, false, 3.5)
	draw_rect(arena_rect.grow(6.0), Color(0.18, 0.22, 0.28, 0.95), false, 4.0)

	# 1B. Directional Stone Archway Doors (North, East, South, West)
	var doors_unlocked := are_room_doors_unlocked()
	var door_tex: Texture2D = sprite_gen.get_prop_texture("prop_door_open" if doors_unlocked else "prop_door_locked")
	var room_doors: Array = curr_room.get("doors", [])
	for d_dir in room_doors:
		var dir_str := str(d_dir)
		var d_pos := get_door_world_pos(dir_str)
		var target_coord := current_room_coord + get_door_offset(dir_str)
		var target_room: Dictionary = dungeon_rooms.get(get_room_key(target_coord), {})
		var target_name := str(target_room.get("name", "Chamber"))
		var aura_col := Color(0.28, 0.96, 0.85, 0.45 + sin(_anim_time * 7.0) * 0.15) if doors_unlocked else Color(0.92, 0.25, 0.25, 0.45)
		draw_circle(d_pos, 30.0, aura_col)
		if door_tex != null:
			draw_texture_rect(door_tex, Rect2(d_pos - Vector2(24, 20), Vector2(48, 40)), false)
		else:
			draw_rect(Rect2(d_pos - Vector2(20, 16), Vector2(40, 32)), aura_col, true)
		if font != null:
			var status_tag := "[%s] %s" % [dir_str, target_name] if doors_unlocked else "[%s LOCKED]" % dir_str
			var lbl_offset := Vector2(-58, -24) if dir_str != "N" else Vector2(-58, 34)
			draw_string(font, d_pos + lbl_offset, status_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 1.0, 0.92) if doors_unlocked else Color(1.0, 0.55, 0.55))

	# Flickering Corner & Wall Torch Sconces
	var torch_positions := [
		ARENA_MIN_BOUNDS + Vector2(-8, -8),
		Vector2(ARENA_MAX_BOUNDS.x + 8, ARENA_MIN_BOUNDS.y - 8),
		Vector2(ARENA_MIN_BOUNDS.x - 8, ARENA_MAX_BOUNDS.y + 8),
		ARENA_MAX_BOUNDS + Vector2(8, 8),
		Vector2(574.0, ARENA_MIN_BOUNDS.y - 14),
		Vector2(574.0, ARENA_MAX_BOUNDS.y + 14)
	]
	var flicker: float = 1.0 + sin(_anim_time * 12.0) * 0.12
	for t_pos in torch_positions:
		draw_circle(t_pos, 42.0 * flicker, Color(1.0, 0.55, 0.15, 0.10))
		draw_circle(t_pos, 18.0 * flicker, Color(1.0, 0.72, 0.22, 0.22))
		draw_circle(t_pos, 5.5, Color(1.0, 0.88, 0.38, 0.95))

	# 2. Environmental Hazard Zones (Bubbling Molten Cinder Pits & Crystal Sanctuary Shrine)
	for zone in hazard_zones:
		var z_pos: Vector2 = zone.get("pos", Vector2.ZERO)
		var z_rad: float = float(zone.get("radius", 45.0))
		var z_type: String = str(zone.get("type", ""))
		if z_type == "cinder_pit":
			draw_circle(z_pos, z_rad + 4.0, Color(0.18, 0.06, 0.04, 0.85))
			draw_circle(z_pos, z_rad, Color(0.68, 0.18, 0.06, 0.65))
			draw_circle(z_pos, z_rad * (0.65 + sin(_anim_time * 6.0) * 0.06), Color(0.98, 0.45, 0.10, 0.55))
			draw_arc(z_pos, z_rad, 0.0, TAU, 36, Color(1.0, 0.52, 0.14, 0.92), 2.8)
			if font != null:
				draw_string(font, z_pos + Vector2(-34, 4), "CINDER PIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.45, 0.95))
		elif z_type == "sanctuary":
			draw_circle(z_pos, z_rad + 4.0, Color(0.06, 0.22, 0.18, 0.75))
			draw_circle(z_pos, z_rad, Color(0.12, 0.52, 0.40, 0.45))
			draw_arc(z_pos, z_rad, 0.0, TAU, 36, Color(0.35, 0.98, 0.78, 0.92), 2.5)
			draw_arc(z_pos, z_rad * (0.58 + cos(_anim_time * 4.5) * 0.06), 0.0, TAU, 6, Color(0.55, 1.0, 0.88, 0.80), 2.0)
			if font != null:
				draw_string(font, z_pos + Vector2(-34, 4), "SANCTUARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 1.0, 0.88, 0.95))

	# 3. Carved Runic Obelisk Pillars (Pixel-Art Sprite + Shadow)
	var pillar_tex: Texture2D = sprite_gen.get_prop_texture("prop_pillar")
	for obs in obstacles:
		var o_pos: Vector2 = obs.get("pos", Vector2.ZERO)
		var o_rad: float = float(obs.get("radius", PILLAR_RADIUS))
		var o_flash: float = float(obs.get("flash_timer", 0.0))
		draw_circle(o_pos + Vector2(0, 10), o_rad * 0.95, Color(0.03, 0.04, 0.06, 0.55))
		if pillar_tex != null:
			var p_mod := Color(1.8, 2.0, 2.5, 1.0) if o_flash > 0.0 else Color.WHITE
			draw_texture_rect(pillar_tex, Rect2(o_pos - Vector2(34, 38), Vector2(68, 68)), false, p_mod)
		else:
			draw_circle(o_pos, o_rad, Color(0.22, 0.26, 0.34))
		var ring_col := Color(0.65, 0.92, 1.0, 0.95) if o_flash > 0.0 else Color(0.32, 0.65, 0.85, 0.45)
		draw_arc(o_pos, o_rad, 0.0, TAU, 32, ring_col, 2.0)

	# 4. Collectible Golden Treasure Chests (Pixel-Art Sprite + Shimmer)
	var chest_tex: Texture2D = sprite_gen.get_prop_texture("prop_chest")
	for chest in loot_chests:
		var c_pos: Vector2 = chest.get("pos", Vector2(560.0, 350.0))
		draw_circle(c_pos + Vector2(0, 8), 18.0, Color(0.03, 0.04, 0.06, 0.55))
		if chest_tex != null:
			draw_texture_rect(chest_tex, Rect2(c_pos - Vector2(20, 15), Vector2(40, 28)), false)
		else:
			draw_rect(Rect2(c_pos - Vector2(14, 11), Vector2(28, 22)), Color(0.95, 0.76, 0.22), true)
		draw_arc(c_pos, 22.0 + sin(_anim_time * 6.0) * 2.0, 0.0, TAU, 32, Color(1.0, 0.88, 0.32, 0.75), 2.0)
		if font != null:
			draw_string(font, c_pos + Vector2(-42, -18), "Relic Chest [E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.92, 0.45))

	# 4B. Hooded Dungeon Merchant NPC (Vaelor the Broker) & Magnetized Gold Coin Drops
	var merch_tex: Texture2D = sprite_gen.get_prop_texture("npc_merchant")
	draw_circle(MERCHANT_POS + Vector2(0, 14), 16.0, Color(0.03, 0.04, 0.06, 0.55))
	draw_arc(MERCHANT_POS, 26.0 + sin(_anim_time * 5.0) * 2.0, 0.0, TAU, 32, Color(0.98, 0.82, 0.25, 0.65), 2.0)
	if merch_tex != null:
		draw_texture_rect(merch_tex, Rect2(MERCHANT_POS - Vector2(22, 24), Vector2(44, 44)), false)
	if font != null:
		draw_string(font, MERCHANT_POS + Vector2(-62, -28), "Vaelor [B: Shop | %dg]" % gold_coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.90, 0.38))

	var coin_tex: Texture2D = sprite_gen.get_prop_texture("prop_coin")
	for coin in coin_drops:
		var cn_pos: Vector2 = coin.get("pos", Vector2.ZERO)
		if coin_tex != null:
			draw_texture_rect(coin_tex, Rect2(cn_pos - Vector2(9, 9), Vector2(18, 18)), false)
		else:
			draw_circle(cn_pos, 6.0, Color(1.0, 0.88, 0.22))

	# 5. Active Hero Pixel-Art Character Sprite, Shadow, Auras & Held Weapon Sprite
	var hero_color := Color(0.28, 0.78, 0.48)
	var cid := "char_001"
	if loader != null:
		if loader.has_method("get_current_hero_accent"):
			hero_color = loader.get_current_hero_accent()
		if not loader.current_data.is_empty():
			cid = str(loader.current_data.get("character_id", "char_001"))

	if ult_vfx_timer > 0.0:
		var pulse_ratio := 1.0 - (ult_vfx_timer / 0.55)
		var ring_rad := lerpf(32.0, ult_vfx_radius, pulse_ratio)
		draw_arc(player_pos, ring_rad, 0.0, TAU, 48, hero_color.lightened(0.45), 4.0)

	# Ground Shadow under Hero
	draw_circle(player_pos + Vector2(0, 14), 16.0, Color(0.02, 0.03, 0.05, 0.58))

	# Hero 2-Frame Pixel-Art Sprite (with directional horizontal flip)
	var hero_tex: Texture2D = sprite_gen.get_hero_texture(cid, anim_frame)
	var bob_y: float = sin(_anim_time * 10.0) * 1.5
	var flip_h: bool = aim_dir.x < -0.05
	if hero_tex != null:
		var h_size := Vector2(46.0 if not flip_h else -46.0, 46.0)
		draw_texture_rect(hero_tex, Rect2(player_pos + Vector2(-23.0, -25.0 + bob_y), h_size), false)
	else:
		draw_circle(player_pos, PLAYER_RADIUS, hero_color)

	# Held Class Weapon Pixel-Art Sprite Orbiting Toward Aim Direction
	var wpn_tex: Texture2D = sprite_gen.get_weapon_texture(cid)
	var wpn_pos: Vector2 = player_pos + aim_dir * 22.0
	if wpn_tex != null:
		var w_size := Vector2(24.0 if not flip_h else -24.0, 24.0)
		var w_mod := get_elemental_stance_color() if elemental_stance != "none" else Color.WHITE
		draw_texture_rect(wpn_tex, Rect2(wpn_pos - Vector2(12.0, 12.0), w_size), false, w_mod)

	# Dash Invulnerability Aura Ring
	if dash_iframe_timer > 0.0:
		draw_arc(player_pos, PLAYER_RADIUS + 9.0, 0.0, TAU, 36, Color(0.42, 0.95, 1.0, 0.9), 3.0)

	# Arcane Parry Reflect Shield Ring ([F] key)
	if parry_window_timer > 0.0:
		draw_arc(player_pos, PARRY_REFLECT_RADIUS * 0.65, 0.0, TAU, 6, Color(1.0, 0.95, 0.38, 0.95), 3.5)
		draw_arc(player_pos, PARRY_REFLECT_RADIUS * 0.85, 0.0, TAU, 36, Color(0.45, 0.98, 1.0, 0.75), 2.0)

	# Frenzy Aura Ring when Combo >= 3
	if is_frenzy_active():
		draw_arc(player_pos, PLAYER_RADIUS + 14.0, 0.0, TAU, 36, Color(1.0, 0.72, 0.18, 0.85), 2.5)

	# AI Auto-Pilot Targeting Laser & Aura ([P] key)
	if ai_pilot_active:
		draw_arc(player_pos, PLAYER_RADIUS + 18.0, 0.0, TAU, 24, Color(0.35, 0.98, 0.85, 0.8), 2.0)
		draw_line(player_pos, player_pos + aim_dir * 260.0, Color(0.35, 0.98, 0.85, 0.28), 1.5)

	# Overhead Player HP & MP mini-bars
	if loader != null and not loader.current_data.is_empty():
		var h_dict: Dictionary = loader.current_data.get("health", {"current": 45, "max": 45})
		var m_dict: Dictionary = loader.current_data.get("mana", {"current": 20, "max": 20})
		var hp_r := clampf(float(h_dict.get("current", 1)) / float(maxi(1, int(h_dict.get("max", 1)))), 0.0, 1.0)
		var mp_r := clampf(float(m_dict.get("current", 1)) / float(maxi(1, int(m_dict.get("max", 1)))), 0.0, 1.0)
		var p_bar_origin := player_pos + Vector2(-30, -42)
		draw_rect(Rect2(p_bar_origin, Vector2(60, 6)), Color(0.12, 0.12, 0.16), true)
		draw_rect(Rect2(p_bar_origin, Vector2(60.0 * hp_r, 6)), Color(0.38, 0.92, 0.48), true)
		draw_rect(Rect2(p_bar_origin + Vector2(0, 7), Vector2(60, 5)), Color(0.12, 0.12, 0.16), true)
		draw_rect(Rect2(p_bar_origin + Vector2(0, 7), Vector2(60.0 * mp_r, 5)), Color(0.42, 0.75, 0.98), true)

	if font != null:
		var char_name := "Kaelen"
		if loader != null and not loader.current_data.is_empty():
			char_name = "%s (Lv.%d)" % [
				str(loader.current_data.get("name", "Kaelen")),
				int(loader.current_data.get("level", 5))
			]
		draw_string(font, player_pos + Vector2(-58, -48), char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.95, 0.95))
		var cover_blocked := count_enemies_blocked_by_cover()
		if cover_blocked > 0:
			draw_string(font, player_pos + Vector2(-42, -64), "[COVER x%d]" % cover_blocked, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.92, 1.0))
		if combo_count >= 2:
			var combo_tag := "[FRENZY %dx — %d HITS!]" % [get_combo_multiplier(), combo_count] if is_frenzy_active() else "[COMBO x%d]" % combo_count
			draw_string(font, player_pos + Vector2(-48, -78), combo_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.22) if is_frenzy_active() else Color(0.95, 0.78, 0.45))
		if ai_pilot_active:
			draw_string(font, player_pos + Vector2(-46, -92), "[AI AUTO-PILOT: %s]" % ai_last_action.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.35, 0.98, 0.85))
		if elemental_stance != "none":
			draw_string(font, player_pos + Vector2(-48, -106), "[INFUSION: %s]" % elemental_stance.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, get_elemental_stance_color())

	# 6. Animated Pixel-Art Monsters & Towering Boss Sprites
	for dummy in dummies:
		if not bool(dummy.get("alive", true)):
			continue
		var d_pos: Vector2 = dummy["pos"]
		var d_rad: float = float(dummy.get("radius", DUMMY_RADIUS))
		var is_boss: bool = bool(dummy.get("is_boss", false))
		var is_enraged: bool = bool(dummy.get("enraged", false))
		var is_summon: bool = bool(dummy.get("is_summon", false))
		var flash: float = float(dummy.get("flash_timer", 0.0))
		var d_name: String = str(dummy.get("name", "Enemy"))

		# Ground Shadow & Boss Molten Aura
		draw_circle(d_pos + Vector2(0, d_rad * 0.55), d_rad * 0.75, Color(0.02, 0.03, 0.05, 0.58))
		if is_boss:
			var aura_col := Color(1.0, 0.25, 0.12, 0.92) if is_enraged else Color(1.0, 0.65, 0.15, 0.85)
			draw_arc(d_pos, d_rad + 8.0 + sin(_anim_time * 8.0) * 2.0, 0.0, TAU, 40, aura_col, 3.5 if is_enraged else 3.0)
			if is_enraged:
				draw_arc(d_pos, d_rad + 16.0 + cos(_anim_time * 12.0) * 3.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.22, 0.75), 2.5)

		var enemy_tex: Texture2D = sprite_gen.get_enemy_texture(d_name, is_boss, anim_frame)
		var face_left: bool = player_pos.x < d_pos.x
		var spr_dim: float = (94.0 if is_enraged else 84.0) if is_boss else (38.0 if is_summon else 48.0)
		var base_mod := Color(1.35, 0.78, 0.68, 1.0) if is_enraged else (Color(1.25, 0.85, 0.55, 1.0) if is_summon else Color.WHITE)
		var mod_col: Color = Color(2.5, 2.5, 2.5, 1.0) if flash > 0.0 else base_mod
		if enemy_tex != null:
			var e_size := Vector2(-spr_dim if face_left else spr_dim, spr_dim)
			draw_texture_rect(enemy_tex, Rect2(d_pos - Vector2(spr_dim * 0.5, spr_dim * 0.52), e_size), false, mod_col)
		else:
			draw_circle(d_pos, d_rad, dummy["color"])

		# Enemy Overhead HP Bar
		var hp_ratio := clampf(float(dummy["hp"]) / float(maxi(1, int(dummy["max_hp"]))), 0.0, 1.0)
		var bar_w := 104.0 if is_boss else (54.0 if is_summon else 72.0)
		var bar_pos := d_pos + Vector2(-bar_w * 0.5, -d_rad - 20.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 8)), Color(0.12, 0.12, 0.16), true)
		var hp_col := (Color(1.0, 0.28, 0.18) if is_enraged else Color(0.98, 0.72, 0.22)) if is_boss else Color(0.92, 0.35, 0.35)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, 8)), hp_col, true)

		if font != null:
			var enrage_tag := " [PHASE 2: ENRAGED]" if is_enraged else ""
			var status_tags := ""
			if float(dummy.get("frost_timer", 0.0)) > 0.0:
				status_tags += " [FROST]"
				draw_arc(d_pos, d_rad + 4.0, 0.0, TAU, 24, Color(0.38, 0.92, 1.0, 0.85), 2.0)
			if float(dummy.get("burn_timer", 0.0)) > 0.0 and int(dummy.get("burn_stacks", 0)) > 0:
				status_tags += " [BURN x%d]" % int(dummy.get("burn_stacks", 1))
				draw_arc(d_pos, d_rad + 6.0, 0.0, TAU, 24, Color(1.0, 0.48, 0.14, 0.85), 2.0)
			var label_str := "%s%s%s (%d/%d)" % [d_name, enrage_tag, status_tags, int(dummy["hp"]), int(dummy["max_hp"])]
			draw_string(font, d_pos + Vector2(-68, -d_rad - 26.0), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.55, 0.38) if is_enraged else Color(0.98, 0.92, 0.78))

	# 6B. Crackling Jagged Stormchain Lightning Arcs
	for arc in lightning_arcs:
		var p_from: Vector2 = arc.get("from", Vector2.ZERO)
		var p_to: Vector2 = arc.get("to", Vector2.ZERO)
		var seg := (p_to - p_from) * 0.25
		var perp := Vector2(-seg.y, seg.x).normalized() * 12.0
		var p1 := p_from + seg + perp
		var p2 := p_from + seg * 2.0 - perp
		var p3 := p_from + seg * 3.0 + perp * 0.7
		var l_col := Color(0.48, 0.96, 1.0, 0.95)
		draw_line(p_from, p1, l_col, 3.2)
		draw_line(p1, p2, Color.WHITE, 2.6)
		draw_line(p2, p3, l_col, 3.2)
		draw_line(p3, p_to, Color.WHITE, 2.6)

	# 7. Active Player Projectiles (Glowing Fletched Bolts / Daggers)
	for arrow in arrows:
		var a_pos: Vector2 = arrow["pos"]
		var a_dir: Vector2 = (arrow["vel"] as Vector2).normalized()
		var is_c: bool = bool(arrow.get("is_crit", false))
		var proj_col: Color = Color(1.0, 0.92, 0.25) if is_c else hero_color.lightened(0.35)
		var proj_w: float = 4.8 if is_c else 3.5
		draw_line(a_pos - a_dir * 14.0, a_pos + a_dir * 10.0, proj_col, proj_w)
		draw_circle(a_pos + a_dir * 10.0, 3.2 if is_c else 2.2, Color.WHITE)

	# 8. Active Enemy Cinder Bolts & Boss Fireballs
	for bolt in enemy_projectiles:
		var b_pos: Vector2 = bolt["pos"]
		var b_dir: Vector2 = (bolt["vel"] as Vector2).normalized()
		var b_rad: float = float(bolt.get("radius", 6.0))
		var is_boss_fb: bool = bool(bolt.get("is_boss_fireball", false))
		var outer_col := Color(1.0, 0.45, 0.12, 0.95) if is_boss_fb else Color(0.95, 0.22, 0.38, 0.95)
		var core_col := Color(1.0, 0.92, 0.45) if is_boss_fb else Color(1.0, 0.65, 0.75)
		draw_line(b_pos - b_dir * 16.0, b_pos, outer_col, b_rad * 0.85)
		draw_circle(b_pos, b_rad, outer_col)
		draw_circle(b_pos, b_rad * 0.48, core_col)

	# 9. Directional Pixel-Spark Particle Bursts
	for p in particles:
		var p_pos: Vector2 = p.get("pos", Vector2.ZERO)
		var p_col: Color = p.get("color", Color.WHITE)
		var p_size: float = float(p.get("size", 4.0))
		var p_alpha: float = clampf(float(p.get("ttl", 0.2)) / maxf(0.01, float(p.get("max_ttl", 0.4))), 0.0, 1.0)
		draw_rect(Rect2(p_pos - Vector2(p_size * 0.5, p_size * 0.5), Vector2(p_size, p_size)), Color(p_col.r, p_col.g, p_col.b, p_alpha), true)

	# 10. Rising & Fading Floating Combat Text Popups
	if font != null:
		for ft in floating_texts:
			var f_pos: Vector2 = ft.get("pos", Vector2.ZERO)
			var f_text: String = str(ft.get("text", ""))
			var f_col: Color = ft.get("color", Color.WHITE)
			var f_crit: bool = bool(ft.get("is_crit", false))
			var alpha: float = clampf(float(ft.get("ttl", 0.5)) / maxf(0.01, float(ft.get("max_ttl", 0.75))), 0.0, 1.0)
			var draw_col := Color(f_col.r, f_col.g, f_col.b, alpha)
			var shadow_col := Color(0.05, 0.05, 0.08, alpha * 0.85)
			var f_size: int = 16 if f_crit else 13
			draw_string(font, f_pos + Vector2(-26, 1), f_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, shadow_col)
			draw_string(font, f_pos + Vector2(-27, 0), f_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, draw_col)

	# 11. Live Top-Right Dungeon Minimap Overlay
	_draw_dungeon_minimap(font)


func _draw_dungeon_minimap(font: Font) -> void:
	var map_rect := Rect2(Vector2(936.0, 102.0), Vector2(156.0, 124.0))
	draw_rect(map_rect, Color(0.05, 0.07, 0.10, 0.88), true)
	draw_rect(map_rect, Color(0.38, 0.55, 0.72, 0.92), false, 2.0)

	var center := map_rect.position + Vector2(78.0, 68.0)
	var cell_step := 28.0
	var cell_size := Vector2(20.0, 16.0)

	# Draw connecting corridors from (0,0)
	for key in dungeon_rooms.keys():
		var r: Dictionary = dungeon_rooms[key]
		var c: Vector2i = r.get("coord", Vector2i.ZERO)
		if c != Vector2i.ZERO:
			var p_from := center
			var p_to := center + Vector2(c.x * cell_step, c.y * cell_step)
			draw_line(p_from, p_to, Color(0.35, 0.45, 0.58, 0.85), 3.0)

	# Draw each room cell
	for key in dungeon_rooms.keys():
		var r: Dictionary = dungeon_rooms[key]
		var c: Vector2i = r.get("coord", Vector2i.ZERO)
		var visited: bool = bool(r.get("visited", false))
		var r_type: String = str(r.get("type", "skirmish"))
		var c_pos := center + Vector2(c.x * cell_step, c.y * cell_step) - cell_size * 0.5
		var c_rect := Rect2(c_pos, cell_size)

		var fill_col := Color(0.16, 0.20, 0.26, 0.90)
		if c == current_room_coord:
			fill_col = Color(0.28, 0.88, 0.58, 0.98)
		elif visited:
			match r_type:
				"boss":
					fill_col = Color(0.88, 0.28, 0.25, 0.95)
				"treasure":
					fill_col = Color(0.92, 0.76, 0.22, 0.95)
				"sanctuary":
					fill_col = Color(0.25, 0.78, 0.88, 0.95)
				_:
					fill_col = Color(0.42, 0.52, 0.68, 0.95)

		draw_rect(c_rect, fill_col, true)
		draw_rect(c_rect, Color(0.85, 0.92, 1.0, 0.95) if c == current_room_coord else Color(0.28, 0.36, 0.46, 0.9), false, 1.5)

		if font != null:
			var icon := "?"
			if c == current_room_coord:
				icon = "★"
			elif r_type == "boss":
				icon = "B"
			elif r_type == "treasure":
				icon = "$"
			elif r_type == "sanctuary":
				icon = "+"
			elif visited:
				icon = "•"
			draw_string(font, c_pos + Vector2(5, 12), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.06, 0.08, 0.10) if c == current_room_coord else Color(0.95, 0.95, 0.98))

	if font != null:
		var curr_name := str(get_current_room().get("name", "Crypt Entry Hall"))
		draw_string(font, map_rect.position + Vector2(8, 15), "MAP (%d/%d): %s" % [rooms_explored_count, dungeon_rooms.size(), curr_name.substr(0, 14)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.88, 0.62))
		draw_string(font, map_rect.position + Vector2(8, 118), "[N] or Walk to Door", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.88, 0.95))


func _refresh_status_bar() -> void:
	if _status_label == null:
		return
	var char_name := "Kaelen"
	var level := 5
	var hp_str := "45/45"
	var mp_str := "20/20"
	if loader != null and not loader.current_data.is_empty():
		char_name = str(loader.current_data.get("name", "Kaelen"))
		level = int(loader.current_data.get("level", 5))
		var h: Dictionary = loader.current_data.get("health", {})
		var m: Dictionary = loader.current_data.get("mana", {})
		hp_str = "%d/%d" % [int(h.get("current", 0)), int(h.get("max", 0))]
		mp_str = "%d/%d" % [int(m.get("current", 0)), int(m.get("max", 0))]

	var boss_suffix := " [BOSS]" if (wave_survival_active and is_boss_wave()) else ""
	var room_name := str(get_current_room().get("name", "Crypt Entry Hall"))
	var mode_tag := "WAVE %d%s (Score: %d)" % [wave_number, boss_suffix, wave_score] if wave_survival_active else "PRACTICE"
	var crit_pct := int(round(get_calculated_crit_chance() * 100.0))
	_status_label.text = (
		"[%s | %s (%d/%d)] %s (Lv.%d) | HP: %s | MP: %s | Gold: %dg | %s: %d Dmg (Crit: %d%%) | [B]: Shop"
		% [
			mode_tag,
			room_name,
			rooms_explored_count,
			dungeon_rooms.size(),
			char_name,
			level,
			hp_str,
			mp_str,
			gold_coins,
			get_primary_attack_name(),
			get_calculated_arrow_damage(),
			crit_pct
		]
	)


func _on_character_data_changed(_data: Dictionary) -> void:
	_refresh_status_bar()
	queue_redraw()


func _on_character_updated(_data: Dictionary, _msg: String) -> void:
	_refresh_status_bar()
	queue_redraw()


func _on_arena_level_up() -> void:
	if loader != null:
		loader.apply_level_up()
		_play_sfx("level_up")
		_refresh_status_bar()


func _on_toggle_sfx_mute() -> void:
	if sfx_node == null and get_parent() != null:
		sfx_node = get_parent().get_node_or_null("ProceduralSfx")
	if sfx_node != null and sfx_node.has_method("toggle_mute"):
		var is_muted: bool = sfx_node.toggle_mute()
		if _sfx_btn != null:
			_sfx_btn.text = "SFX: OFF [M]" if is_muted else "SFX: ON [M]"
