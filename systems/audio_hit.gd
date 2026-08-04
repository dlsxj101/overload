class_name LayeredHitAudio
extends Node

const PITCH_MIN := 0.92
const PITCH_MAX := 1.08
const VOICE_COUNT := 4

const BLADE_VARIANTS: Array[AudioStream] = [
	preload("res://audio/hit/blade_01.ogg"),
	preload("res://audio/hit/blade_02.ogg"),
	preload("res://audio/hit/blade_03.ogg"),
]
const BODY_VARIANTS: Array[AudioStream] = [
	preload("res://audio/hit/body_01.ogg"),
	preload("res://audio/hit/body_02.ogg"),
	preload("res://audio/hit/body_03.ogg"),
]
const TAIL_VARIANTS: Array[AudioStream] = [
	preload("res://audio/hit/tail_01.ogg"),
	preload("res://audio/hit/tail_02.ogg"),
	preload("res://audio/hit/tail_03.ogg"),
]

var _blade_players: Array[AudioStreamPlayer] = []
var _body_players: Array[AudioStreamPlayer] = []
var _tail_players: Array[AudioStreamPlayer] = []
var _voice_index := 0
var _blade_variant_index := 0
var _body_variant_index := 0
var _tail_variant_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blade_players = _create_pool("Blade", -3.0)
	_body_players = _create_pool("Body", -1.0)
	_tail_players = _create_pool("Tail", -5.0)


func play_hit() -> void:
	_play_layer(_blade_players[_voice_index], BLADE_VARIANTS, _blade_variant_index)
	_play_layer(_body_players[_voice_index], BODY_VARIANTS, _body_variant_index)
	_play_layer(_tail_players[_voice_index], TAIL_VARIANTS, _tail_variant_index)
	_blade_variant_index = (_blade_variant_index + 1) % BLADE_VARIANTS.size()
	_body_variant_index = (_body_variant_index + 1) % BODY_VARIANTS.size()
	_tail_variant_index = (_tail_variant_index + 1) % TAIL_VARIANTS.size()
	_voice_index = (_voice_index + 1) % VOICE_COUNT


func _create_pool(prefix: String, volume_db: float) -> Array[AudioStreamPlayer]:
	var pool: Array[AudioStreamPlayer] = []
	for player_index in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "%sVoice%d" % [prefix, player_index + 1]
		player.volume_db = volume_db
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		pool.append(player)
	return pool


func _play_layer(player: AudioStreamPlayer, variants: Array[AudioStream], variant_index: int) -> void:
	player.stream = variants[variant_index]
	player.pitch_scale = randf_range(PITCH_MIN, PITCH_MAX)
	player.play()
