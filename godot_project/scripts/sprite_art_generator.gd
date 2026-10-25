# godot_project/scripts/sprite_art_generator.gd
# Procedural Dark-Fantasy Pixel-Art Sprite, Weapon, Prop & Dungeon Tile Generator.
# Generates crisp Nearest-Neighbor ImageTextures and saves PNG sprite sheets to res://assets/sprites/.
# Connects to: godot_project/scripts/arena_controller.gd, godot_project/scripts/character_sheet_hud.gd
# Created: 2026-10-25

extends RefCounted
class_name SpriteArtGenerator

const SPRITE_DIR: String = "res://assets/sprites"

## Cached ImageTextures keyed by sprite_id ("hero_char_001_0", "enemy_boss_0", "pillar", "chest", "floor_tile", etc.)
var textures: Dictionary = {}
var png_files_written: int = 0


func _init() -> void:
	build_all_sprites(true)


## Builds all pixel-art textures in memory and optionally exports PNG files to res://assets/sprites/.
func build_all_sprites(save_to_disk: bool = true) -> void:
	if save_to_disk:
		var abs_dir := ProjectSettings.globalize_path(SPRITE_DIR)
		DirAccess.make_dir_recursive_absolute(abs_dir)

	# 1. Hero 2-frame animated pixel-art sprites (16x16 grids)
	_register_pattern("hero_char_001_0", _HERO_KAELEN_F0, _PALETTE_KAELEN, save_to_disk)
	_register_pattern("hero_char_001_1", _HERO_KAELEN_F1, _PALETTE_KAELEN, save_to_disk)
	_register_pattern("hero_ash_001_0", _HERO_MALAKOR_F0, _PALETTE_MALAKOR, save_to_disk)
	_register_pattern("hero_ash_001_1", _HERO_MALAKOR_F1, _PALETTE_MALAKOR, save_to_disk)
	_register_pattern("hero_ash_002_0", _HERO_VESPERA_F0, _PALETTE_VESPERA, save_to_disk)
	_register_pattern("hero_ash_002_1", _HERO_VESPERA_F1, _PALETTE_VESPERA, save_to_disk)
	_register_pattern("hero_ash_003_0", _HERO_GORVATH_F0, _PALETTE_GORVATH, save_to_disk)
	_register_pattern("hero_ash_003_1", _HERO_GORVATH_F1, _PALETTE_GORVATH, save_to_disk)

	# 2. Enemy & Boss 2-frame animated pixel-art sprites
	_register_pattern("enemy_scout_0", _ENEMY_SCOUT_F0, _PALETTE_SCOUT, save_to_disk)
	_register_pattern("enemy_scout_1", _ENEMY_SCOUT_F1, _PALETTE_SCOUT, save_to_disk)
	_register_pattern("enemy_stalker_0", _ENEMY_STALKER_F0, _PALETTE_STALKER, save_to_disk)
	_register_pattern("enemy_stalker_1", _ENEMY_STALKER_F1, _PALETTE_STALKER, save_to_disk)
	_register_pattern("enemy_sentinel_0", _ENEMY_SENTINEL_F0, _PALETTE_SENTINEL, save_to_disk)
	_register_pattern("enemy_sentinel_1", _ENEMY_SENTINEL_F1, _PALETTE_SENTINEL, save_to_disk)
	_register_pattern("enemy_boss_0", _ENEMY_BOSS_F0, _PALETTE_BOSS, save_to_disk)
	_register_pattern("enemy_boss_1", _ENEMY_BOSS_F1, _PALETTE_BOSS, save_to_disk)
	_register_pattern("enemy_mimic_0", _ENEMY_MIMIC_F0, _PALETTE_MIMIC, save_to_disk)
	_register_pattern("enemy_mimic_1", _ENEMY_MIMIC_F1, _PALETTE_MIMIC, save_to_disk)

	# 3. Environment Props (Runic Obelisk Pillar, Treasure Chest, Dungeon Doors, Traps, Weapons, Dungeon Cobblestone Tile)
	_register_pattern("prop_pillar", _PROP_PILLAR, _PALETTE_PILLAR, save_to_disk)
	_register_pattern("prop_chest", _PROP_CHEST, _PALETTE_CHEST, save_to_disk)
	_register_pattern("prop_door_open", _PROP_DOOR_OPEN, _PALETTE_DOOR, save_to_disk)
	_register_pattern("prop_door_locked", _PROP_DOOR_LOCKED, _PALETTE_DOOR, save_to_disk)
	_register_pattern("prop_spike_trap_off", _PROP_SPIKE_TRAP_OFF, _PALETTE_TRAP, save_to_disk)
	_register_pattern("prop_spike_trap_on", _PROP_SPIKE_TRAP_ON, _PALETTE_TRAP, save_to_disk)
	_register_pattern("npc_merchant", _NPC_MERCHANT, _PALETTE_MERCHANT, save_to_disk)
	_register_pattern("prop_coin", _PROP_COIN, _PALETTE_MERCHANT, save_to_disk)
	_register_pattern("weapon_bow", _WEAPON_BOW, _PALETTE_WEAPON, save_to_disk)
	_register_pattern("weapon_sword", _WEAPON_SWORD, _PALETTE_WEAPON, save_to_disk)
	_register_pattern("weapon_dagger", _WEAPON_DAGGER, _PALETTE_WEAPON, save_to_disk)
	_register_pattern("weapon_maul", _WEAPON_MAUL, _PALETTE_WEAPON, save_to_disk)
	_build_dungeon_floor_tile(save_to_disk)


