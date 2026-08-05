extends Node2D

const VIEW_SIZE := Vector2(960.0, 540.0)
const ARENA_CENTER := Vector2(480.0, 270.0)
const ARENA_RADIUS := 235.0
const PLAYER_START := Vector2(500.0, 270.0)
const ENEMY_SPAWN := Vector2(565.0, 270.0)
const BACKGROUND_COLOR := Color("18242c")
const ARENA_COLOR := Color("111a21")
const ARENA_RING_COLOR := Color(0.0, 0.898, 0.816, 0.22)
const JUICE: JuiceTuning = preload("res://tuning/juice.tres")

@onready var player: PlayerController = $Player
@onready var enemy_pool: EnemyPool = $EnemyPool
@onready var combat: CombatSystem = $Combat
@onready var hitstop: Hitstop = $Hitstop
@onready var camera_shake: DirectionalCameraShake = $CameraShake
@onready var audio_hit: LayeredHitAudio = $AudioHit
@onready var combo: ComboSystem = $Combo
@onready var tuning_overlay: TuningOverlay = $TuningOverlay


func _ready() -> void:
	player.position = PLAYER_START
	enemy_pool.configure(JUICE, ENEMY_SPAWN)
	combo.configure(JUICE)
	audio_hit.configure(JUICE)
	combat.configure(JUICE, enemy_pool, hitstop, camera_shake, audio_hit, combo)
	player.configure(JUICE, combat, hitstop, combo, ARENA_CENTER, ARENA_RADIUS)
	tuning_overlay.configure(JUICE, hitstop)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-40.0, -40.0), VIEW_SIZE + Vector2(80.0, 80.0)), BACKGROUND_COLOR)
	draw_circle(ARENA_CENTER, ARENA_RADIUS, ARENA_COLOR)
	draw_arc(ARENA_CENTER, ARENA_RADIUS, 0.0, TAU, 128, ARENA_RING_COLOR, 3.0, true)
	draw_arc(ARENA_CENTER, ARENA_RADIUS - 11.0, 0.0, TAU, 128, Color(0.0, 0.898, 0.816, 0.06), 2.0, true)
