class_name ComboSystem
extends Node

signal combo_changed(value: int)
signal tier_changed(previous_tier: int, current_tier: int)

const UI_FONT: Font = preload("res://fonts/BlackHanSans-Regular.ttf")
const AUDIO_SAMPLE_RATE := 44100
const SATURATION_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float saturation = 1.0;

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(luminance), source.rgb, saturation), source.a);
}
"""

var combo_count := 0
var current_tier := 0

var _tuning: JuiceTuning
var _combo_at_last_kill := 0
var _last_kill_usec := 0
var _transition_active := false
var _transition_elapsed := 0.0
var _saturation_material: ShaderMaterial
var _saturation_rect: ColorRect
var _flash_rect: ColorRect
var _combo_label: Label
var _rise_player: AudioStreamPlayer
var _hum_player: AudioStreamPlayer


func configure(tuning_resource: JuiceTuning) -> void:
	_tuning = tuning_resource
	_tuning.changed.connect(_on_tuning_changed)
	_build_visual_layers()
	_build_audio()
	_update_combo_label()
	_apply_tier_state()


func _process(delta: float) -> void:
	if _tuning == null:
		return
	_update_transition(delta)
	if combo_count <= 0:
		return

	var elapsed_seconds := float(Time.get_ticks_usec() - _last_kill_usec) / 1_000_000.0
	var decay_seconds := maxf(0.0, elapsed_seconds - _tuning.combo_grace_time)
	var decay_steps := floori(decay_seconds * _tuning.combo_decay_per_second)
	var expected_combo := maxi(0, _combo_at_last_kill - decay_steps)
	if expected_combo != combo_count:
		_set_combo(expected_combo, false)


func register_kill() -> int:
	_set_combo(combo_count + 1, true)
	_combo_at_last_kill = combo_count
	_last_kill_usec = Time.get_ticks_usec()
	return current_tier


func get_sword_scale() -> float:
	match current_tier:
		1:
			return _tuning.tier_1_sword_scale
		2:
			return _tuning.tier_2_sword_scale
		3:
			return _tuning.tier_3_sword_scale
		4:
			return _tuning.tier_4_sword_scale
		_:
			return _tuning.tier_0_sword_scale


func get_hitstop_duration() -> float:
	match current_tier:
		1:
			return _tuning.tier_1_hitstop
		2:
			return _tuning.tier_2_hitstop
		3:
			return _tuning.tier_3_hitstop
		4:
			return _tuning.tier_4_hitstop
		_:
			return _tuning.hitstop_duration


func get_windup_time() -> float:
	match current_tier:
		1:
			return _tuning.tier_1_windup
		2:
			return _tuning.tier_2_windup
		3:
			return _tuning.tier_3_windup
		4:
			return _tuning.tier_4_windup
		_:
			return _tuning.windup_time


func is_transition_active() -> bool:
	return _transition_active


func is_hum_playing() -> bool:
	return _hum_player != null and _hum_player.playing


func get_saturation() -> float:
	if _saturation_material == null:
		return 1.0
	return float(_saturation_material.get_shader_parameter("saturation"))


func get_combo_label() -> Label:
	return _combo_label


func _set_combo(value: int, allow_tier_up_transition: bool) -> void:
	var previous_tier := current_tier
	combo_count = value
	current_tier = _tier_for_combo(combo_count)
	_update_combo_label()
	combo_changed.emit(combo_count)
	if current_tier == previous_tier:
		return
	_apply_tier_state()
	tier_changed.emit(previous_tier, current_tier)
	if allow_tier_up_transition and current_tier > previous_tier:
		_start_tier_transition()


func _tier_for_combo(value: int) -> int:
	if value >= _tuning.tier_4_threshold:
		return 4
	if value >= _tuning.tier_3_threshold:
		return 3
	if value >= _tuning.tier_2_threshold:
		return 2
	if value >= _tuning.tier_1_threshold:
		return 1
	return 0


func _build_visual_layers() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	var saturation_layer := CanvasLayer.new()
	saturation_layer.name = "SaturationLayer"
	saturation_layer.layer = 10
	add_child(saturation_layer)

	_saturation_rect = ColorRect.new()
	_saturation_rect.name = "Saturation"
	_saturation_rect.position = Vector2.ZERO
	_saturation_rect.size = viewport_size
	_saturation_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saturation_rect.color = Color.WHITE
	var saturation_shader := Shader.new()
	saturation_shader.code = SATURATION_SHADER_CODE
	_saturation_material = ShaderMaterial.new()
	_saturation_material.shader = saturation_shader
	_saturation_rect.material = _saturation_material
	saturation_layer.add_child(_saturation_rect)

	var combo_layer := CanvasLayer.new()
	combo_layer.name = "ComboLayer"
	combo_layer.layer = 20
	add_child(combo_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "TierFlash"
	_flash_rect.position = Vector2.ZERO
	_flash_rect.size = viewport_size
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.88, 1.0, 0.98, 0.0)
	combo_layer.add_child(_flash_rect)

	_combo_label = Label.new()
	_combo_label.name = "ComboNumber"
	_combo_label.position = Vector2.ZERO
	_combo_label.size = viewport_size
	_combo_label.pivot_offset = viewport_size * 0.5
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_override("font", UI_FONT)
	_combo_label.add_theme_font_size_override("font_size", _tuning.combo_font_size)
	combo_layer.add_child(_combo_label)


func _build_audio() -> void:
	_rise_player = AudioStreamPlayer.new()
	_rise_player.name = "TierRise"
	_rise_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_rise_player.volume_db = _tuning.tier_rise_volume_db
	_rise_player.stream = _make_rise_stream()
	add_child(_rise_player)

	_hum_player = AudioStreamPlayer.new()
	_hum_player.name = "Tier4Hum"
	_hum_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_hum_player.volume_db = _tuning.tier_4_hum_volume_db
	_hum_player.stream = _make_hum_stream()
	add_child(_hum_player)


func _update_combo_label() -> void:
	if _combo_label == null:
		return
	_combo_label.text = str(combo_count)
	_combo_label.add_theme_font_size_override("font_size", _tuning.combo_font_size)
	var base_color := Color.WHITE if current_tier == 0 else Color("00e5d0")
	base_color.a = _tuning.combo_opacity
	_combo_label.add_theme_color_override("font_color", base_color)
	if not _transition_active:
		_combo_label.scale = Vector2.ONE


func _apply_tier_state() -> void:
	if _saturation_material != null:
		_saturation_material.set_shader_parameter(
			"saturation",
			_tuning.tier_4_saturation if current_tier == 4 else 1.0
		)
		_saturation_rect.visible = current_tier == 4
	if _hum_player == null:
		return
	if current_tier == 4:
		if not _hum_player.playing:
			_hum_player.play()
	else:
		_hum_player.stop()


func _start_tier_transition() -> void:
	_transition_active = true
	_transition_elapsed = 0.0
	_flash_rect.color.a = _tuning.tier_flash_opacity
	_combo_label.scale = Vector2.ONE * _tuning.combo_pulse_scale
	_rise_player.stop()
	_rise_player.stream = _make_rise_stream()
	_rise_player.play()


func _update_transition(delta: float) -> void:
	if not _transition_active:
		return
	_transition_elapsed = minf(_transition_elapsed + delta, _tuning.tier_transition_duration)
	var progress := _transition_elapsed / maxf(_tuning.tier_transition_duration, 0.001)
	var remaining := pow(1.0 - progress, 2.0)
	_flash_rect.color.a = _tuning.tier_flash_opacity * remaining
	_combo_label.scale = Vector2.ONE * lerpf(1.0, _tuning.combo_pulse_scale, remaining)
	if _transition_elapsed >= _tuning.tier_transition_duration:
		_transition_active = false
		_flash_rect.color.a = 0.0
		_combo_label.scale = Vector2.ONE


func _make_rise_stream() -> AudioStreamWAV:
	var sample_count := maxi(1, int(AUDIO_SAMPLE_RATE * _tuning.tier_transition_duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for sample_index in sample_count:
		var progress := float(sample_index) / float(maxi(sample_count - 1, 1))
		var frequency := lerpf(_tuning.tier_rise_start_hz, _tuning.tier_rise_end_hz, progress)
		phase += TAU * frequency / float(AUDIO_SAMPLE_RATE)
		var envelope := pow(sin(PI * progress), 0.7)
		var sample_value := int(clampf(sin(phase) * envelope * 0.72, -1.0, 1.0) * 32767.0)
		data.encode_s16(sample_index * 2, sample_value)
	return _make_wav(data, sample_count, false)


func _make_hum_stream() -> AudioStreamWAV:
	var sample_count := maxi(16, roundi(float(AUDIO_SAMPLE_RATE) / _tuning.tier_4_hum_hz))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in sample_count:
		var phase := TAU * float(sample_index) / float(sample_count)
		var sample_value := int(sin(phase) * 0.7 * 32767.0)
		data.encode_s16(sample_index * 2, sample_value)
	return _make_wav(data, sample_count, true)


func _make_wav(data: PackedByteArray, sample_count: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream


func _on_tuning_changed() -> void:
	if _combo_label == null:
		return
	var expected_tier := _tier_for_combo(combo_count)
	if expected_tier != current_tier:
		var previous_tier := current_tier
		current_tier = expected_tier
		_apply_tier_state()
		tier_changed.emit(previous_tier, current_tier)
	_update_combo_label()
	_apply_tier_state()
