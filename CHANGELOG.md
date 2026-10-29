# Changelog

## [3.5.0] - 2026-10-29
- Add Boss Rush & Pantheon Gauntlet Mode (`start_pantheon_gauntlet()`, `check_gauntlet_completion()` via **`[I]` key**, **`"Gauntlet (0) [I]"` button**, and `"start_gauntlet"` / `"check_gauntlet"` UDP RPCs) at the Pantheon War-Banner (`(510, 175)`), spawning a multi-elite & Boss arena trial (`Relic Mimic [ELITE]`, `Ashen Stalker [CHAMPION]`, and `Ashen Titan [BOSS]`) that awards a **Champion Trophy** (`+100g` Gold Coins, `+2` Talent Points, `+1` Guaranteed Relic, `+1` Healing Elixir, and full HP/MP restoration) upon completion.
- Add `prop_gauntlet_banner.png` Pantheon Gauntlet War-Banner pixel-art sprite in `sprite_art_generator.gd` (bringing total exported `.png` sprites to 41) and expand headless Godot test suite to 68/68 assertions (`godot_project/tests/test_hud_headless.gd`).

## [3.4.0] - 2026-10-26
- Add Relic Crafting & Blacksmith Forge (`forge_mythic_relic()` via **`[O]` key**, **`"Forge (0) [O]"` button**, and `"forge_mythic"` UDP RPC) at the Obsidian Blacksmith Anvil (`(510, 505)`), spending `50g` Gold Coins or reforging a duplicate Relic stack (`quantity >= 2`) into **Mythic Sovereign Ashblade** (`+8 Dmg, +15 Max HP`), **Mythic Obsidian Aegis** (`+5 Dmg, +25 Max HP`), or **Mythic Stormstrider Greaves** (`+6 Dmg, +25 Spd`).
- Add `prop_anvil.png` Obsidian Blacksmith Anvil pixel-art sprite in `sprite_art_generator.gd` (bringing total exported `.png` sprites to 40) and expand headless Godot test suite to 66/66 assertions (`godot_project/tests/test_hud_headless.gd`).

## [3.3.0] - 2026-10-26
- Add Deployable Arcane Turret Totems (`deploy_arcane_totem()`, `step_arcane_totems()`, `is_hero_in_totem_aura()`, `get_totem_bolt_damage()` via **`[H]` key**, **`"Totem (0/2) [H]"` button**, and `"deploy_totem"` / `"step_totems"` UDP RPCs) placing up to 2 Runic Crossfire Sentry Totems (`14.0s` lifetime, bounded FIFO queue replacement) that pulse every `1.0s` to fire Wisdom-scaled Arcane Bolts at enemies and project a **`+15%` Attack Damage aura** (`160 px` radius).
- Add `prop_totem.png` Runic Sentry Totem pixel-art sprite in `sprite_art_generator.gd` (bringing total exported `.png` sprites to 39) and expand headless Godot test suite to 64/64 assertions (`godot_project/tests/test_hud_headless.gd`).

## [3.2.0] - 2026-10-26
- Add Procedural Weather & Atmospheric Dungeon Mutators (`cycle_dungeon_mutator()`, `get_mutator_gold_multiplier()`, `get_mutator_mana_regen_rate()`, `_step_weather_atmosphere()` via **`[Y]` key**, **`"Mutator: CLEAR [Y]"` button**, and `"cycle_mutator"` UDP RPC) cycling through **Ashen Eclipse** (`+25%` Gold Coin drops from monsters & drifting ash embers), **Arcane Tempest** (`+50%` passive Mana regeneration rate & crackling sky-lightning), and **Blood Moon** (`+15%` Critical Hit Chance for all heroes & crimson mists).
- Add `prop_mutator_obelisk.png` runic Weather Obelisk pixel-art sprite in `sprite_art_generator.gd` (bringing total exported `.png` sprites to 38) and expand headless Godot test suite to 62/62 assertions (`godot_project/tests/test_hud_headless.gd`).