func get_hero_texture(character_id: String, anim_frame: int = 0) -> Texture2D:
	var f: int = posmod(anim_frame, 2)
	var key := "hero_%s_%d" % [character_id, f]
	if textures.has(key):
		return textures[key]
	return textures.get("hero_char_001_%d" % f, null)


func get_weapon_texture(character_id: String) -> Texture2D:
	match character_id:
		"ash_001":
			return textures.get("weapon_sword", null)
		"ash_002":
			return textures.get("weapon_dagger", null)
		"ash_003":
			return textures.get("weapon_maul", null)
		_:
			return textures.get("weapon_bow", null)


func get_enemy_texture(enemy_name: String, is_boss: bool, anim_frame: int = 0) -> Texture2D:
	var f: int = posmod(anim_frame, 2)
	if is_boss:
		return textures.get("enemy_boss_%d" % f, null)
	if enemy_name.contains("Mimic"):
		return textures.get("enemy_mimic_%d" % f, null)
	if enemy_name.contains("Scout") or enemy_name.contains("Imp"):
		return textures.get("enemy_scout_%d" % f, null)
	if enemy_name.contains("Stalker"):
		return textures.get("enemy_stalker_%d" % f, null)
	return textures.get("enemy_sentinel_%d" % f, null)


func get_prop_texture(prop_key: String) -> Texture2D:
	return textures.get(prop_key, null)


func _register_pattern(key: String, rows: Array[String], palette: Dictionary, save_to_disk: bool) -> void:
	var h: int = rows.size()
	var w: int = rows[0].length() if h > 0 else 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var row_str: String = rows[y]
		for x in range(mini(w, row_str.length())):
			var ch: String = row_str.substr(x, 1)
			if ch != "." and palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	var tex := ImageTexture.create_from_image(img)
	textures[key] = tex
	if save_to_disk:
		var path := "%s/%s.png" % [SPRITE_DIR, key]
		var err := img.save_png(ProjectSettings.globalize_path(path))
		if err == OK:
			png_files_written += 1


