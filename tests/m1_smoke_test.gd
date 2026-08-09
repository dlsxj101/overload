extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	_check(packed_scene != null, "main.tscn 로드")
	if packed_scene == null:
		_finish()
		return

	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame

	var enemy_pool := main.get_node("EnemyPool") as EnemyPool
	var player := main.get_node("Player") as PlayerController
	var combat := main.get_node("Combat") as CombatSystem
	var hitstop := main.get_node("Hitstop") as Hitstop
	var audio_hit := main.get_node("AudioHit") as LayeredHitAudio
	var overlay := main.get_node("TuningOverlay") as TuningOverlay

	_check(enemy_pool.positions.size() == 1, "적이 배열 원소 1개로 존재")
	_check(_count_nodes_of_type(main, "RigidBody2D") == 0, "RigidBody2D 없음")
	_check(_count_preset_files() == 5, "선별한 특성 DNA 정확히 5개")
	_check(audio_hit.get_child_count() == 12, "3레이어 × 4보이스 오디오 풀")
	_check((overlay.get("_sliders") as Dictionary).size() == JuiceTuning.PARAMETER_SPECS.size(), "모든 튜닝 파라미터 슬라이더")
	_check((overlay.get("_preset_paths") as Array).size() == 5, "웹에서도 고정 로드되는 DNA 목록 5개")
	var preset_picker := overlay.get("_preset_picker") as OptionButton
	_check(preset_picker.get_item_text(0).begins_with("DNA | "), "선별 DNA의 한국어 특성 표시")
	_check(is_equal_approx(main.JUICE.hitstop_duration, 0.05), "기본 히트스톱 0.05초")
	_check(is_equal_approx(main.JUICE.sword_reach, 44.0), "기본 사거리 플레이어 반경 2.2배")
	for preset_path in overlay.get("_preset_paths") as Array:
		_check(ResourceLoader.load(preset_path) is JuiceTuning, "프리셋 로드: %s" % preset_path.get_file())
	overlay._toggle_ab()
	_check(is_equal_approx(main.JUICE.hitstop_duration, 0.08), "F3로 B 프리셋 즉시 전환")
	overlay._toggle_ab()
	_check(is_equal_approx(main.JUICE.hitstop_duration, 0.05), "F3로 A 프리셋 즉시 복귀")
	overlay._save_user_preset()
	main.JUICE.hitstop_duration = 0.01
	overlay._load_user_preset()
	_check(is_equal_approx(main.JUICE.hitstop_duration, 0.05), "사용자 프리셋 저장·불러오기")

	var finish_payload: Array = []
	hitstop.finished.connect(func(measured: float, buffered: bool) -> void: finish_payload.append([measured, buffered]))
	var hit_registered := combat.perform_sweep(Vector2(510.0, 270.0), 0.0, -0.7, 0.7, main.JUICE.sword_reach)
	_check(hit_registered, "직접 부채꼴 충돌 판정")
	_check(paused, "충돌 즉시 전체 트리 정지")
	_check(enemy_pool.flash_frames_remaining[0] > 0, "적 순백 플래시 예약")
	_check(root.get_viewport().canvas_transform.origin.x > 0.0, "오른쪽 타격 시 화면이 오른쪽으로 밀림")

	var buffered_click := InputEventMouseButton.new()
	buffered_click.button_index = MOUSE_BUTTON_LEFT
	buffered_click.pressed = true
	hitstop._input(buffered_click)
	var watchdog_started := Time.get_ticks_msec()
	while hitstop.is_active() and Time.get_ticks_msec() - watchdog_started < 500:
		await process_frame

	_check(not hitstop.is_active(), "실시간 시계로 히트스톱 종료")
	_check(not paused, "히트스톱 후 트리 재개")
	_check(not finish_payload.is_empty(), "히트스톱 실측 결과 방출")
	if not finish_payload.is_empty():
		_check(finish_payload[0][0] >= 0.05, "히트스톱 실측 0.05초 이상")
		_check(finish_payload[0][1] == true, "정지 중 좌클릭 입력 버퍼")

	for audio_player in audio_hit.get_children():
		if audio_player is AudioStreamPlayer:
			audio_player.stop()
			audio_player.stream = null
	var audio_release_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - audio_release_started < 80:
		await process_frame
	root.remove_child(main)
	main.free()
	_finish()


func _count_nodes_of_type(node: Node, class_name_to_find: String) -> int:
	var count := 1 if node.is_class(class_name_to_find) else 0
	for child in node.get_children():
		count += _count_nodes_of_type(child, class_name_to_find)
	return count


func _count_preset_files() -> int:
	var count := 0
	for file_name in DirAccess.get_files_at("res://tuning/presets"):
		if file_name.ends_with(".tres"):
			count += 1
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("M1_SMOKE_TEST_PASS")
		_quit_after_cleanup.call_deferred(0)
	else:
		print("M1_SMOKE_TEST_FAIL: ", ", ".join(_failures))
		_quit_after_cleanup.call_deferred(1)


func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	await process_frame
	quit(exit_code)