## [3.1.0] - 2026-10-25
- Add Cursed Shrine Gambits & High-Risk / High-Reward Corruptions (`activate_cursed_gambit()` via **`[U]` key**, **`"Gambit (0) [U]"` button**, and `"activate_gambit"` UDP RPC) sacrificing `25%` current HP (clamped with a non-lethal `1 HP` floor) in exchange for rotating permanent corruptions: **Pact of Blood Might** (`+4` permanent Base Attack Damage), **Pact of Shadow Fury** (`+15%` permanent Critical Hit Chance), and **Pact of Forbidden Plunder** (`+60g` Gold Coins & `+1` Guaranteed Relic).
- Add `prop_cursed_altar.png` crimson skull-carved Blood Altar sprite in `sprite_art_generator.gd` (bringing total exported `.png` sprites to 37) and expand headless Godot test suite to 60/60 assertions (`godot_project/tests/test_hud_headless.gd`).

## [3.0.1] - 2026-10-25
- Fix GUI formatting, right-edge text overflow, and map/HUD overlaps across `project.godot`, `arena_controller.gd`, and `character_sheet_hud.gd`:
  - Configure `1280x720` HD viewport (`window/size/viewport_width=1280`, `window/size/viewport_height=720`, `canvas_items` stretch mode) in `godot_project/project.godot`.
  - Split the 20 Arena controls into a compact **Top Status Header** (`y = 0..56`, ellipsis-clamped status/combat banners + 4 system buttons) and a **2-Row Bottom Action Dock** (`y = 636..720`, 8 compact buttons per row) so buttons never overflow off the right edge.
  - Create a dedicated **`256 px` Right-Hand HUD Sidebar (`x = 1012..1268`)** completely outside the Arena floor (`ARENA_MAX_BOUNDS.x = 972.0`) housing the **Dungeon Minimap**, **Bounty Board Tracker**, **Combat Telemetry & DPS Meter**, and **Citadel Hotkeys Legend** with zero overlap over the map, Merchant, doors, or enemies.
  - Clamp East/West/North/South door labels, Enemy/Boss overhead labels, and Character Sheet HUD header/inventory labels (`OVERRUN_TRIM_ELLIPSIS` & `AUTOWRAP_WORD_SMART`).

