extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame

	var profiler := main.get_node("G0Profiler") as G0Profiler
	var enemy_pool := main.get_node("EnemyPool") as EnemyPool
	var combo := main.get_node("Combo") as ComboSystem

	_check(profiler.layer == 110, "F2 프로파일 패널이 F1과 다른 CanvasLayer")
	profiler._set_enemy_count_preset(4)
	_check(enemy_pool.positions.size() == 150, "적 수 150 프리셋")
	_check(enemy_pool.spawn_positions.size() == 150, "적 병렬 배열 150개 유지")

	profiler._set_saturation_node_enabled(false)
	_check(combo.get_node_or_null("SaturationLayer") == null, "채도 노드 실제 free")
	profiler._set_f1_tree_enabled(false)
	_check(main.get_node_or_null("TuningOverlay") == null, "F1 전체 노드 트리 실제 free")

	profiler._set_all_enabled(false)
	_check(not main.get("_g0_world_render_enabled"), "0 키 빈 화면 기준선")
	_check(not main.get_node("Player").visible, "빈 화면에서 Player 렌더 차단")
	_check(not combo.get_node("ComboLayer").visible, "빈 화면에서 콤보 CanvasLayer 차단")

	profiler._set_all_enabled(true)
	_check(main.get_node_or_null("TuningOverlay") is TuningOverlay, "F1 노드 재생성")
	_check(combo.get_node_or_null("SaturationLayer") is CanvasLayer, "채도 노드 재생성")
	_check(main.get_node("Player").visible, "빈 화면 기준선 해제")

	_stop_audio_recursive(main)
	root.remove_child(main)
	main.free()
	_finish()


func _stop_audio_recursive(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio_recursive(child)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("G0_SMOKE_TEST_PASS")
		_quit_after_cleanup.call_deferred(0)
		return
	print("G0_SMOKE_TEST_FAIL: ", ", ".join(_failures))
	_quit_after_cleanup.call_deferred(1)


func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	await process_frame
	quit(exit_code)
