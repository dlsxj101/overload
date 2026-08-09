class_name G0Profiler
extends CanvasLayer

const UI_FONT: Font = preload("res://fonts/BlackHanSans-Regular.ttf")
const PANEL_POSITION := Vector2(500.0, 12.0)
const PANEL_SIZE := Vector2(448.0, 516.0)
const PANEL_UPDATE_INTERVAL_SECONDS := 0.25
const RECENT_WINDOW_USEC := 1_000_000
const CAPTURE_DURATION_USEC := 30_000_000
const ENEMY_COUNT_PRESETS := [1, 10, 50, 100, 150]
const HISTOGRAM_BOUNDS_MS := [8.0, 13.0, 16.7, 25.0, 33.3]

var _main: Node
var _player: PlayerController
var _enemy_pool: EnemyPool
var _combat: CombatSystem
var _camera_shake: DirectionalCameraShake
var _combo: ComboSystem
var _panel: PanelContainer
var _label: Label
var _panel_update_elapsed := PANEL_UPDATE_INTERVAL_SECONDS
var _recent_frame_times_ms: Array[float] = []
var _recent_frame_timestamps_usec: Array[int] = []
var _current_frame_time_ms := 0.0
var _player_redraw_enabled := true
var _enemy_render_enabled := true
var _saturation_node_enabled := true
var _f1_tree_enabled := true
var _camera_shake_enabled := true
var _combo_layer_enabled := true
var _combat_effects_enabled := true
var _blank_baseline_enabled := false
var _enemy_count_preset_index := 0
var _forced_tier := -1
var _capture_active := false
var _capture_started_usec := 0
var _capture_frame_times_ms: Array[float] = []
var _capture_process_ms_total := 0.0
var _capture_physics_ms_total := 0.0
var _capture_draw_calls_total := 0.0
var _capture_render_objects_total := 0.0
var _capture_primitives_total := 0.0
var _capture_node_count_total := 0.0
var _capture_static_memory_total := 0.0
var _last_result: Dictionary = {}
var _g0_js_control_callback: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110


func configure(
	main_node: Node,
	player: PlayerController,
	enemy_pool: EnemyPool,
	combat: CombatSystem,
	camera_shake: DirectionalCameraShake,
	combo: ComboSystem
) -> void:
	_main = main_node
	_player = player
	_enemy_pool = enemy_pool
	_combat = combat
	_camera_shake = camera_shake
	_combo = combo
	_build_interface()
	if OS.has_feature("web"):
		_g0_js_control_callback = JavaScriptBridge.create_callback(_on_javascript_control)
		var javascript_window := JavaScriptBridge.get_interface("window")
		javascript_window.__g0Control = _g0_js_control_callback
		JavaScriptBridge.eval(
			"window.__g0InputReady=performance.now();window.__g0ResultCounter=0;",
			true
		)
	_refresh_panel()


func _process(delta: float) -> void:
	if _main == null:
		return
	_current_frame_time_ms = delta * 1000.0
	var now_usec := Time.get_ticks_usec()
	_recent_frame_times_ms.append(_current_frame_time_ms)
	_recent_frame_timestamps_usec.append(now_usec)
	while not _recent_frame_timestamps_usec.is_empty() \
	and now_usec - _recent_frame_timestamps_usec[0] > RECENT_WINDOW_USEC:
		_recent_frame_timestamps_usec.pop_front()
		_recent_frame_times_ms.pop_front()

	if _capture_active:
		_capture_sample()
		if now_usec - _capture_started_usec >= CAPTURE_DURATION_USEC:
			_finish_capture(now_usec)

	if _panel == null or not _panel.visible:
		return
	_panel_update_elapsed += delta
	if _panel_update_elapsed < PANEL_UPDATE_INTERVAL_SECONDS:
		return
	_panel_update_elapsed = 0.0
	_refresh_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or _main == null:
		return
	if not _handle_keycode(event.keycode):
		return
	_refresh_panel()
	get_viewport().set_input_as_handled()