func _build_dungeon_floor_tile(save_to_disk: bool) -> void:
	var w := 32
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color(0.11, 0.14, 0.19, 1.0)
	var mortar := Color(0.07, 0.09, 0.13, 1.0)
	var highlight := Color(0.15, 0.19, 0.25, 1.0)
	var moss := Color(0.12, 0.22, 0.18, 1.0)
	img.fill(base)

	for x in range(w):
		img.set_pixel(x, 0, mortar)
		img.set_pixel(x, 16, mortar)
		img.set_pixel(x, 1, highlight)
		img.set_pixel(x, 17, highlight)
	for y in range(h):
		var seam_x := 0 if y < 16 else 16
		img.set_pixel(seam_x, y, mortar)
		img.set_pixel((seam_x + 1) % w, y, highlight)

	# Subtle stone texture speckles and moss accents
	var speckles := [
		Vector2i(5, 5), Vector2i(11, 9), Vector2i(22, 6), Vector2i(27, 12),
		Vector2i(7, 22), Vector2i(14, 27), Vector2i(24, 21), Vector2i(29, 28)
	]
	for pt in speckles:
		img.set_pixel(pt.x, pt.y, highlight)
	img.set_pixel(3, 15, moss)
	img.set_pixel(4, 15, moss)
	img.set_pixel(19, 31, moss)

	textures["floor_tile"] = ImageTexture.create_from_image(img)
	if save_to_disk:
		if img.save_png(ProjectSettings.globalize_path("%s/floor_tile.png" % SPRITE_DIR)) == OK:
			png_files_written += 1


# ============================================================================
# PIXEL-ART PALETTES & 16x16 / 20x20 SPRITE MATRICES
# ============================================================================

const _PALETTE_KAELEN := {
	"O": Color(0.06, 0.08, 0.10), # Dark outline
	"H": Color(0.18, 0.58, 0.34), # Forest hood/cloak
	"L": Color(0.32, 0.82, 0.48), # Emerald highlight
	"F": Color(0.96, 0.80, 0.64), # Elf skin
	"E": Color(0.35, 0.95, 1.00), # Glowing cyan ranger eyes
	"G": Color(0.95, 0.82, 0.32), # Gold trim / quiver
	"B": Color(0.45, 0.28, 0.16), # Leather chest/boots
}

const _HERO_KAELEN_F0: Array[String] = [
	".....OOOOOO.....",
	"....OHLLLLHO....",
	"...OHLLLLLLHO...",
	"..OOHHOOOOHHOO..",
	"..GFHFEFFEFHFG..",
	"...OFFFFFFFFO...",
	"....OOBGGGBOO...",
	"...OHHBBBBBHHO..",
	"..OHLHBBBBBLHHO.",
	"..OHLBBBBBBBLHO.",
	"..OOHHBBBBBHHOO.",
	"...OOHHGGGHHOO..",
	"....OBB..BBO....",
	"....OBB..BBO....",
	"...OOBB..BBOO...",
	"...OOOO..OOOO..."
]

const _HERO_KAELEN_F1: Array[String] = [
	".....OOOOOO.....",
	"....OHLLLLHO....",
	"...OHLLLLLLHO...",
	"..OOHHOOOOHHOO..",
	"..GFHFEFFEFHFG..",
	"...OFFFFFFFFO...",
	"....OOBGGGBOO...",
	"..OOHHBBBBBHHOO.",
	".OHLLHBBBBBLHLHO",
	"..OHLBBBBBBBLHO.",
	"...OHHBBBBBHHO..",
	"....OHHGGGHHO...",
	"...OBB....BBO...",
	"...OOB....BOO...",
	"....OO....OO....",
	"................"
]

const _PALETTE_MALAKOR := {
	"O": Color(0.07, 0.05, 0.06),
	"M": Color(0.48, 0.52, 0.58), # Dark steel plate
	"S": Color(0.75, 0.80, 0.88), # Bright steel highlight
	"R": Color(0.85, 0.22, 0.18), # Crimson ash cloak / plumes
	"E": Color(1.00, 0.68, 0.15), # Molten ember visor
	"G": Color(0.92, 0.72, 0.24), # Gold pauldrons
}

const _HERO_MALAKOR_F0: Array[String] = [
	"..OO...OO...OO..",
	".ORRO.OMMO.ORRO.",
	"..ORROMSSMORRO..",
	"...OOMSSSSMOO...",
	"...OMEEEEEEEMO..",
	"...OMMMMMMMMOO..",
	"..OGGGMMMMGGGO..",
	".ORGGGMSMSGGGRO.",
	".ORRGMMGGMMGRRO.",
	".ORRMMMMMMMMRRO.",
	"..ORRMMMMMMRRO..",
	"..OORRGGGGMMOO..",
	"....OMM..MMO....",
	"....OSM..MSO....",
	"...OOMM..MMOO...",
	"...OOOO..OOOO..."
]

