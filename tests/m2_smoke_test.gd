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

	var combo := main.get_node("Combo") as ComboSystem
	var player := main.get_node("Player") as PlayerController
	var enemy_pool := main.get_node("EnemyPool") as EnemyPool
	var combat := main.get_node("Combat") as CombatSystem
	var hitstop := main.get_node("Hitstop") as Hitstop
	var audio_hit := main.get_node("AudioHit") as LayeredHitAudio

	_check(combo.combo_count == 0 and combo.current_tier == 0, "콤보 0에서 티어 0 시작")
	_check(is_equal_approx(combo.get_sword_scale(), 1.0), "티어 0 칼 1.0배")
	_check(is_equal_approx(combo.get_hitstop_duration(), 0.05), "티어 0 히트스톱 0.05초")
	_check(is_equal_approx(combo.get_windup_time(), 0.15), "티어 0 준비동작 0.15초")
	_check(is_equal_approx(combo.get_windup_time() + combo.get_hitstop_duration(), 0.2), "티어 0 공격 주기 기준 유지")
	_check(combo.get_combo_label().text == "0", "화면 중앙 콤보 숫자 표시")
	_check(combo.get_combo_label().get_theme_font_size("font_size") == 148, "콤보 숫자 대형 표시")
	_check(is_equal_approx(combo.get_combo_label().get_theme_color("font_color").a, 0.13), "콤보 숫자 반투명 표시")

	_raise_combo_to(combo, 9)
	_check(combo.current_tier == 0, "콤보 9까지 티어 0")
	combo.register_kill()
	_check(combo.current_tier == 1, "콤보 10에서 티어 1")
	_check(is_equal_approx(combo.get_sword_scale(), 1.3), "티어 1 칼 1.3배")
	_check(is_equal_approx(combo.get_hitstop_duration(), 0.06), "티어 1 히트스톱 0.06초")
	_check(is_equal_approx(combo.get_windup_time(), 0.14), "티어 1 준비동작 0.14초")
	_check(is_equal_approx(combo.get_windup_time() + combo.get_hitstop_duration(), 0.2), "티어 1 공격 주기 기준 유지")
	_check(combo.is_transition_active(), "티어 상승 화면 전환 시작")
	_check(main.JUICE.tier_transition_duration <= 0.2, "티어 전환 0.2초 이내")
	_check(combo.get_combo_label().scale.x > 1.0, "티어 상승 시 콤보 숫자 확대")
	_check((combo.get("_flash_rect") as ColorRect).color.a > 0.0, "티어 상승 시 짧은 화면 플래시")
	_check((combo.get("_rise_player") as AudioStreamPlayer).playing, "티어 상승 시 낮은 상승음")

	_raise_combo_to(combo, 25)
	_check(combo.current_tier == 2, "콤보 25에서 티어 2")
	_check(is_equal_approx(combo.get_sword_scale(), 1.7), "티어 2 칼 1.7배")
	_check(is_equal_approx(combo.get_hitstop_duration(), 0.08), "티어 2 히트스톱 0.08초")
	_check(is_equal_approx(combo.get_windup_time(), 0.12), "티어 2 준비동작 0.12초")
	_check(is_equal_approx(combo.get_windup_time() + combo.get_hitstop_duration(), 0.2), "티어 2 공격 주기 기준 유지")
	player._record_afterimage(0.0, player.get_effective_sword_reach())
	_check((player.get("_afterimage_angles") as Array).size() == 1, "티어 2 궤적 잔상 기록")

	_raise_combo_to(combo, 50)
	_check(combo.current_tier == 3, "콤보 50에서 티어 3")
	_check(is_equal_approx(combo.get_sword_scale(), 2.2), "티어 3 칼 2.2배")
	_check(is_equal_approx(combo.get_hitstop_duration(), 0.1), "티어 3 히트스톱 0.10초")
	_check(is_equal_approx(combo.get_windup_time(), 0.1), "티어 3 준비동작 0.10초")
	_check(is_equal_approx(combo.get_windup_time() + combo.get_hitstop_duration(), 0.2), "티어 3 공격 주기 기준 유지")
	var tier_3_hit := combat.perform_sweep(
		player.global_position,
		0.0,
		-0.7,
		0.7,
		player.get_effective_sword_reach()
	)
	_check(tier_3_hit, "티어 3 실제 타격")
	_check((combat.get("_electric_origins") as Array).size() == main.JUICE.electric_bolt_count, "티어 3 전류 스파크")
	while hitstop.is_active():
		await process_frame

	_raise_combo_to(combo, 100)
	_check(combo.current_tier == 4, "콤보 100에서 티어 4")
	_check(is_equal_approx(combo.get_sword_scale(), 3.0), "티어 4 칼 3.0배")
	_check(is_equal_approx(combo.get_hitstop_duration(), 0.12), "티어 4 히트스톱 0.12초")
	_check(is_equal_approx(combo.get_windup_time(), 0.08), "티어 4 준비동작 0.08초")
	_check(is_equal_approx(combo.get_windup_time() + combo.get_hitstop_duration(), 0.2), "티어 4 공격 주기 기준 유지")
	_check(is_equal_approx(player.get_effective_sword_reach(), main.JUICE.sword_reach * 3.0), "칼 배율이 실제 사거리에 적용")
	_check(is_equal_approx(combo.get_saturation(), 1.35), "티어 4 화면 채도 상승")
	_check(combo.is_hum_playing(), "티어 4 저역 지속음")

	var far_target := player.global_position + Vector2(120.0, 0.0)
	enemy_pool.positions[0] = far_target
	_check(
		enemy_pool.find_swept_hit(player.global_position, 0.0, -0.7, 0.7, main.JUICE.sword_reach) < 0,
		"기본 칼은 먼 표적에 닿지 않음"
	)
	_check(
		enemy_pool.find_swept_hit(player.global_position, 0.0, -0.7, 0.7, player.get_effective_sword_reach()) == 0,
		"티어 4 칼은 넓어진 실제 범위로 먼 표적 타격"
	)

	audio_hit.play_hit(4)
	var tier_4_body := audio_hit.get_node("BodyVoice2") as AudioStreamPlayer
	_check(tier_4_body.stream.resource_path.get_file().begins_with("body_"), "티어별 타격음 파일 교체 없음")
	_check(is_equal_approx(tier_4_body.volume_db, main.JUICE.tier_4_body_volume_db), "티어 4 body 볼륨만 하향")
	_check(
		tier_4_body.pitch_scale >= main.JUICE.tier_4_body_pitch * 0.92
		and tier_4_body.pitch_scale <= main.JUICE.tier_4_body_pitch * 1.08,
		"티어 4 body 피치 하향과 ±8% 무작위 유지"
	)

	combo._process(main.JUICE.combo_grace_time)
	_check(combo.combo_count == 100, "마지막 처치 후 3초 동안 콤보 유지")
	combo._process(1.0)
	_check(combo.combo_count == 95, "3초 이후 초당 5씩 점진 감소")
	_check(combo.current_tier == 3, "콤보 감소 시 티어도 하향")
	_check(not combo.is_hum_playing() and is_equal_approx(combo.get_saturation(), 1.0), "티어 4 이탈 시 지속 연출 해제")

	_stop_audio_recursive(main)
	var audio_release_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - audio_release_started < 80:
		await process_frame
	root.remove_child(main)
	main.free()
	_finish()


func _raise_combo_to(combo: ComboSystem, target: int) -> void:
	while combo.combo_count < target:
		combo.register_kill()


func _stop_audio_recursive(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio_recursive(child)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("M2_SMOKE_TEST_PASS")
		_quit_after_cleanup.call_deferred(0)
	else:
		print("M2_SMOKE_TEST_FAIL: ", ", ".join(_failures))
		_quit_after_cleanup.call_deferred(1)


func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	await process_frame
	quit(exit_code)
