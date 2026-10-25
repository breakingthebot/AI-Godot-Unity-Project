# godot_project/scripts/procedural_sfx.gd
# Zero-asset procedural DSP retro sound synthesizer using AudioStreamGenerator.
# Connects to: godot_project/scenes/main.tscn, godot_project/scripts/arena_controller.gd, godot_project/scripts/character_sheet_hud.gd
# Created: 2026-10-24

extends Node
class_name ProceduralSfx

## Emitted whenever a procedural sound cue is synthesized (or suppressed while muted).
signal sfx_played(cue_name: String, details: Dictionary)

## Emitted when audio mute state changes ([M] key or RPC).
signal mute_toggled(is_muted: bool)

const MIX_RATE: float = 22050.0
const BUFFER_LENGTH_SEC: float = 0.35

const CUE_PRESETS: Dictionary = {
	"shoot": {
		"freq_start": 680.0,
		"freq_end": 220.0,
		"duration": 0.07,
		"volume": 0.28,
		"waveform": "square_sweep"
	},
	"hit": {
		"freq_start": 195.0,
		"freq_end": 72.0,
		"duration": 0.08,
		"volume": 0.34,
		"waveform": "sine_thud"
	},
	"dash": {
		"freq_start": 310.0,
		"freq_end": 890.0,
		"duration": 0.11,
		"volume": 0.30,
		"waveform": "phase_whoosh"
	},
	"ultimate": {
		"freq_start": 440.0,
		"freq_end": 880.0,
		"duration": 0.22,
		"volume": 0.38,
		"waveform": "power_arpeggio"
	},
	"relic_loot": {
		"freq_start": 523.25,
		"freq_end": 1046.50,
		"duration": 0.20,
		"volume": 0.35,
		"waveform": "gold_chime"
	},
	"boss_spawn": {
		"freq_start": 110.0,
		"freq_end": 82.41,
		"duration": 0.26,
		"volume": 0.42,
		"waveform": "boss_horn"
	},
	"level_up": {
		"freq_start": 440.0,
		"freq_end": 880.0,
		"duration": 0.24,
		"volume": 0.34,
		"waveform": "fanfare"
	}
}

var muted: bool = false
var total_sfx_played: int = 0
var last_cue_name: String = ""
var last_samples_generated: int = 0
var cue_counts: Dictionary = {}

var _player: AudioStreamPlayer = null
var _generator: AudioStreamGenerator = null


func _ready() -> void:
	_setup_audio_generator()


func _setup_audio_generator() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = MIX_RATE
	_generator.buffer_length = BUFFER_LENGTH_SEC

	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralAudioPlayer"
	_player.stream = _generator
	add_child(_player)
	_player.play()


## Toggles procedural audio mute state on/off ([M] key).
func toggle_mute() -> bool:
	muted = not muted
	mute_toggled.emit(muted)
	return muted


## Synthesizes and plays a procedural retro sound effect cue by name.
func play_cue(cue_name: String) -> Dictionary:
	var key := cue_name.to_lower().strip_edges()
	var preset: Dictionary = CUE_PRESETS.get(key, CUE_PRESETS["shoot"])

	if muted:
		var muted_res := {
			"status": "muted",
			"cue": key,
			"samples_generated": 0
		}
		sfx_played.emit(key, muted_res)
		return muted_res

	var duration: float = float(preset.get("duration", 0.08))
	var freq_start: float = float(preset.get("freq_start", 440.0))
	var freq_end: float = float(preset.get("freq_end", 220.0))
	var volume: float = float(preset.get("volume", 0.30))
	var waveform: String = str(preset.get("waveform", "sine_thud"))

	var frames := _synthesize_waveform(freq_start, freq_end, duration, volume, waveform)
	var sample_count: int = frames.size()

	# Push synthesized stereo frames to AudioStreamGeneratorPlayback if audio hardware is active
	if _player != null:
		if not _player.playing:
			_player.play()
		var playback := _player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback != null:
			var available: int = playback.get_frames_available()
			var push_limit: int = mini(sample_count, available)
			for i in range(push_limit):
				playback.push_frame(frames[i])

	total_sfx_played += 1
	last_cue_name = key
	last_samples_generated = sample_count
	cue_counts[key] = int(cue_counts.get(key, 0)) + 1

	var res := {
		"status": "played",
		"cue": key,
		"waveform": waveform,
		"samples_generated": sample_count,
		"total_sfx_played": total_sfx_played
	}
	sfx_played.emit(key, res)
	return res


## Generates a PackedVector2Array of stereo PCM audio samples for the requested cue preset.
func _synthesize_waveform(
	freq_start: float,
	freq_end: float,
	duration: float,
	volume: float,
	waveform: String
) -> PackedVector2Array:
	var total_frames: int = maxi(16, int(round(duration * MIX_RATE)))
	var buffer := PackedVector2Array()
	buffer.resize(total_frames)

	var phase: float = 0.0
	for i in range(total_frames):
		var t: float = float(i) / float(total_frames)
		var env: float = clampf(1.0 - t, 0.0, 1.0)
		var freq: float = lerpf(freq_start, freq_end, t)

		if waveform == "power_arpeggio" or waveform == "gold_chime" or waveform == "fanfare":
			# 4-step ascending arpeggio notes
			var step_idx: int = int(floor(t * 4.0))
			var mults := [1.0, 1.25, 1.5, 2.0]
			freq = freq_start * float(mults[clampi(step_idx, 0, 3)])

		phase = fmod(phase + (freq / MIX_RATE), 1.0)
		var raw_sample: float = sin(phase * TAU)

		if waveform == "square_sweep" or waveform == "boss_horn":
			raw_sample = (1.0 if raw_sample >= 0.0 else -1.0) * 0.65 + raw_sample * 0.35
		elif waveform == "phase_whoosh":
			raw_sample = sin(phase * TAU) * 0.7 + sin(phase * TAU * 2.7) * 0.3

		var amp: float = raw_sample * env * volume
		buffer[i] = Vector2(amp, amp)

	return buffer