const _HERO_MALAKOR_F1: Array[String] = [
	"..OO...OO...OO..",
	".ORRO.OMMO.ORRO.",
	"..ORROMSSMORRO..",
	"...OOMSSSSMOO...",
	"...OMEEEEEEEMO..",
	"...OMMMMMMMMOO..",
	"..OGGGMMMMGGGO..",
	".ORGGGMSMSGGGRO.",
	"OORRGMMGGMMGRROO",
	".ORRMMMMMMMMRRO.",
	"..OORRMMMMRROO..",
	"...OOMGGGGMOO...",
	"...OMM....MMO...",
	"...OSM....MSO...",
	"...OOO....OOO...",
	"................"
]

const _PALETTE_VESPERA := {
	"O": Color(0.05, 0.04, 0.09),
	"V": Color(0.34, 0.18, 0.52), # Deep shadow cowl
	"P": Color(0.64, 0.36, 0.88), # Wraith violet highlight
	"E": Color(0.38, 0.98, 0.95), # Ethereal cyan eyes
	"D": Color(0.18, 0.14, 0.28), # Dark cloak body
	"S": Color(0.82, 0.88, 0.98), # Silver daggers/clasps
}

const _HERO_VESPERA_F0: Array[String] = [
	".....OOOOOO.....",
	"....OVPPPPVO....",
	"...OVPPPPPPVO...",
	"...OVVDDDDVVO...",
	"...ODDEddEDDO...",
	"....ODDDDDDO....",
	"...OOVSSSSVOO...",
	"..OVVVDDDDVVVO..",
	".OVPPVDDDDVPPVO.",
	".OVPDDDDDDDDPVO.",
	"..OVDDDDDDDDVO..",
	"..OOVVDDDDVVOO..",
	"...OVV.OO.VVO...",
	"..OVP..OO..PVO..",
	"...OO......OO...",
	"................"
]

const _HERO_VESPERA_F1: Array[String] = [
	".....OOOOOO.....",
	"....OVPPPPVO....",
	"...OVPPPPPPVO...",
	"...OVVDDDDVVO...",
	"...ODDEddEDDO...",
	"....ODDDDDDO....",
	"...OOVSSSSVOO...",
	".OOVVVDDDDVVVOO.",
	"OVPPPVDDDDVPPPVO",
	".OVPDDDDDDDDPVO.",
	"..OOVDDDDDDVOO..",
	"...OVVDDDDVVO...",
	"..OVV..OO..VVO..",
	"...OO......OO...",
	"................",
	"................"
]

const _PALETTE_GORVATH := {
	"O": Color(0.05, 0.08, 0.06),
	"G": Color(0.26, 0.48, 0.32), # Rotting moss armor
	"L": Color(0.45, 0.85, 0.42), # Toxic blight glow
	"B": Color(0.82, 0.78, 0.68), # Bone horns / skull pauldrons
	"D": Color(0.18, 0.28, 0.22), # Heavy iron-bark body
}

const _HERO_GORVATH_F0: Array[String] = [
	".OO..OOOOOO..OO.",
	"OBBOOGGGGGGOOBBO",
	".OBBGGGGGGGGBBO.",
	"..OOGGLLLLGGOO..",
	"..OGGLLOOLLGGO..",
	"..OGGGGGGGGGGO..",
	".OBBBGGGGGGGBBO.",
	"OBBGGGGLLGGGGBBO",
	"OBGGGGLLLLGGGGBO",
	"OOGGGGGLLGGGGGOO",
	".OGGGGGGGGGGGGO.",
	"..OOGGDDDDGGOO..",
	"...ODD....DDO...",
	"...ODD....DDO...",
	"..OODD....DDOO..",
	"..OOOO....OOOO.."
]