## [3.0.0] - 2026-10-25
- Add Live In-Game Combat Telemetry & Rolling 5s DPS Meter Overlay (`record_combat_damage()`, `get_rolling_dps()`, `get_combat_telemetry_summary()`, `toggle_telemetry_overlay()`, `_draw_telemetry_overlay()` via **`[K]` key**, **`"DPS: OFF [K]"` button**, and `"toggle_telemetry_overlay"` / `"get_combat_telemetry"` UDP RPCs) displaying rolling 5s DPS with a live meter bar, Total Damage Dealt, Hits Landed, Max Single Hit, Observed Crit Rate %, Parries, Cover Blocks, Elemental Procs, Spirit Owl Bolts, Gold Earned, and AI Pilot ops.
- Expand headless Godot test suite to 58/58 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.9.0] - 2026-10-25
- Add Companion Familiar Pet (`summon_or_upgrade_familiar()`, `get_familiar_bolt_damage()`, `step_familiar()` via **`[Z]` key**, **`"Familiar: OFF [Z]"` button**, and `"summon_familiar"` / `"step_familiar"` UDP RPCs) summoning a 2-frame animated **Ashen Spirit Owl** (`companion_owl_0.png` / `companion_owl_1.png`, bringing total exported `.png` sprites to 36) that orbits the hero, automatically fires Wisdom-scaled Arcane Bolts at nearby enemies, and swoops out (`220 px` radius) to fetch Gold Coins.
- Expand headless Godot test suite to 56/56 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.8.0] - 2026-10-25
- Add Dark-Fantasy Pixel-Art Title Screen & 4-Hero Pantheon Selector Overlay (`godot_project/scripts/title_screen.gd` attached to `main.tscn`) featuring animated rising cinder/ember particles, twin flickering torch sconces, `ui_crest_emblem.png` shield emblem, 4 interactive Ashen Pantheon Hero Cards (`[1]`–`[4]` with animated hero & weapon previews), and direct launch buttons (`ENTER THE CITADEL (2D ARENA) [ENTER]`, `CONTINUE SAVED RUN [F9]`, and `CHARACTER SHEET & LORE [TAB]`).
- Add `[ESC]` key and `"Title [ESC]"` Arena button to toggle the Title Screen anytime, add `"show_title"` and `"dismiss_title"` UDP RPC commands, export `ui_crest_emblem.png` (`34` total `.png` sprites), and expand headless Godot test suite to 54/54 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.7.0] - 2026-10-25
- Add Dungeon Bounty Board & Quest Log Tracker (`_init_bounties()`, `evaluate_bounty_progress()`, `claim_or_advance_bounties()` via **`[J]` key**, **`"Bounties (T1) [J]"` button**, and `"claim_bounty"` UDP RPC) tracking 3 live dungeon objectives: **Slayer's Contract** (defeat monsters for `+35g` Gold & `+1 Talent Point`), **Aegis Deflector** (parry projectiles with `[F]` for `+30g` Gold & `+1 Healing Elixir`), and **Cartographer's Oath** (explore dungeon rooms for `+40g` Gold & `+1 Guaranteed Relic`), plus a `+50g` & `+1 Talent Point` Tier Clear Bonus when advancing to Tier 2+.
- Add Top-Left Quest & Bounty Tracker Overlay (`_draw_bounty_tracker()`) and wooden `prop_bounty_board.png` sprite in `sprite_art_generator.gd` (bringing total exported `.png` sprites to 33), and expand headless Godot test suite to 52/52 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.6.0] - 2026-10-25
- Add 3-Branch Hero Talent Tree & Level-Up Perk Selection (`invest_talent_point()` via **`[T]` key**, **`"Talent (1) [T]"` button**, and `"invest_talent"` UDP RPC) featuring **Twin-Shot Mastery** (fires 2 parallel projectiles per attack), **Vampiric Strikes** (`+4 HP` per rank life-steal on critical hits and kills), and **Arcane Overcharge** (`-25%` per rank Mana discount on Dash & Ultimates).
- Add Procedural Dungeon Floor Escalation (`descend_dungeon_floor()` via **`[X]` key**, **`"Descend [X]"` button**, and `"descend_floor"` UDP RPC) advancing to `Floor 2`, `Floor 3`... with `+30g` bonus gold, `+1 Talent Point`, `+20 HP / +15 MP` recovery, reset 5-room dungeon floor graph, and scaled monsters.
- Add `prop_stairs.png` spiral stone descent staircase sprite to `sprite_art_generator.gd` (bringing total exported `.png` sprites to 32) and expand headless Godot test suite to 50/50 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.5.0] - 2026-10-25
- Add permanent enemy defeat (`hp = 0`, `alive = false` in all arena modes without auto-respawning) and on-demand enemy respawn (`respawn_enemies()` via **`[R]` key**, **`"Respawn [R]"` button**, and `"respawn_enemies"` UDP RPC).
- Add Procedural Cyclic Floor Spike Traps (`_init_spike_traps()`, `trigger_spike_trap_cycle()`, `step_spike_traps()`, `"trigger_spike_trap"` UDP RPC) toggling every `2.0s` between retracted and armed states and dealing `12` piercing damage to overlapping enemies (`6` armor-mitigated bleed damage to heroes).
- Add Chest Mimic Encounters (`spawn_mimic_chest()`, `Relic Mimic [ELITE]` with `85 HP` awakening on chest interaction and dropping `+45g` Gold Coins plus a guaranteed Relic upon defeat).
- Add `enemy_mimic_0.png`, `enemy_mimic_1.png`, `prop_spike_trap_off.png`, and `prop_spike_trap_on.png` pixel-art sprites to `sprite_art_generator.gd` (bringing total exported `.png` sprites to 31) and expand headless Godot test suite to 48/48 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.4.0] - 2026-10-25
- Add Gold Coin Drop Economy (`spawn_coin_drop()`, `step_coin_drops()`, `+20g` per enemy kill, `+60g` per Boss kill, and `160 px` magnetized coin pickup) and Hooded Dungeon Merchant NPC Shop (`buy_merchant_upgrade()` via `[B]` key, `"Merchant [B]"` button, and `"buy_upgrade"` UDP RPC offering **Ashen Whetstone** `+3 Dmg` for `35g`, **Obsidian Plate** `+15 Max HP` for `40g`, and **Ashen Healing Elixir** `+1 Potion` for `25g`).
- Add `npc_merchant.png` and `prop_coin.png` pixel-art sprites to `sprite_art_generator.gd` (bringing total exported `.png` sprites to 27) and expand headless Godot test suite to 46/46 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.3.0] - 2026-10-25
- Add Elemental Weapon Infusion Stance system (`cycle_elemental_stance()`, `apply_elemental_infusion_on_hit()`, `step_elemental_statuses()` via `[V]` key, `"Infusion: NONE [V]"` button, and `"cycle_stance"` UDP RPC) supporting **Frostbite** (`-35%` enemy chase speed for `3.5s`), **Cinderbrand** (stacking `+5` fire burn DoT every `0.5s`), and **Stormchain** (arcing `50%` chain-lightning damage to a nearby secondary enemy with crackling 4-segment lightning bolt visuals).
- Expand headless Godot test suite to 44/44 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.2.0] - 2026-10-25
- Add Boss Phase 2 Molten Enrage state machine (`check_and_trigger_boss_enrage()`, `_summon_cinder_imps()`, `is_boss_enraged()`, `"trigger_boss_enrage"` UDP RPC) triggered when `Ashen Titan [BOSS]` drops to `<= 50% HP`, boosting Boss chase speed by `+30%`, summoning 2 flanking `Cinder Imp [SUMMON]` minions (`32 HP`, `1.35x` speed), and upgrading Boss ranged attacks from a 3-bolt fan to a **5-Bolt Radial Fireball Nova** (`16` dmg/bolt, `1.15x` velocity).
- Expand headless Godot test suite to 42/42 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.1.0] - 2026-10-25
- Add 5-Room Procedural Dungeon Crawler (`_init_dungeon_floor()`, `enter_dungeon_door()`, `enter_next_unexplored_room()`, `check_door_transition()` via `[N]` key, `"Next Room [N]"` button, walking into doors, or `"enter_door"` / `"next_room"` UDP RPCs) with distinct room types (`Crypt Entry Hall (0,0)`, `Ashen Catacombs (0,-1)`, `Consecrated Sanctuary (-1,0)` with `+1` Healing Elixir restock, `Gilded Relic Vault (0,1)` with `2` guaranteed Relic Chests, and `Throne of the Ashen Titan (1,0)` Boss Room).
- Add 2 pixel-art Stone Archway Doorway sprites (`prop_door_open.png` and `prop_door_locked.png` in `sprite_art_generator.gd`, bringing total exported `.png` sprites to 25) and render a live **Top-Right Dungeon Minimap Overlay** (`_draw_dungeon_minimap()`) in `arena_controller.gd`.
- Expand headless Godot test suite to 40/40 assertions (`godot_project/tests/test_hud_headless.gd`).