func _handle_keycode(keycode: Key) -> bool:
	match keycode:
		KEY_F2:
			_panel.visible = not _panel.visible
			_panel_update_elapsed = PANEL_UPDATE_INTERVAL_SECONDS
		KEY_1:
			_set_player_redraw_enabled(not _player_redraw_enabled)
		KEY_2:
			_set_enemy_render_enabled(not _enemy_render_enabled)
		KEY_3:
			_set_saturation_node_enabled(not _saturation_node_enabled)
		KEY_4:
			_set_f1_tree_enabled(not _f1_tree_enabled)
		KEY_5:
			_set_camera_shake_enabled(not _camera_shake_enabled)
		KEY_6:
			_set_combo_layer_enabled(not _combo_layer_enabled)
		KEY_7:
			_set_combat_effects_enabled(not _combat_effects_enabled)
		KEY_0:
			_set_all_enabled(_blank_baseline_enabled)
		KEY_N:
			_set_enemy_count_preset(_enemy_count_preset_index + 1)
		KEY_M:
			_set_enemy_count_preset(_enemy_count_preset_index - 1)
		KEY_T:
			_set_forced_tier(4 if _combo.current_tier != 4 else 0)
		KEY_R:
			if not _capture_active:
				_start_capture()
			else:
				_cancel_capture()
		_:
			return false
	return true


func _on_javascript_control(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var command := str(arguments[0]).to_upper()
	JavaScriptBridge.eval(
		"window.__g0ControlSeen=(window.__g0ControlSeen||0)+1;window.__g0LastControl='%s';" % command,
		true
	)
	var keycode := KEY_NONE
	match command:
		"F2": keycode = KEY_F2
		"0": keycode = KEY_0
		"1": keycode = KEY_1
		"2": keycode = KEY_2
		"3": keycode = KEY_3
		"4": keycode = KEY_4
		"5": keycode = KEY_5
		"6": keycode = KEY_6
		"7": keycode = KEY_7
		"N": keycode = KEY_N
		"M": keycode = KEY_M
		"T": keycode = KEY_T
		"R": keycode = KEY_R
		_:
			return
	_handle_keycode(keycode)
	_refresh_panel()


func _build_interface() -> void:
	_panel = PanelContainer.new()
	_panel.name = "G0ProfilePanel"
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	_panel.visible = false
	var panel_theme := Theme.new()
	panel_theme.default_font = UI_FONT
	panel_theme.default_font_size = 13
	_panel.theme = panel_theme
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	_label = Label.new()
	_label.name = "ProfileText"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	margin.add_child(_label)


func _refresh_panel() -> void:
	if _label == null:
		return
	var recent_average := _average(_recent_frame_times_ms)
	var recent_maximum := _maximum(_recent_frame_times_ms)
	var recent_p99 := _percentile_99(_recent_frame_times_ms)
	var low_fps := _one_percent_low_fps(_recent_frame_times_ms)
	var capture_text := "측정 없음"
	if _capture_active:
		var elapsed := float(Time.get_ticks_usec() - _capture_started_usec) / 1_000_000.0
		capture_text = "측정 중 %.1f / 30.0초" % elapsed
	elif not _last_result.is_empty():
		capture_text = "마지막 %.2fms | p99 %.2fms" % [
			float(_last_result["frame_average_ms"]),
			float(_last_result["frame_p99_ms"]),
		]
	_label.text = "G0 웹 성능 프로파일 | F2 닫기\n" \
	+ "R 30초 측정 | T 티어0/4 | N/M 적 수\n\n" \
	+ "프레임  현재 %.2fms | 1초 평균 %.2fms\n" % [_current_frame_time_ms, recent_average] \
	+ "1초 최대 %.2fms | p99 %.2fms | 1%% low %.1fFPS\n" % [recent_maximum, recent_p99, low_fps] \
	+ "process %.3fms | physics %.3fms\n" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	] \
	+ "render object %d | draw call %d | primitive %d\n" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	] \
	+ "node %d | static memory %.2fMiB\n" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1_048_576.0,
	] \
	+ "적 %d | 티어 %d | %s\n\n" % [_enemy_pool.positions.size(), _combo.current_tier, capture_text] \
	+ "1 Player redraw       %s\n" % _state_text(_player_redraw_enabled) \
	+ "2 적 render           %s\n" % _state_text(_enemy_render_enabled) \
	+ "3 채도 node           %s\n" % _state_text(_saturation_node_enabled) \
	+ "4 F1 node tree        %s\n" % _state_text(_f1_tree_enabled) \
	+ "5 camera shake        %s\n" % _state_text(_camera_shake_enabled) \
	+ "6 combo layer         %s\n" % _state_text(_combo_layer_enabled) \
	+ "7 combat effects      %s\n" % _state_text(_combat_effects_enabled) \
	+ "0 blank baseline      %s\n" % _state_text(_blank_baseline_enabled) \
	+ "히스토그램(ms) %s" % _histogram_text(_recent_frame_times_ms)


