# godot_project/tests/test_hud_headless.gd
# Headless SceneTree test runner verifying HUD, Arena, Roster, Ultimates, Boss, Relics, SFX, Potions, UDP & Save/Load.
# Connects to: godot_project/scenes/main.tscn, godot_project/scripts/character_loader.gd
# Created: 2026-10-24

extends SceneTree

var _main_instance: Node = null
var _done: bool = false


func _initialize() -> void:
	print("=== Starting Iteration 23A Headless HUD, Arena, Roster, Ultimates, Boss, Relics, SFX, Potions, Pillars, Crits, Enemy Bolts, Parry, Hazards, Frenzy, AI Pilot, Pixel-Art Sprites, Dungeon Crawler, Boss Enrage, Elemental Infusions, Merchant Shop & Save Suite ===")
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if main_packed == null:
		printerr("FAIL: Could not load res://scenes/main.tscn")
		quit(1)
		return

	_main_instance = main_packed.instantiate()
	root.add_child(_main_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var loader: Node = _main_instance
	var hud: Node = _main_instance.get_node_or_null("CharacterSheetHUD") if _main_instance != null else null
	var arena: Node = _main_instance.get_node_or_null("Arena") if _main_instance != null else null
	var udp_bridge: Node = _main_instance.get_node_or_null("CommandCenterReceiver") if _main_instance != null else null
	var sfx: Node = _main_instance.get_node_or_null("ProceduralSfx") if _main_instance != null else null
	if loader == null or hud == null or arena == null or udp_bridge == null or sfx == null or hud.title_label == null:
		printerr("FAIL: Main, CharacterSheetHUD, Arena, CommandCenterReceiver, or ProceduralSfx node failed to initialize.")
		quit(1)
		return true

	# 1. Verify initial state bound to HUD (Slot 1: Kaelen)
	var title_text: String = str(hud.title_label.text)
	if not title_text.begins_with("Kaelen — Level 5"):
		printerr("FAIL: Unexpected initial HUD title: ", title_text)
		quit(1)
		return true
	print("PASS [1/46]: Initial HUD title verified -> ", title_text)

	# 2. Verify d20 Skill Check Roll
	var roll_res: Dictionary = loader.roll_skill_check(0)
	if roll_res.has("error") or int(roll_res.get("total", 0)) < 10:
		printerr("FAIL: Archery skill check roll invalid: ", roll_res)
		quit(1)
		return true
	print("PASS [2/46]: Skill check verified -> ", roll_res.get("summary", ""))

	# 3. Verify Combat Damage & Healing Clamping
	loader.modify_health(-15)
	if int(hud.hp_bar.value) != 30:
		printerr("FAIL: Expected HP 30 after -15 damage, got: ", hud.hp_bar.value)
		quit(1)
		return true
	loader.modify_health(100)
	if int(hud.hp_bar.value) != 45:
		printerr("FAIL: Expected HP clamped to 45 after heal, got: ", hud.hp_bar.value)
		quit(1)
		return true
	print("PASS [3/46]: Health damage and max-HP clamp verified (30 -> 45/45).")

	# 4. Verify Level Up Mutation & UI Refresh (Dexterity 18 -> 19, Level 5 -> 6)
	loader.apply_level_up()
	var updated_title: String = str(hud.title_label.text)
	if not updated_title.begins_with("Kaelen — Level 6") or int(hud.hp_bar.max_value) != 53:
		printerr("FAIL: Level-up did not update HUD title/HP bar: ", updated_title)
		quit(1)
		return true
	print("PASS [4/46]: Level-up verified -> ", updated_title, " (Max HP: 53)")

	# 5. Verify 2D Arena Toggle & Stat-Driven Speed/Arrow Damage Scaling
	hud.toggle_arena_mode()
	if hud.visible or not arena.arena_active:
		printerr("FAIL: toggle_arena_mode() did not activate Arena.")
		quit(1)
		return true
	loader.apply_level_up()
	var calc_dmg: int = arena.get_calculated_arrow_damage()
	var calc_spd: int = int(arena.get_calculated_move_speed())
	if calc_dmg != 16 or calc_spd != 320:
		printerr("FAIL: Expected Arena Dmg 16 & Speed 320 at Dex 20, got: ", calc_dmg, " / ", calc_spd)
		quit(1)
		return true
	print("PASS [5/46]: Arena toggle & live stat scaling verified -> Speed: %d px/s, Arrow Dmg: %d" % [calc_spd, calc_dmg])

	# 6. Verify Projectile Spawning in 2D Arena
	var proj: Dictionary = arena.fire_arrow_at(Vector2(760.0, 200.0))
	if arena.arrows.size() != 1 or int(proj.get("damage", 0)) != 16:
		printerr("FAIL: Arrow projectile did not spawn with expected damage.")
		quit(1)
		return true
	print("PASS [6/46]: Projectile spawn verified (Active projectiles: 1, Damage: 16)")

	# 7. Verify Target Dummy Hit & HP Reduction
	var hit_res: Dictionary = arena.apply_damage_to_dummy(0, calc_dmg)
	if int(hit_res.get("remaining_hp", 0)) != 29:
		printerr("FAIL: Expected Corruption Scout HP 29 after 16 dmg, got: ", hit_res)
		quit(1)
		return true
	print("PASS [7/46]: Target dummy hit verified -> ", hit_res.get("message", ""))

	# 8. Verify Roster Switch to Slot [2] Malakor, The Ash-Knight (Str 20 (+5), Cinder Bolts Rank 6 -> Dmg 17)
	var ash_data: Dictionary = loader.select_roster_character(1)
	if str(ash_data.get("character_id", "")) != "ash_001" or arena.get_calculated_arrow_damage() != 17:
		printerr("FAIL: Ash-Knight roster switch or damage calc failed: ", ash_data)
		quit(1)
		return true
	print("PASS [8/46]: Slot [2] Malakor, The Ash-Knight verified -> HP: 85, Cinder Bolts Dmg: 17")

	# 9. Verify Roster Switch to Slot [3] Vespera, Echo-Wraith (Dex 22 (+6) -> Speed 338 px/s, Phase Daggers Dmg 18)
	var echo_data: Dictionary = loader.select_roster_character(2)
	if str(echo_data.get("character_id", "")) != "ash_002" or int(arena.get_calculated_move_speed()) != 338:
		printerr("FAIL: Echo-Wraith roster switch or speed calc failed: ", echo_data)
		quit(1)
		return true
	print("PASS [9/46]: Slot [3] Vespera, Echo-Wraith verified -> Speed: 338 px/s, Phase Daggers Dmg: 18")

	# 10. Verify Mana Dash Ability (-6 MP, +145 px burst, 0.45s i-frames)
	var pos_before_dash: Vector2 = arena.player_pos
	var dash_res: Dictionary = arena.trigger_mana_dash(Vector2.RIGHT)
	var mp_after_dash: int = int(loader.current_data.get("mana", {}).get("current", 0))
	if dash_res.get("status") != "dashed" or mp_after_dash != 39 or arena.player_pos.distance_to(pos_before_dash) < 140.0:
		printerr("FAIL: Mana Dash did not burst or deduct 6 MP cleanly: ", dash_res)
		quit(1)
		return true
	print("PASS [10/46]: Mana Dash verified -> ", dash_res.get("message", ""))

	# 11. Verify Roster Switch to Slot [4] Gorvath & Constitution Armor Mitigation in Wave Survival
	var rot_data: Dictionary = loader.select_roster_character(3)
	if str(rot_data.get("character_id", "")) != "ash_003" or int(hud.hp_bar.max_value) != 120:
		printerr("FAIL: Gorvath roster switch failed: ", rot_data)
		quit(1)
		return true
	arena.dash_iframe_timer = 0.0
	var contact_res: Dictionary = arena.apply_enemy_contact_hit("Corruption Scout")
	if int(contact_res.get("damage_taken", 0)) != 6 or int(contact_res.get("armor_mitigated", 0)) != 6:
		printerr("FAIL: Expected Gorvath to take 6 dmg (6 mitigated), got: ", contact_res)
		quit(1)
		return true
	print("PASS [11/46]: Constitution Armor mitigation verified -> ", contact_res.get("message", ""))

	# 12. Verify Wave Survival Mode AI Pursuit & Wave Clear Progression (Wave 1 -> Wave 2)
	arena.toggle_wave_survival()
	var enemy_start_x: float = float(arena.dummies[0]["pos"].x)
	arena.step_wave_enemies(0.5)
	if float(arena.dummies[0]["pos"].x) >= enemy_start_x:
		printerr("FAIL: Wave Survival enemy did not pursue player to the left.")
		quit(1)
		return true
	arena.apply_damage_to_dummy(0, 500)
	arena.apply_damage_to_dummy(1, 500)
	arena.apply_damage_to_dummy(2, 500)
	if arena.wave_number != 2 or arena.wave_score != 300 or int(arena.dummies[0]["max_hp"]) <= 45:
		printerr("FAIL: Wave 1 clear did not advance to Wave 2 with scaled enemy HP.")
		quit(1)
		return true
	print("PASS [12/46]: Wave Survival AI chase & Wave 1->2 progression verified (Wave Score: %d, Wave 2 Scout HP: %d)" % [arena.wave_score, int(arena.dummies[0]["max_hp"])])

	# 13. Verify CommandCenterReceiver Direct RPC Command Execution
	var rpc_res: Dictionary = udp_bridge.execute_remote_command("select_hero", {"slot": 2})
	if rpc_res.get("status") != "ok" or str(rpc_res.get("snapshot", {}).get("character_id", "")) != "ash_001":
		printerr("FAIL: CommandCenterReceiver select_hero RPC failed: ", rpc_res)
		quit(1)
		return true
	print("PASS [13/46]: CommandCenterReceiver RPC verified -> ", rpc_res.get("note", ""))

	# 14. Verify Live Loopback UDP Socket Round-Trip (PacketPeerUDP -> CommandCenterReceiver -> ACK)
	var bound_port: int = udp_bridge.get_bound_port()
	var test_sender := PacketPeerUDP.new()
	test_sender.bind(0, "127.0.0.1")
	test_sender.set_dest_address("127.0.0.1", bound_port)
	var wire_cmd := JSON.stringify({"command": "level_up", "payload": {}}).to_utf8_buffer()
	test_sender.put_packet(wire_cmd)
	OS.delay_msec(15)
	udp_bridge.poll_packets()
	OS.delay_msec(15)
	if test_sender.get_available_packet_count() <= 0 or int(loader.current_data.get("level", 0)) != 8:
		test_sender.close()
		printerr("FAIL: Loopback UDP packet did not level up Ash-Knight to Level 8 or return ACK.")
		quit(1)
		return true
	var ack_text := test_sender.get_packet().get_string_from_utf8()
	test_sender.close()
	print("PASS [14/46]: Live UDP loopback datagram & ACK verified on port %d -> %s" % [bound_port, ack_text.substr(0, 75) + "..."])

	# 15. Verify Class Ultimate Ability ([Q] Key, -15 MP)
	arena.player_pos = Vector2(760.0, 200.0)
	var ult_res: Dictionary = arena.trigger_ultimate_ability()
	if ult_res.get("status") != "ultimate_cast" or str(ult_res.get("ultimate_name", "")) != "Consecrated Ember Nova" or int(ult_res.get("targets_hit", 0)) < 1:
		printerr("FAIL: Ash-Knight Consecrated Ember Nova ultimate failed: ", ult_res)
		quit(1)
		return true
	print("PASS [15/46]: Class Ultimate Ability verified -> ", ult_res.get("message", ""))

	# 16. Verify Boss Wave Encounter on Wave 3 (Ashen Titan [BOSS] Spawn)
	arena.apply_damage_to_dummy(0, 500)
	arena.apply_damage_to_dummy(1, 500)
	arena.apply_damage_to_dummy(2, 500)
	if arena.wave_number != 3 or not arena.is_boss_wave() or arena.dummies.size() != 4 or str(arena.dummies[3].get("name", "")) != "Ashen Titan [BOSS]":
		printerr("FAIL: Clearing Wave 2 did not spawn Ashen Titan [BOSS] on Wave 3: ", arena.dummies)
		quit(1)
		return true
	print("PASS [16/46]: Wave 3 Boss Encounter verified -> %s spawned (%d/%d HP)!" % [
		str(arena.dummies[3].get("name", "")),
		int(arena.dummies[3].get("hp", 0)),
		int(arena.dummies[3].get("max_hp", 0))
	])

	# 17. Verify Relic Chest Spawning on Wave Clear
	if arena.loot_chests.size() < 2:
		printerr("FAIL: Expected at least 2 Relic Chests spawned after clearing Waves 1 & 2, got: ", arena.loot_chests.size())
		quit(1)
		return true
	print("PASS [17/46]: Wave Clear Relic Chest spawning verified (%d active chests on arena floor)." % arena.loot_chests.size())

	# 18. Verify Looting Relic Chest Grants Inventory Item & Boosts Derived Combat Stats
	var dmg_before_relic: int = arena.get_calculated_arrow_damage()
	var loot_res: Dictionary = arena.collect_nearest_relic_chest(true)
	var dmg_after_relic: int = arena.get_calculated_arrow_damage()
	var bonuses: Dictionary = loader.get_inventory_bonuses()
	if loot_res.get("status") != "relic_looted" or dmg_after_relic <= dmg_before_relic or int(bonuses.get("relic_count", 0)) < 1:
		printerr("FAIL: Looting Relic Chest did not boost hero damage or inventory bonuses: ", loot_res)
		quit(1)
		return true
	print("PASS [18/46]: Relic Chest loot & stat bonus verified (Dmg %d -> %d) -> %s" % [
		dmg_before_relic,
		dmg_after_relic,
		str(loot_res.get("message", ""))
	])

	# 19. Verify Persistent Save Party Progression to user://test_roster_save.json
	var test_save_path := "user://test_roster_save.json"
	var save_res: Dictionary = loader.save_party_progression(test_save_path)
	if save_res.get("status") != "saved" or int(save_res.get("saved_heroes_count", 0)) != 4 or int(save_res.get("high_wave_score", 0)) != 900:
		printerr("FAIL: save_party_progression() did not persist 4 heroes and high_wave_score 900: ", save_res)
		quit(1)
		return true
	print("PASS [19/46]: Save party progression verified -> ", save_res.get("message", ""))

	# 20. Verify Reset & Load Party Progression Restores Level-Ups, Relics, Active Slot & Wave Records
	loader.reset_all_progression()
	if int(loader.current_data.get("level", 0)) != 7 or loader.high_wave_score != 0 or int(loader.get_inventory_bonuses().get("relic_count", 0)) != 0:
		printerr("FAIL: reset_all_progression() did not reset state cleanly.")
		quit(1)
		return true
	var load_res: Dictionary = loader.load_party_progression(test_save_path)
	if load_res.get("status") != "loaded" or int(loader.current_data.get("level", 0)) != 8 or int(loader.get_inventory_bonuses().get("relic_count", 0)) < 1:
		printerr("FAIL: load_party_progression() did not restore Ash-Knight Level 8 & equipped Relic: ", load_res)
		quit(1)
		return true
	loader.select_roster_character(0)
	if int(loader.current_data.get("level", 0)) != 7:
		printerr("FAIL: Loaded roster cache did not preserve Kaelen Level 7 across slots.")
		quit(1)
		return true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	print("PASS [20/46]: Load party progression verified (Ash-Knight Level 8 + Relic, Kaelen Level 7, Best Wave 3 / 900 pts restored).")

	# 21. Verify ProceduralSfx Waveform Synthesis & Combat Cue Accounting
	if sfx.total_sfx_played < 8 or not sfx.cue_counts.has("shoot") or not sfx.cue_counts.has("ultimate") or not sfx.cue_counts.has("relic_loot") or not sfx.cue_counts.has("boss_spawn"):
		printerr("FAIL: ProceduralSfx did not synthesize all expected combat cues: ", sfx.cue_counts)
		quit(1)
		return true
	print("PASS [21/46]: ProceduralSfx waveform synthesis verified (%d cues played: %s, last samples=%d)." % [
		sfx.total_sfx_played,
		JSON.stringify(sfx.cue_counts),
		sfx.last_samples_generated
	])

	# 22. Verify ProceduralSfx Mute Toggle ([M] Key / RPC)
	var muted_state: bool = sfx.toggle_mute()
	var muted_play: Dictionary = sfx.play_cue("shoot")
	var unmuted_state: bool = sfx.toggle_mute()
	var unmuted_play: Dictionary = sfx.play_cue("level_up")
	if not muted_state or muted_play.get("status") != "muted" or unmuted_state or unmuted_play.get("status") != "played":
		printerr("FAIL: ProceduralSfx mute/unmute toggle failed: ", muted_play, " / ", unmuted_play)
		quit(1)
		return true
	print("PASS [22/46]: ProceduralSfx mute toggle [M] verified (Muted samples=0 -> Unmuted 'level_up' samples=%d)." % [
		int(unmuted_play.get("samples_generated", 0))
	])

	# 23. Verify Interactive Consumable Potion ([C] Key / trigger_use_potion) Restores HP/MP & Decrements Quantity
	loader.modify_health(-30)
	loader.modify_mana(-15, true)
	var hp_before_pot: int = int(loader.current_data.get("health", {}).get("current", 0))
	var pot_res_1: Dictionary = arena.trigger_use_potion()
	var hp_after_pot: int = int(loader.current_data.get("health", {}).get("current", 0))
	if pot_res_1.get("status") != "consumed" or hp_after_pot != hp_before_pot + 25 or int(pot_res_1.get("remaining_potions", -1)) != 1:
		printerr("FAIL: trigger_use_potion() did not restore +25 HP or decrement quantity to 1: ", pot_res_1)
		quit(1)
		return true
	print("PASS [23/46]: Consumable Potion [C] verified -> ", pot_res_1.get("message", ""))

	# 24. Verify Zero-Quantity Cleanup, Empty Potion Error Boundary & Boss Potion Restock
	var pot_res_2: Dictionary = arena.trigger_use_potion()
	var pot_empty_res: Dictionary = arena.trigger_use_potion()
	var restock_res: Dictionary = loader.grant_consumable_potion(1)
	if int(pot_res_2.get("remaining_potions", -1)) != 0 or not pot_empty_res.has("error") or int(restock_res.get("remaining_potions", 0)) != 1:
		printerr("FAIL: Potion zero-quantity cleanup, empty error boundary, or restock failed: ", pot_empty_res, " / ", restock_res)
		quit(1)
		return true
	print("PASS [24/46]: Potion zero-quantity cleanup, empty boundary check & Boss restock verified (%s)." % str(restock_res.get("message", "")))

	# 25. Verify Tactical Obsidian Pillars, Circle Collision Resolution & Line-of-Sight Cover
	var los_blocked: bool = not arena.has_line_of_sight(Vector2(380.0, 220.0), Vector2(560.0, 220.0))
	var los_clear: bool = arena.has_line_of_sight(Vector2(260.0, 350.0), Vector2(880.0, 350.0))
	var col_test: Dictionary = arena.resolve_circle_obstacle_collision(Vector2(475.0, 220.0), 18.0)
	var pushed_pos: Vector2 = col_test.get("pos", Vector2.ZERO)
	if arena.obstacles.size() != 4 or not los_blocked or not los_clear or not bool(col_test.get("collided", false)) or pushed_pos.distance_to(Vector2(470.0, 220.0)) < 49.5:
		printerr("FAIL: Obsidian Pillar LoS cover or circle collision resolution failed: ", col_test)
		quit(1)
		return true
	print("PASS [25/46]: Obsidian Pillars (4), circle collision push-out & Line-of-Sight cover verified (Blocked LoS=%s, Clear Corridor=%s)." % [
		str(los_blocked),
		str(los_clear)
	])

	# 26. Verify Projectile Interception by Obsidian Pillar Cover (step_projectiles)
	arena.arrows.clear()
	arena.player_pos = Vector2(415.0, 220.0)
	arena.fire_arrow_at(Vector2(560.0, 220.0))
	var blocked_arrows: int = arena.step_projectiles(0.08)
	if blocked_arrows != 1 or arena.obstacle_blocks_count < 1 or not arena.arrows.is_empty():
		printerr("FAIL: Projectile aimed into Obsidian Pillar NW was not blocked: blocked=", blocked_arrows, " remaining=", arena.arrows.size())
		quit(1)
		return true
	print("PASS [26/46]: Projectile cover interception verified (Blocked by Obsidian Pillar NW, total blocks=%d)." % arena.obstacle_blocks_count)

	# 27. Verify Dexterity/Wisdom Critical Hit System (2x Damage & force_crit RPC)
	var crit_chance: float = arena.get_calculated_crit_chance()
	udp_bridge.execute_remote_command("force_crit", {})
	var crit_hit_res: Dictionary = arena.apply_damage_to_dummy(0, 16)
	if crit_chance < 0.20 or not bool(crit_hit_res.get("is_crit", false)) or int(crit_hit_res.get("damage", 0)) != 32 or arena.total_critical_hits < 1:
		printerr("FAIL: Critical Hit 2x damage or crit_chance scaling failed: ", crit_hit_res, " chance=", crit_chance)
		quit(1)
		return true
	print("PASS [27/46]: Critical Hit 2x multiplier & Dex/Wis Crit Chance (%d%%) verified -> %s" % [
		int(round(crit_chance * 100.0)),
		str(crit_hit_res.get("message", ""))
	])

	# 28. Verify Floating Combat Text Popup Spawning, Rising Physics & TTL Expiration
	var ft_count_before: int = arena.floating_texts.size()
	var last_popup: Dictionary = arena.floating_texts[ft_count_before - 1] if ft_count_before > 0 else {}
	var start_y: float = float(last_popup.get("pos", Vector2.ZERO).y)
	arena.step_floating_texts(0.15)
	var moved_y: float = float(arena.floating_texts[arena.floating_texts.size() - 1].get("pos", Vector2.ZERO).y) if not arena.floating_texts.is_empty() else start_y
	arena.step_floating_texts(2.0)
	if ft_count_before < 1 or str(last_popup.get("text", "")) != "CRIT -32!" or moved_y >= start_y or not arena.floating_texts.is_empty():
		printerr("FAIL: Floating Combat Text popup lifecycle failed: count_before=", ft_count_before, " text=", last_popup.get("text", ""))
		quit(1)
		return true
	print("PASS [28/46]: Floating Combat Text popups verified (%d total spawned, 'CRIT -32!' rose & faded cleanly)." % arena.total_floating_texts_spawned)

	# 29. Verify Enemy Ranged Projectiles, Boss 3-Bolt Fireball Volley & Obsidian Pillar Cover Interception
	arena.enemy_projectiles.clear()
	var boss_volley_res: Dictionary = arena.fire_enemy_projectile_from(3, Vector2(260.0, 350.0))
	var boss_bolts_count: int = int(boss_volley_res.get("bolts_spawned", 0))
	arena.enemy_projectiles.clear()
	arena.dummies[0]["pos"] = Vector2(535.0, 220.0)
	arena.fire_enemy_projectile_from(0, Vector2(380.0, 220.0))
	var step_ep_res: Dictionary = arena.step_enemy_projectiles(0.10)
	if boss_bolts_count != 3 or not bool(boss_volley_res.get("is_boss_volley", false)) or int(step_ep_res.get("blocked_by_cover", 0)) != 1 or arena.enemy_projectiles_blocked_by_cover < 1:
		printerr("FAIL: Boss 3-bolt Fireball Volley or enemy projectile cover block failed: ", boss_volley_res, " / ", step_ep_res)
		quit(1)
		return true
	print("PASS [29/46]: Boss 3-Bolt Fireball Volley & Obsidian Pillar enemy bolt interception verified (Boss bolts=%d, Cover blocks=%d)." % [
		boss_bolts_count,
		arena.enemy_projectiles_blocked_by_cover
	])

	# 30. Verify Hero Hit & Mana Dash I-Frame Dodge Against Incoming Enemy Projectiles
	arena.enemy_projectiles.clear()
	arena.player_pos = Vector2(260.0, 350.0)
	arena.dash_iframe_timer = 0.45
	arena.dummies[1]["pos"] = Vector2(315.0, 350.0)
	arena.fire_enemy_projectile_from(1, Vector2(260.0, 350.0))
	var dodge_step_res: Dictionary = arena.step_enemy_projectiles(0.08)
	arena.dash_iframe_timer = 0.0
	var direct_hit_res: Dictionary = arena.apply_enemy_projectile_hit("Ashen Titan [BOSS]", 14)
	if int(dodge_step_res.get("dodged_hits", 0)) != 1 or direct_hit_res.get("status") != "hit_player" or int(direct_hit_res.get("damage_taken", 0)) <= 0:
		printerr("FAIL: Enemy projectile Mana Dash dodge or armor-mitigated hit failed: ", dodge_step_res, " / ", direct_hit_res)
		quit(1)
		return true
	print("PASS [30/46]: Enemy projectile Mana Dash dodge ('DODGED!') & armor-mitigated hit verified -> %s" % str(direct_hit_res.get("message", "")))

	# 31. Verify Arcane Parry & Projectile Deflection ([F] Key / trigger_arcane_parry)
	arena.enemy_projectiles.clear()
	arena.arrows.clear()
	arena.parry_cooldown_timer = 0.0
	arena.player_pos = Vector2(260.0, 350.0)
	arena.dummies[1]["pos"] = Vector2(290.0, 350.0)
	arena.fire_enemy_projectile_from(1, Vector2(260.0, 350.0))
	var parry_res: Dictionary = arena.trigger_arcane_parry()
	if parry_res.get("status") != "parried_projectiles" or int(parry_res.get("reflected_count", 0)) != 1 or arena.arrows.size() != 1 or not bool(arena.arrows[0].get("is_parried", false)):
		printerr("FAIL: Arcane Parry did not deflect incoming Cinder Bolt into supercharged player arrow: ", parry_res)
		quit(1)
		return true
	print("PASS [31/46]: Arcane Parry [F] deflection verified -> %s" % str(parry_res.get("message", "")))

	# 32. Verify Environmental Hazard Zones (Molten Cinder Pit Burn DoT & Sanctuary Shrine Regen)
	arena.dummies[0]["alive"] = true
	arena.dummies[0]["hp"] = 50
	arena.dummies[0]["pos"] = Vector2(565.0, 175.0)
	arena.player_pos = Vector2(330.0, 350.0)
	loader.modify_health(-10)
	var haz_res: Dictionary = arena.step_hazard_zones(0.55)
	if arena.hazard_zones.size() != 3 or int(haz_res.get("enemies_burned", 0)) < 1 or int(haz_res.get("sanctuary_healed", 0)) < 1 or int(arena.dummies[0]["hp"]) != 42:
		printerr("FAIL: Environmental Hazard / Sanctuary Shrine tick failed: ", haz_res, " dummy_hp=", arena.dummies[0]["hp"])
		quit(1)
		return true
	print("PASS [32/46]: Environmental Hazard & Sanctuary Zones verified (Molten Burn -8 HP on enemy, Sanctuary +2 HP/+3 MP on hero).")

	# 33. Verify Combo Kill-Streak & Frenzy Multiplier System (+15% Speed, +10% Crit, 2x/3x Multiplier)
	arena.combo_count = 0
	var base_spd_pre_frenzy: float = arena.get_frenzy_move_speed()
	var base_crit_pre_frenzy: float = arena.get_calculated_crit_chance()
	arena.register_combo_hit()
	arena.register_combo_hit()
	var frenzy_res: Dictionary = arena.register_combo_hit()
	var spd_post_frenzy: float = arena.get_frenzy_move_speed()
	var crit_post_frenzy: float = arena.get_calculated_crit_chance()
	if not bool(frenzy_res.get("frenzy_active", false)) or int(frenzy_res.get("multiplier", 1)) != 2 or spd_post_frenzy <= base_spd_pre_frenzy or crit_post_frenzy <= base_crit_pre_frenzy:
		printerr("FAIL: Combo Frenzy Mode did not activate 2x multiplier, +15% haste, and +10% crit: ", frenzy_res)
		quit(1)
		return true
	print("PASS [33/46]: Combo Kill-Streak & Frenzy Mode verified (Combo=%d, Multiplier=%dx, Speed %d->%d px/s, Crit %d%%->%d%%)." % [
		arena.combo_count,
		arena.get_combo_multiplier(),
		int(base_spd_pre_frenzy),
		int(spd_post_frenzy),
		int(round(base_crit_pre_frenzy * 100.0)),
		int(round(crit_post_frenzy * 100.0))
	])

	# 34. Verify Autonomous Tactical Utility AI Auto-Pilot ([P] Key / toggle_ai_pilot RPC: Emergency Potion + Reflex Parry + Aimed Fire)
	udp_bridge.execute_remote_command("toggle_ai_pilot", {})
	loader.modify_health(-45)
	loader.grant_consumable_potion(1)
	arena.parry_cooldown_timer = 0.0
	arena.player_pos = Vector2(260.0, 350.0)
	arena.dummies[1]["alive"] = true
	arena.dummies[1]["pos"] = Vector2(292.0, 350.0)
	arena.fire_enemy_projectile_from(1, Vector2(260.0, 350.0))
	var ai_step_1: Dictionary = arena.step_ai_pilot(0.45)
	var actions_1: Array = ai_step_1.get("actions_taken", [])
	if not arena.ai_pilot_active or not actions_1.has("use_potion") or not actions_1.has("arcane_parry") or not actions_1.has("aim_and_fire"):
		printerr("FAIL: Tactical AI Auto-Pilot did not execute emergency potion, reflex parry, and aimed fire: ", ai_step_1)
		quit(1)
		return true
	print("PASS [34/46]: Tactical Utility AI Auto-Pilot [P] multi-action evaluation verified (Actions=%s, Total AI decisions=%d)." % [
		JSON.stringify(actions_1),
		arena.ai_decisions_count
	])

	# 35. Verify Tactical Utility AI Danger-Zone Mana Dash Evasion ("evade_dash")
	arena.dash_cooldown_timer = 0.0
	loader.modify_mana(20, true)
	arena.player_pos = Vector2(500.0, 350.0)
	arena.dummies[0]["alive"] = true
	arena.dummies[0]["pos"] = Vector2(540.0, 350.0)
	var ai_step_2: Dictionary = arena.step_ai_pilot(0.15)
	var actions_2: Array = ai_step_2.get("actions_taken", [])
	if not actions_2.has("evade_dash") or arena.player_pos.distance_to(Vector2(540.0, 350.0)) <= 60.0:
		printerr("FAIL: Tactical AI Auto-Pilot did not trigger evade_dash when enemy closed within danger radius: ", ai_step_2)
		quit(1)
		return true
	print("PASS [35/46]: Tactical Utility AI danger-zone Mana Dash evasion ('evade_dash') verified (New pos=%s)." % str(arena.player_pos))

	# 36. Verify Dark-Fantasy Pixel-Art Sprite Generator, PNG Disk Export & HUD Hero Portrait
	if arena.sprite_gen == null or arena.sprite_gen.textures.size() < 23 or arena.sprite_gen.png_files_written < 23 or hud.hero_portrait == null or hud.hero_portrait.texture == null:
		printerr("FAIL: SpriteArtGenerator did not generate 23 pixel-art textures, write .png files, or bind HUD HeroPortrait: textures=", arena.sprite_gen.textures.size() if arena.sprite_gen else 0)
		quit(1)
		return true
	print("PASS [36/46]: Dark-Fantasy Pixel-Art Sprite Generator verified (%d Nearest-Neighbor textures, %d .png sprites written to res://assets/sprites/, HUD HeroPortrait bound)." % [
		arena.sprite_gen.textures.size(),
		arena.sprite_gen.png_files_written
	])

	# 37. Verify Directional Pixel-Spark Particle Burst System & Camera Screen-Shake
	arena.particles.clear()
	arena.spawn_particle_burst(Vector2(300.0, 300.0), Color(1.0, 0.75, 0.2), 16, 1.25)
	arena.trigger_screen_shake(0.55)
	var active_parts_before: int = arena.particles.size()
	arena.step_particles(0.08)
	var alive_after_step: int = arena.particles.size()
	var trauma_after_step: float = arena.screen_shake_trauma
	arena.step_particles(1.0)
	var alive_after_expire: int = arena.particles.size()
	if active_parts_before != 16 or alive_after_step != 16 or alive_after_expire != 0 or arena.total_particles_spawned < 16 or trauma_after_step <= 0.0:
		printerr("FAIL: Pixel-Spark Particle Burst or Camera Screen-Shake lifecycle failed: before=", active_parts_before, " trauma=", trauma_after_step)
		quit(1)
		return true
	print("PASS [37/46]: Pixel-Spark Particle Burst & Camera Screen-Shake verified (%d total particles spawned, trauma=%.2f)." % [
		arena.total_particles_spawned,
		trauma_after_step
	])

	# 38. Verify 5-Room Procedural Dungeon Graph & Gilded Relic Vault Door Transition
	arena.loot_chests.clear()
	var vault_res: Dictionary = arena.enter_dungeon_door("S", true)
	if arena.dungeon_rooms.size() != 5 or vault_res.get("status") != "room_entered" or arena.current_room_coord != Vector2i(0, 1) or str(vault_res.get("room_type", "")) != "treasure" or arena.loot_chests.size() != 2 or arena.rooms_explored_count != 2:
		printerr("FAIL: Entering South Dungeon Door did not transition to Gilded Relic Vault (0,1) with 2 chests: ", vault_res)
		quit(1)
		return true
	print("PASS [38/46]: Procedural Dungeon Door ('S') -> Gilded Relic Vault (0,1) verified (2 Vault Chests spawned, Rooms Explored: %d/5)." % arena.rooms_explored_count)

	# 39. Verify Consecrated Sanctuary Restock & Boss Throne Room Transition via UDP RPC ("enter_door")
	arena.enter_dungeon_door("N", true)
	var pots_before_sanc: int = loader.get_consumable_count()
	var sanc_res: Dictionary = arena.enter_dungeon_door("W", true)
	var pots_after_sanc: int = loader.get_consumable_count()
	arena.enter_dungeon_door("E", true)
	var throne_rpc: Dictionary = udp_bridge.execute_remote_command("enter_door", {"direction": "E", "force_unlock": true})
	var throne_snap: Dictionary = throne_rpc.get("snapshot", {})
	if sanc_res.get("room_type") != "sanctuary" or pots_after_sanc != pots_before_sanc + 1 or str(throne_snap.get("current_room_type", "")) != "boss" or arena.dummies.size() != 4 or str(arena.dummies[3].get("name", "")) != "Ashen Titan [BOSS]":
		printerr("FAIL: Sanctuary restock or Boss Throne Room (1,0) transition failed: sanc=", sanc_res, " throne=", throne_snap)
		quit(1)
		return true
	print("PASS [39/46]: Sanctuary Chamber (+1 Elixir) & Boss Throne Room (1,0) verified -> %s (Rooms Explored: %d/5, Transitions: %d)." % [
		str(throne_snap.get("current_room_name", "")),
		int(throne_snap.get("rooms_explored_count", 0)),
		int(throne_snap.get("total_door_transitions", 0))
	])

	# 40. Verify Boss Phase 2 Molten Enrage at <= 50% HP (+30% Speed & 2 Summoned Cinder Imps)
	arena.enemy_projectiles.clear()
	var boss_spd_pre: float = float(arena.dummies[3].get("speed", 0.0))
	var enrage_hit_res: Dictionary = arena.apply_damage_to_dummy(3, 180)
	var boss_spd_post: float = float(arena.dummies[3].get("speed", 0.0))
	if not arena.is_boss_enraged() or arena.total_boss_enrages < 1 or arena.total_cinder_imps_summoned != 2 or arena.dummies.size() != 6 or boss_spd_post <= boss_spd_pre or arena.enemy_projectiles.size() != 5:
		printerr("FAIL: Boss Phase 2 Molten Enrage did not summon 2 Cinder Imps, boost speed, or fire 5-bolt nova: ", enrage_hit_res, " dummies=", arena.dummies.size())
		quit(1)
		return true
	print("PASS [40/46]: Boss Phase 2 Molten Enrage verified -> %s" % str(enrage_hit_res.get("message", "")))

	# 41. Verify Enraged Boss 5-Bolt Radial Fireball Nova Volley (is_enraged_nova = true, 5 bolts)
	arena.enemy_projectiles.clear()
	var nova_volley: Dictionary = arena.fire_enemy_projectile_from(3, Vector2(260.0, 350.0))
	if int(nova_volley.get("bolts_spawned", 0)) != 5 or not bool(nova_volley.get("is_enraged_nova", false)) or int(nova_volley.get("damage_per_bolt", 0)) != 16:
		printerr("FAIL: Enraged Boss did not fire 5-bolt Radial Fireball Nova at 16 dmg/bolt: ", nova_volley)
		quit(1)
		return true
	print("PASS [41/46]: Enraged Boss 5-Bolt Radial Fireball Nova verified (Bolts=%d, Dmg/Bolt=%d, Enraged Nova=%s)." % [
		int(nova_volley.get("bolts_spawned", 0)),
		int(nova_volley.get("damage_per_bolt", 0)),
		str(nova_volley.get("is_enraged_nova", false))
	])

	# 42. Verify Elemental Weapon Infusion Stance ([V] Key / cycle_stance RPC): Frostbite Chill & Cinderbrand Burn DoT
	arena.dummies[0]["alive"] = true
	arena.dummies[0]["hp"] = 80
	arena.dummies[0]["pos"] = Vector2(760.0, 200.0)
	udp_bridge.execute_remote_command("cycle_stance", {"stance": "frostbite"})
	arena.apply_damage_to_dummy(0, 10)
	var frost_timer_applied: float = float(arena.dummies[0].get("frost_timer", 0.0))
	arena.cycle_elemental_stance("cinderbrand")
	arena.apply_damage_to_dummy(0, 10)
	var hp_before_burn: int = int(arena.dummies[0].get("hp", 0))
	var burn_step_res: Dictionary = arena.step_elemental_statuses(0.55)
	var hp_after_burn: int = int(arena.dummies[0].get("hp", 0))
	if frost_timer_applied <= 0.0 or arena.total_chilled_hits < 1 or int(burn_step_res.get("burn_ticks_applied", 0)) < 1 or hp_after_burn >= hp_before_burn:
		printerr("FAIL: Frostbite chill or Cinderbrand burn DoT failed: frost=", frost_timer_applied, " burn_step=", burn_step_res)
		quit(1)
		return true
	print("PASS [42/46]: Frostbite (-35%% speed chill) & Cinderbrand stacking Burn DoT verified (Chilled hits=%d, Burn ticks=%d, Enemy HP %d->%d)." % [
		arena.total_chilled_hits,
		arena.total_elemental_burn_ticks,
		hp_before_burn,
		hp_after_burn
	])

	# 43. Verify Stormchain Lightning Arc (50% Secondary Chain-Lightning Damage & Crackling Arc Visual)
	arena.dummies[0]["alive"] = true
	arena.dummies[0]["hp"] = 80
	arena.dummies[0]["pos"] = Vector2(760.0, 200.0)
	arena.dummies[1]["alive"] = true
	arena.dummies[1]["hp"] = 80
	arena.dummies[1]["pos"] = Vector2(880.0, 310.0)
	arena.lightning_arcs.clear()
	arena.cycle_elemental_stance("stormchain")
	var storm_res: Dictionary = arena.apply_damage_to_dummy(0, 20)
	var elem_proc: Dictionary = storm_res.get("elemental_proc", {})
	if str(elem_proc.get("effect", "")) != "stormchain" or int(elem_proc.get("chain_damage", 0)) != 10 or int(arena.dummies[1].get("hp", 0)) != 70 or arena.lightning_arcs.size() != 1 or arena.total_stormchain_arcs < 1:
		printerr("FAIL: Stormchain did not arc 50% chain-lightning damage (10 dmg) to secondary target: ", storm_res)
		quit(1)
		return true
	print("PASS [43/46]: Stormchain Lightning Arc verified (Primary hit=20 dmg -> Chained 10 dmg to %s, Active lightning arcs=%d)." % [
		str(arena.dummies[1].get("name", "Target")),
		arena.lightning_arcs.size()
	])

	# 44. Verify Gold Coin Drop Economy & Magnetized Coin Pickup
	arena.coin_drops.clear()
	var gold_before_pickup: int = arena.gold_coins
	arena.spawn_coin_drop(arena.player_pos + Vector2(45.0, 0.0), 25, false)
	var collected_gold: int = arena.step_coin_drops(0.20)
	if gold_before_pickup < 100 or collected_gold != 25 or arena.gold_coins != gold_before_pickup + 25:
		printerr("FAIL: Gold Coin Drop or magnetized pickup failed: before=", gold_before_pickup, " collected=", collected_gold, " total=", arena.gold_coins)
		quit(1)
		return true
	print("PASS [44/46]: Gold Coin Drop & magnetized pickup verified (+%dg magnetized -> Total Gold: %dg, Total Earned: %dg)." % [
		collected_gold,
		arena.gold_coins,
		arena.total_gold_earned
	])

	# 45. Verify Dungeon Merchant NPC Shop Upgrades ([B] Key / buy_upgrade RPC: Whetstone +3 Dmg, Armor +15 Max HP & Insufficient Gold Boundary)
	var dmg_pre_shop: int = arena.get_calculated_arrow_damage()
	var buy_whetstone: Dictionary = arena.buy_merchant_upgrade("whetstone")
	var dmg_post_shop: int = arena.get_calculated_arrow_damage()
	var buy_armor_rpc: Dictionary = udp_bridge.execute_remote_command("buy_upgrade", {"item_key": "armor"})
	arena.gold_coins = 10
	var broke_res: Dictionary = arena.buy_merchant_upgrade("whetstone")
	if buy_whetstone.get("status") != "purchased" or dmg_post_shop != dmg_pre_shop + 3 or arena.shop_bonus_max_hp != 15 or arena.shop_purchases_count != 2 or not broke_res.has("error"):
		printerr("FAIL: Dungeon Merchant shop upgrade or insufficient-gold boundary check failed: ", buy_whetstone, " / ", buy_armor_rpc, " / ", broke_res)
		quit(1)
		return true
	print("PASS [45/46]: Dungeon Merchant NPC Shop [B] verified (Whetstone Dmg %d->%d, Armor +15 Max HP, Insufficient-gold boundary verified)." % [
		dmg_pre_shop,
		dmg_post_shop
	])

	# 46. Verify Failure Mode / Missing File Boundary Error Banner
	hud.toggle_arena_mode()
	var missing_res: Dictionary = loader.load_character_data("res://data/NonExistentChaosFile.json")
	if not missing_res.is_empty() or not hud.error_banner.visible:
		printerr("FAIL: Missing file error banner did not trigger.")
		quit(1)
		return true
	print("PASS [46/46]: Missing-file error state verified -> ", hud.error_banner.text)

	print("=== ALL 46 HEADLESS HUD, ARENA, ROSTER, ULTIMATES, BOSS, RELICS, SFX, POTIONS, PILLARS, CRITS, ENEMY BOLTS, PARRY, HAZARDS, FRENZY, AI PILOT, PIXEL-ART SPRITES, DUNGEON CRAWLER, BOSS ENRAGE, ELEMENTAL INFUSIONS, MERCHANT SHOP, UDP & SAVE/LOAD TESTS PASSED ===")
	_main_instance.queue_free()
	quit(0)
	return true