## [2.0.0] - 2026-10-25
- Add Dark-Fantasy Pixel-Art Sprite & Dungeon Tile Generator (`godot_project/scripts/sprite_art_generator.gd`) generating 23 Nearest-Neighbor `ImageTexture` assets and exporting `.png` sprite sheets to `godot_project/assets/sprites/` (2-frame animated sprites for all 4 heroes, 3 monsters, and `Ashen Titan [BOSS]`, plus class weapons, carved runic obelisk pillars, treasure chests, and cobblestone dungeon floor tiles).
- Upgrade `arena_controller.gd` renderer from geometric circles/squares to full pixel-art dungeon rendering with tiled cobblestone floors, flickering torch sconces, animated 2-frame hero/enemy/boss sprites, orbiting class weapons, directional pixel-spark particle bursts (`spawn_particle_burst()`, `step_particles()`), and camera screen-shake (`trigger_screen_shake()`).
- Add crisp `56x56` Hero Pixel-Art Portrait (`HeroPortrait`) to `character_sheet_hud.gd` and expand headless Godot test suite to 38/38 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.9.0] - 2026-10-25
- Add Autonomous Tactical Utility AI Auto-Pilot (`[P]` key, `"AI Pilot: OFF [P]"` button, `toggle_ai_pilot()`, `step_ai_pilot()`, and UDP RPC commands `"toggle_ai_pilot"` / `"step_ai_pilot"`) with 7 prioritized combat behaviors (Emergency Potion `<45% HP`, Reflex Arcane Parry, Danger-Zone Mana Dash Evasion, Auto Relic Loot, Class Ultimate Rotation, Composite Kiting/Sanctuary Steering, and Line-of-Sight Target Lock) across `arena_controller.gd` and `command_center_receiver.gd`.
- Expand headless Godot test suite to 36/36 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.8.0] - 2026-10-24
- Add Arcane Parry & Projectile Deflection (`[F]` key, `"Parry [F]"` button, `trigger_arcane_parry()`, `"trigger_parry"` UDP RPC) reflecting incoming enemy Cinder Bolts and Boss Fireballs back at `1.35x` speed and `2x` Critical Damage (`+5 MP`).
- Add Environmental Arena Hazard & Sanctuary Zones (`_init_hazard_zones()`, `step_hazard_zones()` with 2 Molten Cinder Pits dealing `-8 HP` burn DoT to enemies and 1 Sanctuary Shrine restoring `+2 HP / +3 MP` to the hero).
- Add Combo Kill-Streak & Frenzy Multiplier system (`register_combo_hit()`, `is_frenzy_active()`, `get_frenzy_move_speed()`, `+15%` move speed, `+10%` crit chance, and `2x`/`3x` multipliers at 3+/6+ hits).
- Expand headless Godot test suite to 34/34 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.7.0] - 2026-10-24
- Add Enemy Ranged Projectiles (`fire_enemy_projectile_from()`, `step_enemy_projectiles()`, `apply_enemy_projectile_hit()`) and Boss 3-Bolt Fireball Volleys (`Ashen Titan [BOSS]`) with Obsidian Pillar cover interception (`"COVER BLOCK!"`), Mana Dash i-frame dodging (`"DODGED!"`), and `"enemy_fire"` UDP RPC across `arena_controller.gd` and `command_center_receiver.gd`.
- Expand headless Godot test suite to 31/31 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.6.0] - 2026-10-24
- Add rising/fading Floating Combat Text popups (`spawn_floating_text()`, `step_floating_texts()`) and Dexterity/Wisdom-scaled Critical Hit system (`get_calculated_crit_chance()`, `roll_critical_hit()`, `2x` damage multiplier, `"force_crit"` UDP RPC) across `arena_controller.gd` and `command_center_receiver.gd`.
- Expand headless Godot test suite to 29/29 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.5.0] - 2026-10-24
- Add 4 tactical Obsidian Pillars (`_init_obstacles()`), circle-vs-circle entity collision resolution (`resolve_circle_obstacle_collision()`), tangential enemy pursuit sliding, projectile cover interception (`step_projectiles()`), and Line-of-Sight cover detection (`has_line_of_sight()`, `count_enemies_blocked_by_cover()`, overhead `[COVER xN]` indicator) in `arena_controller.gd` and `command_center_receiver.gd`.
- Expand headless Godot test suite to 27/27 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.4.0] - 2026-10-24
- Add interactive Consumable Potions (`[C]` key, HUD & Arena `"Potion [C]"` buttons, and UDP RPC `"use_potion"`) restoring `+25 HP` & `+12 MP`, decrementing inventory stack quantity, removing depleted stacks, and restocking `+1` potion on Boss kills across `character_loader.gd`, `character_sheet_hud.gd`, `arena_controller.gd`, and `command_center_receiver.gd`.
- Expand headless Godot test suite to 25/25 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.3.0] - 2026-10-24
- Add zero-asset procedural DSP retro sound synthesizer (`godot_project/scripts/procedural_sfx.gd` using `AudioStreamGenerator`) with 7 combat cues (`shoot`, `hit`, `dash`, `ultimate`, `relic_loot`, `boss_spawn`, `level_up`) and `[M]` / UDP mute toggle.
- Expand headless Godot test suite to 23/23 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.2.0] - 2026-10-24
- Add 1,000-match Monte Carlo Combat Balance Simulator (`src/combat_simulator.py`) and `godot_run_combat_simulation` MCP tool in `src/godot_mcp_server.py`.
- Expand Python MCP & simulator unit test suite to 7/7 tests (`tests/test_dual_engine_mcp.py`).