func _set_player_redraw_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_player_redraw_enabled = enabled
	_player.set_g0_continuous_redraw_enabled(enabled)


func _set_enemy_render_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_enemy_render_enabled = enabled
	_enemy_pool.set_g0_render_enabled(enabled)


func _set_saturation_node_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_saturation_node_enabled = enabled
	_combo.set_g0_saturation_node_enabled(enabled)


func _set_f1_tree_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_f1_tree_enabled = enabled
	_main.set_g0_tuning_overlay_enabled(enabled)


func _set_camera_shake_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_camera_shake_enabled = enabled
	_camera_shake.set_g0_enabled(enabled)


func _set_combo_layer_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_combo_layer_enabled = enabled
	_combo.set_g0_combo_layer_enabled(enabled)


func _set_combat_effects_enabled(enabled: bool) -> void:
	_leave_blank_baseline()
	_combat_effects_enabled = enabled
	_combat.set_g0_effects_enabled(enabled)
	_player.set_g0_effects_enabled(enabled)


func _leave_blank_baseline() -> void:
	if not _blank_baseline_enabled:
		return
	_blank_baseline_enabled = false
	_main.set_g0_blank_baseline_enabled(false)


func _set_all_enabled(enabled: bool) -> void:
	_player_redraw_enabled = enabled
	_enemy_render_enabled = enabled
	_saturation_node_enabled = enabled
	_f1_tree_enabled = enabled
	_camera_shake_enabled = enabled
	_combo_layer_enabled = enabled
	_combat_effects_enabled = enabled
	_blank_baseline_enabled = not enabled
	_player.set_g0_continuous_redraw_enabled(enabled)
	_enemy_pool.set_g0_render_enabled(enabled)
	_combo.set_g0_saturation_node_enabled(enabled)
	_main.set_g0_tuning_overlay_enabled(enabled)
	_camera_shake.set_g0_enabled(enabled)
	_combo.set_g0_combo_layer_enabled(enabled)
	_combat.set_g0_effects_enabled(enabled)
	_player.set_g0_effects_enabled(enabled)
	_main.set_g0_blank_baseline_enabled(not enabled)


func _set_enemy_count_preset(index: int) -> void:
	_enemy_count_preset_index = clampi(index, 0, ENEMY_COUNT_PRESETS.size() - 1)
	_main.set_g0_enemy_count(ENEMY_COUNT_PRESETS[_enemy_count_preset_index])


func _set_forced_tier(tier: int) -> void:
	_forced_tier = 4 if tier == 4 else 0
	_combo.set_g0_forced_tier(_forced_tier)


func _start_capture() -> void:
	_capture_active = true
	_capture_started_usec = Time.get_ticks_usec()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__g0CaptureStarted=(window.__g0CaptureStarted||0)+1;", true)
	_capture_frame_times_ms.clear()
	_capture_process_ms_total = 0.0
	_capture_physics_ms_total = 0.0
	_capture_draw_calls_total = 0.0
	_capture_render_objects_total = 0.0
	_capture_primitives_total = 0.0
	_capture_node_count_total = 0.0
	_capture_static_memory_total = 0.0