const _HERO_GORVATH_F1: Array[String] = [
	".OO..OOOOOO..OO.",
	"OBBOOGGGGGGOOBBO",
	".OBBGGGGGGGGBBO.",
	"..OOGGLLLLGGOO..",
	"..OGGLLOOLLGGO..",
	"..OGGGGGGGGGGO..",
	".OBBBGGGGGGGBBO.",
	"OBBGGGGLLGGGGBBO",
	"OBGGGGLLLLGGGGBO",
	".OGGGGGLLGGGGGO.",
	"..OOGGGGGGGGOO..",
	"...OGGDDDDGGO...",
	"..OODD....DDOO..",
	"..OODD....DDOO..",
	"...OOO....OOO...",
	"................"
]

const _PALETTE_SCOUT := {
	"O": Color(0.08, 0.04, 0.04),
	"R": Color(0.82, 0.24, 0.24),
	"H": Color(0.98, 0.48, 0.38),
	"Y": Color(1.00, 0.92, 0.22),
	"D": Color(0.45, 0.14, 0.16),
}

const _ENEMY_SCOUT_F0: Array[String] = [
	"..OO........OO..",
	".OHRO..OO..ORHO.",
	"..ORRORHHHRRRO..",
	"...ORRYYYYRRO...",
	"..ODDRROORRDDO..",
	".ODDRRRRRRRRDDO.",
	"ODDDRRHHHHRRDDDO",
	"OD.ORRRRRRRRO.DO",
	"...OORRRRRROO...",
	"....ORR..RRO....",
	"...OORR..RROO...",
	"...OOOO..OOOO..."
]

const _ENEMY_SCOUT_F1: Array[String] = [
	"....OO....OO....",
	"...OHROOOORHO...",
	"..OORRRHHHRROO..",
	"...ORRYYYYRRO...",
	"ODDDRRROORRRDDDO",
	"ODDDRRRRRRRRDDDO",
	".OOORRHHHHRROOO.",
	"...OORRRRRROO...",
	"....ORRRRRRO....",
	"...ORR....RRO...",
	"...OOO....OOO...",
	"................"
]

const _PALETTE_STALKER := {
	"O": Color(0.06, 0.04, 0.10),
	"P": Color(0.58, 0.28, 0.78),
	"L": Color(0.82, 0.52, 0.98),
	"C": Color(0.35, 0.98, 1.00),
	"D": Color(0.28, 0.14, 0.42),
}

const _ENEMY_STALKER_F0: Array[String] = [
	".....OOOOOO.....",
	"....OPPLLLPO....",
	"...OPPLLLLLPO...",
	"..OOPPDDDDPPOO..",
	"..OPDDCAACDDPO..",
	"...OPDDDDDDPO...",
	"..OOPPLLLLPPOO..",
	".OPPPDDDDDDPPPO.",
	".OPPDDDDDDDDPPO.",
	"..OOPPDDDDPPOO..",
	"...ODP.OO.PDO...",
	"....OO....OO...."
]

const _ENEMY_STALKER_F1: Array[String] = [
	".....OOOOOO.....",
	"....OPPLLLPO....",
	"...OPPLLLLLPO...",
	"..OOPPDDDDPPOO..",
	"..OPDDCAACDDPO..",
	"...OPDDDDDDPO...",
	".OOOPPLLLLPPOOO.",
	"OPPPPDDDDDDPPPPO",
	"..OPPDDDDDDPPO..",
	"...OOPDDDDPOO...",
	"..OO..OOOO..OO..",
	"................"
]

const _PALETTE_SENTINEL := {
	"O": Color(0.05, 0.09, 0.07),
	"G": Color(0.28, 0.65, 0.45),
	"L": Color(0.55, 0.96, 0.65),
	"M": Color(0.38, 0.45, 0.42),
}

const _ENEMY_SENTINEL_F0: Array[String] = [
	"...OOOOOOOOOO...",
	"..OMMGGGGGGMMO..",
	".OMMGGGGGGGGMMO.",
	".OMGGLLLLLLGGMO.",
	".OMGGGGGGGGGGMO.",
	"OMMMGGGLLGGGMMMO",
	"OMMGGGGLLGGGGMMO",
	"OMMGGGGGGGGGGMMO",
	".OOMGGGGGGGGMOO.",
	"..OMMM....MMMO..",
	"..OMMM....MMMO..",
	"..OOOO....OOOO.."
]