## [1.1.0] - 2026-10-24
- Add Arena Relic Chest loot drops (`spawn_relic_chest()`, `collect_nearest_relic_chest()` via `[E]` / proximity / UDP `"loot_relic"`) and passive Inventory Relic Stat Bonuses (`grant_relic_item()`, `get_inventory_bonuses()` boosting Damage, Max HP, and Move Speed) across `character_loader.gd`, `character_sheet_hud.gd`, `arena_controller.gd`, and `command_center_receiver.gd`.
- Expand headless Godot test suite to 21/21 assertions (`godot_project/tests/test_hud_headless.gd`).

## [1.0.0] - 2026-10-24
- Add polymorphic Class Ultimate Abilities (`[Q]` key, `-15 MP`: *Multi-Shot Volley*, *Consecrated Ember Nova*, *Phantom Blade Storm*, *Blighted Spore Quake*) and Boss Wave Encounters (`Ashen Titan [BOSS]` on every 3rd wave) to `arena_controller.gd` and `command_center_receiver.gd`.
- Expand headless Godot test suite to 19/19 assertions (`godot_project/tests/test_hud_headless.gd`).

## [0.9.0] - 2026-10-24
- Add persistent party progression Save/Load (`user://roster_save.json` via `[F5]` / `[F9]` and UDP RPC commands `save_party` / `load_party`) with in-memory roster state caching and Wave Survival High Score persistence across `character_loader.gd`, `character_sheet_hud.gd`, `arena_controller.gd`, and `command_center_receiver.gd`.
- Expand headless Godot test suite to 17/17 assertions (`godot_project/tests/test_hud_headless.gd`).

