# godot_project/scripts/command_center_receiver.gd
# Bi-directional loopback UDP telemetry broadcaster and live RPC command receiver on port 4242.
# Connects to: godot_project/scripts/character_loader.gd, godot_project/scripts/character_sheet_hud.gd, godot_project/scripts/arena_controller.gd
# Created: 2026-10-24

extends Node
class_name CommandCenterReceiver

## Emitted whenever a structured RPC command is received and executed.
signal remote_command_executed(command_name: String, result: Dictionary)

## Emitted when the UDP socket starts or stops listening.
signal connection_state_changed(is_listening: bool, bound_port: int)

const DEFAULT_LISTEN_PORT: int = 4242
const DEFAULT_TELEMETRY_PORT: int = 4243
const LOOPBACK_HOST: String = "127.0.0.1"

@export var listen_port: int = DEFAULT_LISTEN_PORT
@export var telemetry_port: int = DEFAULT_TELEMETRY_PORT
@export var auto_start: bool = true

var loader: Node = null
var hud: Node = null
var arena: Node = null
var sfx_node: Node = null

var _udp: PacketPeerUDP = PacketPeerUDP.new()
var _is_listening: bool = false
var _bound_port: int = -1


func _ready() -> void:
	_bind_sibling_nodes()
	if auto_start:
		start_listening(listen_port)


func _exit_tree() -> void:
	stop_listening()


func _bind_sibling_nodes() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent.has_method("load_character_data"):
		loader = parent
		if not loader.character_updated.is_connected(_on_character_updated):
			loader.character_updated.connect(_on_character_updated)
	hud = parent.get_node_or_null("CharacterSheetHUD")
	arena = parent.get_node_or_null("Arena")
	sfx_node = parent.get_node_or_null("ProceduralSfx")


## Binds the loopback UDP listener on the requested port (or fallback port if busy).
func start_listening(port: int = DEFAULT_LISTEN_PORT) -> Error:
	if _is_listening:
		stop_listening()

	var err := _udp.bind(port, LOOPBACK_HOST)
	if err != OK:
		# Fallback to any available ephemeral port if 4242 is already in use by another instance
		err = _udp.bind(0, LOOPBACK_HOST)
		if err != OK:
			return err
		_bound_port = _udp.get_local_port()
	else:
		_bound_port = port

	_is_listening = true
	connection_state_changed.emit(true, _bound_port)
	return OK


## Closes the UDP listener socket.
func stop_listening() -> void:
	if _is_listening:
		_udp.close()
		_is_listening = false
		_bound_port = -1
		connection_state_changed.emit(false, -1)


## Returns true if the UDP socket is bound and listening.
func is_listening() -> bool:
	return _is_listening


## Returns the actual bound local UDP port.
func get_bound_port() -> int:
	return _bound_port


## Poll incoming UDP datagrams each frame and execute structured JSON RPC commands.
func _process(_delta: float) -> void:
	if not _is_listening:
		return
	poll_packets()


## Reads all queued UDP packets, executes commands, and sends JSON ACK packets back to sender.
func poll_packets() -> int:
	var processed_count: int = 0
	while _udp.get_available_packet_count() > 0:
		var raw_bytes := _udp.get_packet()
		var sender_ip := _udp.get_packet_ip()
		var sender_port := _udp.get_packet_port()
		var text := raw_bytes.get_string_from_utf8().strip_edges()
		if text.is_empty():
			continue

		var json := JSON.new()
		if json.parse(text) != OK or not (json.data is Dictionary):
			continue

		var packet_dict: Dictionary = json.data
		var cmd_name: String = str(packet_dict.get("command", packet_dict.get("event", "")))
		var payload: Dictionary = packet_dict.get("payload", {}) if (packet_dict.get("payload") is Dictionary) else {}

		var response := execute_remote_command(cmd_name, payload)
		processed_count += 1

		if not sender_ip.is_empty() and sender_port > 0:
			_send_udp_json(response, sender_ip, sender_port)
	return processed_count