const _ENEMY_SENTINEL_F1: Array[String] = [
	"...OOOOOOOOOO...",
	"..OMMGGGGGGMMO..",
	".OMMGGGGGGGGMMO.",
	".OMGGLLLLLLGGMO.",
	".OMGGGGGGGGGGMO.",
	"OMMMGGGLLGGGMMMO",
	"OMMGGGGLLGGGGMMO",
	".OOMGGGGGGGGMOO.",
	"..OMMGGGGGGMMO..",
	".OOMMM....MMMOO.",
	".OOOOO....OOOOO.",
	"................"
]

const _PALETTE_BOSS := {
	"O": Color(0.07, 0.03, 0.02),
	"B": Color(0.95, 0.85, 0.62), # Demon horns / crown
	"R": Color(0.78, 0.22, 0.14), # Titan magma hide
	"F": Color(1.00, 0.68, 0.14), # Molten lava core / cracks
	"Y": Color(1.00, 0.96, 0.35), # Blazing eyes / crown gems
	"D": Color(0.34, 0.12, 0.12), # Obsidian plate armor
}

const _ENEMY_BOSS_F0: Array[String] = [
	".OO..........OO.",
	"OBBO..OOOO..OBBO",
	"OBBBOOBYYBOOBBBO",
	".OOBBBRRRRBBBOO.",
	"..OORRRRRRRROO..",
	"..ORRYYOOYYRRO..",
	"..ORRRRRRRRRRO..",
	".ODDDRFFFFRDDDO.",
	"ODDDRFFYYFFRDDDO",
	"ODDRRFFYYFFRRDDO",
	"ODDRRRRFFRRRRDDO",
	".OODDRRRRRRDDOO.",
	"..ODDDRRRRDDDO..",
	"..ODDO....ODDO..",
	".OODDO....ODDOO.",
	".OOOOO....OOOOO."
]

const _ENEMY_BOSS_F1: Array[String] = [
	".OO..........OO.",
	"OBBO..OOOO..OBBO",
	"OBBBOOBYYBOOBBBO",
	".OOBBBRRRRBBBOO.",
	"..OORRRRRRRROO..",
	"..ORRYYOOYYRRO..",
	"..ORRRRRRRRRRO..",
	"OODDDRFFFFRDDDOO",
	"ODDDRFFYYFFRDDDO",
	"ODDRRFFYYFFRRDDO",
	".OODDRRFFRRDDOO.",
	"..ODDRRRRRRDDO..",
	".OODDDRRRRDDDOO.",
	".ODDO......ODDO.",
	".OOOO......OOOO.",
	"................"
]

const _PALETTE_PILLAR := {
	"O": Color(0.06, 0.08, 0.12),
	"D": Color(0.18, 0.22, 0.30),
	"S": Color(0.32, 0.38, 0.48),
	"L": Color(0.48, 0.56, 0.68),
	"C": Color(0.38, 0.95, 1.00), # Glowing cyan runes
}

const _PROP_PILLAR: Array[String] = [
	"....OOOOOOOO....",
	"..OOSSSSSSSSOO..",
	".OSSLLLLLLLLSSO.",
	".OSDDDDDDDDDDSO.",
	".OSDDCCCCCCDDDS.",
	".OSDDDDCCDDDDDS.",
	".OSDDCCCCCCDDDS.",
	".OSDDDDCCDDDDDS.",
	".OSDDCCCCCCDDDS.",
	".OSDDDDDDDDDDSO.",
	".OSSDDDDDDDDSSO.",
	"..OOSSSSSSSSOO..",
	"...OOOOOOOOOO...",
	"................",
	"................",
	"................"
]

const _PALETTE_CHEST := {
	"O": Color(0.08, 0.05, 0.02),
	"W": Color(0.55, 0.32, 0.14),
	"G": Color(0.98, 0.82, 0.24),
	"Y": Color(1.00, 0.96, 0.65),
}