func _cancel_capture() -> void:
	_capture_active = false
	_capture_frame_times_ms.clear()


func _capture_sample() -> void:
	_capture_frame_times_ms.append(_current_frame_time_ms)
	_capture_process_ms_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_capture_physics_ms_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_capture_draw_calls_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_capture_render_objects_total += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_capture_primitives_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_capture_node_count_total += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_capture_static_memory_total += Performance.get_monitor(Performance.MEMORY_STATIC)


func _finish_capture(now_usec: int) -> void:
	_capture_active = false
	var sample_count := _capture_frame_times_ms.size()
	if sample_count <= 0:
		return
	var p99_ms := _percentile_99(_capture_frame_times_ms)
	_last_result = {
		"duration_seconds": float(now_usec - _capture_started_usec) / 1_000_000.0,
		"sample_count": sample_count,
		"frame_average_ms": _average(_capture_frame_times_ms),
		"frame_max_ms": _maximum(_capture_frame_times_ms),
		"frame_p99_ms": p99_ms,
		"one_percent_low_fps": _one_percent_low_fps(_capture_frame_times_ms),
		"process_average_ms": _capture_process_ms_total / float(sample_count),
		"physics_average_ms": _capture_physics_ms_total / float(sample_count),
		"draw_calls_average": _capture_draw_calls_total / float(sample_count),
		"render_objects_average": _capture_render_objects_total / float(sample_count),
		"primitives_average": _capture_primitives_total / float(sample_count),
		"node_count_average": _capture_node_count_total / float(sample_count),
		"static_memory_average_bytes": _capture_static_memory_total / float(sample_count),
		"enemy_count": _enemy_pool.positions.size(),
		"tier": _combo.current_tier,
		"toggles": _toggle_state(),
		"histogram": _histogram_counts(_capture_frame_times_ms),
	}
	var json := JSON.stringify(_last_result)
	print("G0_RESULT|", json)
	if OS.has_feature("web"):
		var escaped_json := json.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval(
			"window.__g0LastResult=JSON.parse('%s');window.__g0ResultCounter=(window.__g0ResultCounter||0)+1;" % escaped_json,
			true
		)
	_capture_frame_times_ms.clear()


func _toggle_state() -> Dictionary:
	return {
		"player_redraw": _player_redraw_enabled,
		"enemy_render": _enemy_render_enabled,
		"saturation_node": _saturation_node_enabled,
		"f1_tree": _f1_tree_enabled,
		"camera_shake": _camera_shake_enabled,
		"combo_layer": _combo_layer_enabled,
		"combat_effects": _combat_effects_enabled,
		"blank_baseline": _blank_baseline_enabled,
	}


func _state_text(enabled: bool) -> String:
	return "ON" if enabled else "OFF"


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _maximum(values: Array[float]) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, value)
	return result


func _percentile_99(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var index := clampi(ceili(float(sorted_values.size()) * 0.99) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _one_percent_low_fps(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var slow_frame_count := maxi(1, ceili(float(sorted_values.size()) * 0.01))
	var slow_frame_time_total := 0.0
	for offset in slow_frame_count:
		slow_frame_time_total += sorted_values[sorted_values.size() - 1 - offset]
	var slow_frame_average_ms := slow_frame_time_total / float(slow_frame_count)
	return 1000.0 / slow_frame_average_ms if slow_frame_average_ms > 0.0 else 0.0


func _histogram_counts(values: Array[float]) -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for value in values:
		var bucket := HISTOGRAM_BOUNDS_MS.size()
		for bound_index in HISTOGRAM_BOUNDS_MS.size():
			if value < HISTOGRAM_BOUNDS_MS[bound_index]:
				bucket = bound_index
				break
		counts[bucket] += 1
	return counts


func _histogram_text(values: Array[float]) -> String:
	var counts := _histogram_counts(values)
	return "<8:%d  <13:%d  <16.7:%d  <25:%d  <33.3:%d  >=33.3:%d" % counts
