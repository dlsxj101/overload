extends Node2D

const VIEW_SIZE := Vector2(960.0, 540.0)
const ARENA_CENTER := Vector2(480.0, 270.0)
const ARENA_RADIUS := 235.0
const PLAYER_START := Vector2(500.0, 270.0)
const ENEMY_SPAWN := Vector2(565.0, 270.0)
const BACKGROUND_COLOR := Color("18242c")
const ARENA_COLOR := Color("111a21")
const ARENA_RING_COLOR := Color(0.0, 0.898, 0.816, 0.22)
const G0_GOLDEN_ANGLE_RADIANS := PI * (3.0 - sqrt(5.0))
const JUICE: JuiceTuning = preload("res://tuning/juice.tres")

@onready var player: PlayerController = $Player
@onready var enemy_pool: EnemyPool = $EnemyPool
@onready var combat: CombatSystem = $Combat
@onready var hitstop: Hitstop = $Hitstop
@onready var camera_shake: DirectionalCameraShake = $CameraShake
@onready var audio_hit: LayeredHitAudio = $AudioHit
@onready var combo: ComboSystem = $Combo
@onready var instructions: Label = $Instructions
@onready var tuning_overlay: TuningOverlay = $TuningOverlay
@onready var g0_profiler: G0Profiler = $G0Profiler

var _g0_world_render_enabled := true


func _ready() -> void:
	player.position = PLAYER_START
	enemy_pool.configure(JUICE, [ENEMY_SPAWN])
	combo.configure(JUICE)
	audio_hit.configure(JUICE)
	combat.configure(JUICE, enemy_pool, hitstop, camera_shake, audio_hit, combo)
	player.configure(JUICE, combat, hitstop, combo, ARENA_CENTER, ARENA_RADIUS)
	tuning_overlay.configure(JUICE, hitstop)
	g0_profiler.configure(self, player, enemy_pool, combat, camera_shake, combo)
	queue_redraw()


func _draw() -> void:
	if not _g0_world_render_enabled:
		return
	draw_rect(Rect2(Vector2(-40.0, -40.0), VIEW_SIZE + Vector2(80.0, 80.0)), BACKGROUND_COLOR)
	draw_circle(ARENA_CENTER, ARENA_RADIUS, ARENA_COLOR)
	draw_arc(ARENA_CENTER, ARENA_RADIUS, 0.0, TAU, 128, ARENA_RING_COLOR, 3.0, true)
	draw_arc(ARENA_CENTER, ARENA_RADIUS - 11.0, 0.0, TAU, 128, Color(0.0, 0.898, 0.816, 0.06), 2.0, true)


func set_g0_tuning_overlay_enabled(enabled: bool) -> void:
	if enabled:
		if is_instance_valid(tuning_overlay):
			return
		tuning_overlay = TuningOverlay.new()
		tuning_overlay.name = "TuningOverlay"
		tuning_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(tuning_overlay)
		tuning_overlay.configure(JUICE, hitstop)
		return
	if not is_instance_valid(tuning_overlay):
		return
	var overlay_to_free := tuning_overlay
	tuning_overlay = null
	overlay_to_free.free()


func set_g0_blank_baseline_enabled(enabled: bool) -> void:
	_g0_world_render_enabled = not enabled
	player.visible = not enabled
	combat.visible = not enabled
	instructions.visible = not enabled
	queue_redraw()


func set_g0_enemy_count(count: int) -> void:
	var spawn_points: Array[Vector2] = []
	var safe_count := maxi(1, count)
	var minimum_radius := (ENEMY_SPAWN - ARENA_CENTER).length()
	var maximum_radius := ARENA_RADIUS - EnemyPool.ENEMY_RADIUS
	for index in safe_count:
		if index == 0:
			spawn_points.append(ENEMY_SPAWN)
			continue
		var normalized_index := float(index) / float(maxi(safe_count - 1, 1))
		var radius := lerpf(minimum_radius, maximum_radius, sqrt(normalized_index))
		var angle := float(index) * G0_GOLDEN_ANGLE_RADIANS
		spawn_points.append(ARENA_CENTER + Vector2.from_angle(angle) * radius)
	enemy_pool.configure(JUICE, spawn_points)