const _PROP_CHEST: Array[String] = [
	"..OOOOOOOOOOOO..",
	".OGGWWWWWWWWGGO.",
	"OGWWGGGGGGGGWWGO",
	"OGWWWWWWWWWWWWGO",
	"OOOOOOOOOOOOOOOO",
	"OGWWWWGGGGWWWWGO",
	"OGWWWWGYYGWWWWGO",
	"OGWWWWGGGGWWWWGO",
	"OGGWWWWWWWWWWGGO",
	".OOOOOOOOOOOOOO."
]

const _PALETTE_WEAPON := {
	"O": Color(0.06, 0.06, 0.08),
	"W": Color(0.62, 0.38, 0.18),
	"S": Color(0.85, 0.90, 0.98),
	"G": Color(0.98, 0.82, 0.25),
	"C": Color(0.42, 0.96, 1.00),
}

const _WEAPON_BOW: Array[String] = [
	"...OO...",
	"..CSWO..",
	".C..OWO.",
	"C....OWO",
	"C....OWO",
	".C..OWO.",
	"..CSWO..",
	"...OO..."
]

const _WEAPON_SWORD: Array[String] = [
	"......OO",
	".....OSS",
	"....OSSO",
	".OO.OSSO",
	"..OGGSO.",
	"..OWGO..",
	".OWO....",
	"OO......"
]

const _WEAPON_DAGGER: Array[String] = [
	".....OO.",
	"....OSSO",
	"...OCCSO",
	"..OGGSO.",
	".OWO....",
	"OO......",
	"........",
	"........"
]

const _WEAPON_MAUL: Array[String] = [
	"....OOOO",
	"...OSSSO",
	"...OSCSO",
	"...OSSSO",
	"..OGGOOO",
	".OWO....",
	"OWO.....",
	"OO......"
]

const _PALETTE_DOOR := {
	"O": Color(0.06, 0.07, 0.10),
	"S": Color(0.36, 0.42, 0.52),
	"L": Color(0.55, 0.62, 0.74),
	"C": Color(0.28, 0.92, 0.85),
	"B": Color(0.75, 0.98, 1.00),
	"R": Color(0.92, 0.25, 0.28),
	"D": Color(0.14, 0.16, 0.22),
}

const _PROP_DOOR_OPEN: Array[String] = [
	"...OOOOOOOOOO...",
	"..OLLSSSSSSLLO..",
	".OLSSCCCCCCSSLO.",
	"OLSCCBBBBBBCCSLO",
	"OSSCBCCCCCCBCSSO",
	"OSSCBCCCCCCBCSSO",
	"OSSCCCCCCCCCCSSO",
	"OSSCBCCCCCCBCSSO",
	"OSSCBCCCCCCBCSSO",
	"OSSCCCCCCCCCCSSO",
	"OSSCCCCCCCCCCSSO",
	"OOOOOOOOOOOOOOOO"
]

const _PROP_DOOR_LOCKED: Array[String] = [
	"...OOOOOOOOOO...",
	"..OLLSSSSSSLLO..",
	".OLSSDDDDDDSSLO.",
	"OLSDRODRORODSLOO",
	"OSSDRODRORODSSOO",
	"OSSRRRRRRRRRSSOO",
	"OSSDRODRORODSSOO",
	"OSSDRODRORODSSOO",
	"OSSRRRRRRRRRSSOO",
	"OSSDRODRORODSSOO",
	"OSSDRODRORODSSOO",
	"OOOOOOOOOOOOOOOO"
]

const _PALETTE_MERCHANT := {
	"O": Color(0.06, 0.05, 0.08),
	"R": Color(0.45, 0.22, 0.58),
	"D": Color(0.28, 0.14, 0.38),
	"G": Color(0.98, 0.82, 0.24),
	"Y": Color(1.00, 0.96, 0.62),
	"C": Color(0.42, 0.98, 0.88),
	"W": Color(0.58, 0.36, 0.18),
}