## [0.8.0] - 2026-10-24
- Add bi-directional UDP Telemetry & RPC Bridge (`godot_project/scripts/command_center_receiver.gd` on port `4242`) and `godot_send_live_command` MCP tool in `src/godot_mcp_server.py`.
- Expand headless Godot test suite to 15/15 assertions (`godot_project/tests/test_hud_headless.gd`) and Python MCP test suite to 5/5 tests (`tests/test_dual_engine_mcp.py`).

## [0.7.0] - 2026-10-24
- Add Wave Survival AI pursuit mode (`[G]`), Mana Dash ability (`[Shift]` / Right-Click with 0.45s i-frames), and Constitution armor mitigation to `arena_controller.gd` and `character_loader.gd`.
- Expand headless Godot test suite to 13/13 assertions (`godot_project/tests/test_hud_headless.gd`).

## [0.6.0] - 2026-10-24
- Add Ashen Pantheon 3-hero pack (`data/characters/ash_knight.json`, `echo_wraith.json`, `rotting_sentinel.json`) synced across Godot 4.4 and Unity 6 with `character_id` deduplication.
- Add 4-Hero Roster Switcher Bar (`Keys 1–4` and HUD buttons) across `character_loader.gd`, `character_sheet_hud.gd`, and `arena_controller.gd`, verified by 10/10 headless Godot tests and 4/4 Python MCP tests.

## [0.5.0] - 2026-10-24
- Add playable 2D Top-Down Ranger Arena (`godot_project/scenes/arena.tscn` and `godot_project/scripts/arena_controller.gd`) with WASD movement, mouse-aimed Longbow projectiles, 3 target dummies, and `[Tab]` mode toggle.
- Expand headless Godot test suite to 8/8 assertions (`godot_project/tests/test_hud_headless.gd`).

## [0.4.0] - 2026-10-24
- Scaffold Unity 6 (`6000.0.23f1`) project (`unity_project/Packages/manifest.json`, `unity_project/ProjectSettings/ProjectVersion.txt`, `UnityBatchmodeBridge.cs`) and install Unity Hub (Free Tier).
- Extend `src/godot_mcp_server.py` with `unity_get_status`, `unity_inspect_project`, `unity_run_batchmode`, and `dual_engine_sync_data` plus unit/chaos tests (`tests/test_dual_engine_mcp.py`).

## [0.3.0] - 2026-10-24
- Add interactive RPG Character Sheet HUD (`godot_project/scenes/character_sheet_hud.tscn` and `godot_project/scripts/character_sheet_hud.gd`) with live HP/Mana bars, attribute modifier calculation, d20 skill checks, level-up mutation, and combat log.
- Upgrade `character_loader.gd` with boundary schema validation, signals, and headless SceneTree test suite (`godot_project/tests/test_hud_headless.gd`).

## [0.2.0] - 2026-10-24
- Connect Godot 4.4.1 (`project.godot`, `scenes/main.tscn`, `icon.svg`) and add Stdio MCP Server (`src/godot_mcp_server.py`).
- Add comprehensive Godot 4.4 & Unity 6 Free Tier capabilities guide (`docs/GODOT_AND_UNITY_CAPABILITIES_GUIDE.md`).

## [0.1.0] - 2026-10-24
- Add Unity C# `CharacterLoader.cs` (`[System.Serializable]` schema) and Godot 4 `character_loader.gd`.
- Add sample `CharacterData.json` and full JSON Schema specification in `docs/`.