## Executes a named remote command against the live Godot runtime and returns a telemetry snapshot.
func execute_remote_command(command_name: String, payload: Dictionary = {}) -> Dictionary:
	_bind_sibling_nodes()
	var cmd := command_name.to_lower().strip_edges()
	var action_note := "Executed '%s'" % cmd

	match cmd:
		"level_up":
			if loader != null:
				loader.apply_level_up()
				action_note = "Remote RPC triggered Level Up"
		"select_hero":
			if loader != null:
				var slot_idx: int = int(payload.get("slot", payload.get("index", 1))) - 1
				loader.select_roster_character(clampi(slot_idx, 0, 3))
				action_note = "Remote RPC switched hero to slot %d" % (slot_idx + 1)
		"heal":
			if loader != null:
				var amount: int = abs(int(payload.get("amount", 15)))
				loader.modify_health(amount)
				action_note = "Remote RPC healed +%d HP" % amount
		"damage":
			if loader != null:
				var amount: int = abs(int(payload.get("amount", 10)))
				loader.modify_health(-amount)
				action_note = "Remote RPC dealt -%d HP" % amount
		"roll_skill":
			if loader != null:
				var sk_idx: int = int(payload.get("skill_index", 0))
				loader.roll_skill_check(sk_idx)
				action_note = "Remote RPC rolled skill index %d" % sk_idx
		"toggle_arena":
			if hud != null and hud.has_method("toggle_arena_mode"):
				hud.toggle_arena_mode()
				action_note = "Remote RPC toggled 2D Arena mode"
		"toggle_wave":
			if arena != null and arena.has_method("toggle_wave_survival"):
				arena.toggle_wave_survival()
				action_note = "Remote RPC toggled Wave Survival mode"
		"mana_dash":
			if arena != null and arena.has_method("trigger_mana_dash"):
				arena.trigger_mana_dash()
				action_note = "Remote RPC triggered Mana Dash"
		"trigger_ultimate":
			if arena != null and arena.has_method("trigger_ultimate_ability"):
				arena.trigger_ultimate_ability()
				action_note = "Remote RPC triggered Class Ultimate Ability"
		"loot_relic":
			if arena != null and arena.has_method("collect_nearest_relic_chest"):
				arena.collect_nearest_relic_chest(true)
				action_note = "Remote RPC collected nearest Relic Chest"
		"use_potion":
			if arena != null and arena.has_method("trigger_use_potion"):
				arena.trigger_use_potion()
				action_note = "Remote RPC used consumable potion"
		"force_crit":
			if arena != null:
				arena.force_next_crit = true
				action_note = "Remote RPC armed guaranteed 2x Critical Hit for next attack"
		"enemy_fire":
			if arena != null and arena.has_method("fire_enemy_projectile_from"):
				var d_idx: int = int(payload.get("dummy_index", 1))
				arena.fire_enemy_projectile_from(d_idx)
				action_note = "Remote RPC triggered enemy projectile from dummy %d" % d_idx
		"trigger_parry":
			if arena != null and arena.has_method("trigger_arcane_parry"):
				arena.trigger_arcane_parry()
				action_note = "Remote RPC triggered Arcane Parry reflect shield"
		"toggle_ai_pilot":
			if arena != null and arena.has_method("toggle_ai_pilot"):
				var ai_state: bool = arena.toggle_ai_pilot()
				action_note = "Remote RPC toggled Tactical AI Auto-Pilot -> %s" % str(ai_state)
		"step_ai_pilot":
			if arena != null and arena.has_method("step_ai_pilot"):
				var dt: float = float(payload.get("delta", 0.4))
				arena.step_ai_pilot(dt)
				action_note = "Remote RPC stepped Tactical AI Auto-Pilot (delta=%.2fs)" % dt
		"enter_door":
			if arena != null and arena.has_method("enter_dungeon_door"):
				var door_dir: String = str(payload.get("direction", "E"))
				var force_open: bool = bool(payload.get("force_unlock", true))
				var d_res: Dictionary = arena.enter_dungeon_door(door_dir, force_open)
				action_note = "Remote RPC entered door '%s' -> %s" % [door_dir, str(d_res.get("room_name", "Room"))]
		"next_room":
			if arena != null and arena.has_method("enter_next_unexplored_room"):
				var nr_res: Dictionary = arena.enter_next_unexplored_room()
				action_note = "Remote RPC entered next room -> %s" % str(nr_res.get("room_name", "Room"))
		"trigger_boss_enrage":
			if arena != null and arena.has_method("check_and_trigger_boss_enrage"):
				var b_idx: int = int(payload.get("boss_index", -1))
				var e_res: Dictionary = arena.check_and_trigger_boss_enrage(b_idx, true)
				action_note = "Remote RPC triggered Boss Phase 2 Molten Enrage -> %s" % str(e_res.get("status", "ok"))
		"cycle_stance":
			if arena != null and arena.has_method("cycle_elemental_stance"):
				var target_st: String = str(payload.get("stance", ""))
				var st_res: Dictionary = arena.cycle_elemental_stance(target_st)
				action_note = "Remote RPC cycled Elemental Infusion Stance -> %s" % str(st_res.get("elemental_stance", "none"))
		"toggle_mute":
			if sfx_node != null and sfx_node.has_method("toggle_mute"):
				var muted_now: bool = sfx_node.toggle_mute()
				action_note = "Remote RPC toggled SFX mute -> %s" % str(muted_now)
		"play_sfx":
			if sfx_node != null and sfx_node.has_method("play_cue"):
				var cue_str: String = str(payload.get("cue", "shoot"))
				sfx_node.play_cue(cue_str)
				action_note = "Remote RPC played SFX cue '%s'" % cue_str
		"save_party":
			if loader != null and loader.has_method("save_party_progression"):
				loader.save_party_progression()
				action_note = "Remote RPC saved party progression to user://roster_save.json"
		"load_party":
			if loader != null and loader.has_method("load_party_progression"):
				loader.load_party_progression()
				action_note = "Remote RPC loaded party progression from user://roster_save.json"
		"get_state", "ping":
			action_note = "Telemetry snapshot requested"
		_:
			return {
				"status": "error",
				"error": "Unknown command '%s'" % command_name,
				"snapshot": build_telemetry_snapshot()
			}

	var result := {
		"status": "ok",
		"command": cmd,
		"note": action_note,
		"snapshot": build_telemetry_snapshot()
	}
	remote_command_executed.emit(cmd, result)
	return result