const _NPC_MERCHANT: Array[String] = [
	".....OOOOOO.....",
	"....ORRRRRRO....",
	"...ORRRRRRRRO...",
	"...ORDOOOODRO...",
	"...ORDYOOYDRO...",
	"...ORDDDDDDRO...",
	"..OOGGRRRRGGOWO.",
	".ORRRRRRRRRROWYO",
	".ORRGGRRRRGGOWYO",
	".ORRRRRRRRRROOO.",
	"..ODRRRRRRRRDO..",
	"..ODDDDDDDDDDO..",
	"...OOWW..WWOO...",
	"...OOWW..WWOO...",
	"...OOOO..OOOO...",
	"................"
]

const _PROP_COIN: Array[String] = [
	"..OOOO..",
	".OGYYGO.",
	"OGYGGYGO",
	"OGYGGYGO",
	"OGGGGGGO",
	".OGGGGO.",
	"..OOOO..",
	"........"
]

const _PALETTE_MIMIC := {
	"O": Color(0.08, 0.04, 0.03),
	"W": Color(0.48, 0.24, 0.12), # Dark mimic oak
	"G": Color(0.95, 0.78, 0.22), # Gold trim
	"F": Color(0.98, 0.96, 0.88), # Jagged ivory fangs
	"R": Color(0.98, 0.22, 0.28), # Glowing crimson eyes
	"T": Color(0.85, 0.25, 0.68), # Lashing mimic tongue
	"M": Color(0.24, 0.06, 0.10), # Dark maw interior
}

const _ENEMY_MIMIC_F0: Array[String] = [
	"..OOOOOOOOOOOO..",
	".OGGWWWWWWWWGGO.",
	"OGWWRRWWWWWRRWGO",
	"OGWWWWWWWWWWWWGO",
	"OOFMFMFMFMFMFMOO",
	"OMFMMTTTTTTMMFMO",
	"OMFMFTTTTTTFMFMO",
	"OOGWWWWWWWWWWGOO",
	"OGWWGGGGGGGGWWGO",
	"OGGWWWWWWWWWWGGO",
	".OOOOOOOOOOOOOO.",
	"................"
]

const _ENEMY_MIMIC_F1: Array[String] = [
	".OOOOOOOOOOOOOO.",
	"OGGWWWWWWWWWWGGO",
	"OGWWRRWWWWWRRWGO",
	"OOFMFMFMFMFMFMOO",
	"OMMMMMMMMMMMMMMO",
	"OMMMTTTTTTTTMMMO",
	"OMFMFTTTTTTFMFMO",
	"OOFMFMFMFMFMFMOO",
	"OGWWGGGGGGGGWWGO",
	"OGGWWWWWWWWWWGGO",
	".OOOWW....WWOOO.",
	"....OO....OO...."
]

const _PALETTE_TRAP := {
	"O": Color(0.06, 0.07, 0.09),
	"D": Color(0.16, 0.19, 0.24), # Recessed iron plate
	"M": Color(0.32, 0.36, 0.44), # Metal rim
	"S": Color(0.84, 0.89, 0.96), # Gleaming steel spike
	"R": Color(0.92, 0.22, 0.24), # Blood-tipped spike point
}

const _PROP_SPIKE_TRAP_OFF: Array[String] = [
	"..OOOOOOOOOOOO..",
	".OMMDDDDDDDDMMO.",
	"OMDDODDOODDODDMO",
	"OMDOOODOODOOODMO",
	"OMDDODDOODDODDMO",
	"OMDDDDDDDDDDDDMO",
	"OMDDODDOODDODDMO",
	"OMDOOODOODOOODMO",
	"OMDDODDOODDODDMO",
	"OMDDDDDDDDDDDDMO",
	".OMMDDDDDDDDMMO.",
	"..OOOOOOOOOOOO.."
]

const _PROP_SPIKE_TRAP_ON: Array[String] = [
	"..OORRO..OORRO..",
	".OMRSSO..OSSRMO.",
	"OMDSSSOOOOSSSDMO",
	"OMDDSSOOOOSSDDMO",
	"OMRROOORROOORRMO",
	"OMSSO.OSSO.OSSMO",
	"OMSSOOOSSOOOSSMO",
	"OMDDSSO..OSSDDMO",
	"OMDDSSO..OSSDDMO",
	"OMDDDDDDDDDDDDMO",
	".OMMDDDDDDDDMMO.",
	"..OOOOOOOOOOOO.."
]