## Builds a structured JSON-serializable telemetry dictionary of the current hero and arena state.
func build_telemetry_snapshot() -> Dictionary:
	var char_data: Dictionary = loader.current_data if loader != null else {}
	var health: Dictionary = char_data.get("health", {})
	var mana: Dictionary = char_data.get("mana", {})
	return {
		"character_id": str(char_data.get("character_id", "")),
		"name": str(char_data.get("name", "")),
		"character_class": str(char_data.get("character_class", "")),
		"level": int(char_data.get("level", 1)),
		"hp_current": int(health.get("current", 0)),
		"hp_max": int(health.get("max", 0)),
		"mp_current": int(mana.get("current", 0)),
		"mp_max": int(mana.get("max", 0)),
		"arena_active": bool(arena.arena_active) if arena != null else false,
		"wave_survival_active": bool(arena.wave_survival_active) if arena != null else false,
		"wave_number": int(arena.wave_number) if arena != null else 1,
		"wave_score": int(arena.wave_score) if arena != null else 0,
		"is_boss_wave": bool(arena.is_boss_wave()) if (arena != null and arena.has_method("is_boss_wave")) else false,
		"ultimate_ability": str(arena.get_ultimate_ability_name()) if (arena != null and arena.has_method("get_ultimate_ability_name")) else "",
		"relic_bonuses": loader.get_inventory_bonuses() if (loader != null and loader.has_method("get_inventory_bonuses")) else {},
		"consumables_remaining": loader.get_consumable_count() if (loader != null and loader.has_method("get_consumable_count")) else 0,
		"obstacle_count": arena.obstacles.size() if arena != null else 0,
		"obstacle_blocks_count": int(arena.obstacle_blocks_count) if arena != null else 0,
		"enemies_blocked_by_cover": arena.count_enemies_blocked_by_cover() if (arena != null and arena.has_method("count_enemies_blocked_by_cover")) else 0,
		"crit_chance_pct": int(round(arena.get_calculated_crit_chance() * 100.0)) if (arena != null and arena.has_method("get_calculated_crit_chance")) else 8,
		"total_critical_hits": int(arena.total_critical_hits) if arena != null else 0,
		"total_floating_texts_spawned": int(arena.total_floating_texts_spawned) if arena != null else 0,
		"enemy_projectiles_active": arena.enemy_projectiles.size() if arena != null else 0,
		"enemy_projectiles_spawned_total": int(arena.enemy_projectiles_spawned_total) if arena != null else 0,
		"enemy_projectiles_blocked_by_cover": int(arena.enemy_projectiles_blocked_by_cover) if arena != null else 0,
		"total_projectiles_parried": int(arena.total_projectiles_parried) if arena != null else 0,
		"combo_count": int(arena.combo_count) if arena != null else 0,
		"max_combo_reached": int(arena.max_combo_reached) if arena != null else 0,
		"frenzy_active": bool(arena.is_frenzy_active()) if (arena != null and arena.has_method("is_frenzy_active")) else false,
		"total_hazard_burn_ticks": int(arena.total_hazard_burn_ticks) if arena != null else 0,
		"total_sanctuary_ticks": int(arena.total_sanctuary_ticks) if arena != null else 0,
		"ai_pilot_active": bool(arena.ai_pilot_active) if arena != null else false,
		"ai_decisions_count": int(arena.ai_decisions_count) if arena != null else 0,
		"ai_last_action": str(arena.ai_last_action) if arena != null else "idle",
		"sprite_textures_loaded": int(arena.sprite_gen.textures.size()) if (arena != null and arena.sprite_gen != null) else 0,
		"png_files_written": int(arena.sprite_gen.png_files_written) if (arena != null and arena.sprite_gen != null) else 0,
		"total_particles_spawned": int(arena.total_particles_spawned) if arena != null else 0,
		"current_room_coord": "%d,%d" % [arena.current_room_coord.x, arena.current_room_coord.y] if arena != null else "0,0",
		"current_room_name": str(arena.get_current_room().get("name", "Crypt Entry Hall")) if (arena != null and arena.has_method("get_current_room")) else "Crypt Entry Hall",
		"current_room_type": str(arena.get_current_room().get("type", "entry")) if (arena != null and arena.has_method("get_current_room")) else "entry",
		"rooms_explored_count": int(arena.rooms_explored_count) if arena != null else 1,
		"total_door_transitions": int(arena.total_door_transitions) if arena != null else 0,
		"boss_enraged": bool(arena.is_boss_enraged()) if (arena != null and arena.has_method("is_boss_enraged")) else false,
		"total_boss_enrages": int(arena.total_boss_enrages) if arena != null else 0,
		"total_cinder_imps_summoned": int(arena.total_cinder_imps_summoned) if arena != null else 0,
		"elemental_stance": str(arena.elemental_stance) if arena != null else "none",
		"total_chilled_hits": int(arena.total_chilled_hits) if arena != null else 0,
		"total_elemental_burn_ticks": int(arena.total_elemental_burn_ticks) if arena != null else 0,
		"total_stormchain_arcs": int(arena.total_stormchain_arcs) if arena != null else 0,
		"sfx_muted": bool(sfx_node.muted) if sfx_node != null else false,
		"total_sfx_played": int(sfx_node.total_sfx_played) if sfx_node != null else 0,
		"high_wave_reached": int(loader.high_wave_reached) if loader != null else 1,
		"high_wave_score": int(loader.high_wave_score) if loader != null else 0,
		"bound_udp_port": _bound_port
	}


func _on_character_updated(_data: Dictionary, event_message: String) -> void:
	if not _is_listening:
		return
	var packet := {
		"event": "character_updated",
		"message": event_message,
		"snapshot": build_telemetry_snapshot()
	}
	_send_udp_json(packet, LOOPBACK_HOST, telemetry_port)


func _send_udp_json(payload: Dictionary, dest_host: String, dest_port: int) -> Error:
	if not _is_listening:
		return ERR_UNCONFIGURED
	var raw := JSON.stringify(payload).to_utf8_buffer()
	_udp.set_dest_address(dest_host, dest_port)
	return _udp.put_packet(raw)
